use super::c_path;
use crate::ux::filetree::{Entry, FileIdentity, Kind};
use std::ffi::{CStr, OsStr, OsString, c_void};
use std::io;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::os::unix::ffi::OsStrExt;
use std::path::Path;

#[cfg(test)]
mod tests;

/** Bytes per `getattrlistbulk` call, a few hundred entries; a scan charges them to its reservation. */
pub(crate) const BUFFER_BYTES: usize = 64 * 1024;

/* <sys/attr.h> and <sys/stat.h> define these; the libc crate does not. */
const ATTR_CMN_ERROR: u32 = 0x2000_0000;
const SF_FIRMLINK: u32 = 0x0080_0000;
/* Returned in bit order, after ATTR_CMN_RETURNED_ATTRS and ATTR_CMN_ERROR. */
const COMMON: u32 = libc::ATTR_CMN_NAME
    | libc::ATTR_CMN_DEVID
    | libc::ATTR_CMN_OBJTYPE
    | libc::ATTR_CMN_CRTIME
    | libc::ATTR_CMN_MODTIME
    | libc::ATTR_CMN_OWNERID
    | libc::ATTR_CMN_GRPID
    | libc::ATTR_CMN_ACCESSMASK
    | libc::ATTR_CMN_FLAGS
    | libc::ATTR_CMN_FILEID;
const DIRECTORY: u32 = libc::ATTR_DIR_MOUNTSTATUS | libc::ATTR_DIR_DATALENGTH;

/** A listed name with metadata equal to `Entry::read` of its path, or a name left for that read:
links, firmlinks, mount points, entry errors and incomplete attributes. */
// Each value moves once from the buffer into the scan; boxing would allocate per entry.
#[allow(clippy::large_enum_variant)]
pub(crate) enum Listed {
    Entry(Entry),
    Name(OsString),
}

/** A directory's entries with their metadata: one `getattrlistbulk` call per buffer of entries
instead of an `lstat` per entry. */
pub(crate) struct Listing {
    directory: OwnedFd,
    request: libc::attrlist,
    /* Entry groups start 8-byte aligned. */
    buffer: Box<[u64]>,
    remaining: usize,
    offset: usize,
}

impl Listing {
    pub fn open(path: &Path) -> io::Result<Self> {
        let path = c_path(path)?;
        let fd = unsafe {
            libc::open(
                path.as_ptr(),
                libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC,
            )
        };
        if fd < 0 {
            return Err(io::Error::last_os_error());
        }
        let mut request: libc::attrlist = unsafe { std::mem::zeroed() };
        request.bitmapcount = libc::ATTR_BIT_MAP_COUNT;
        request.commonattr = libc::ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_ERROR | COMMON;
        request.dirattr = DIRECTORY;
        request.fileattr = libc::ATTR_FILE_DATALENGTH;
        Ok(Self {
            directory: unsafe { OwnedFd::from_raw_fd(fd) },
            request,
            buffer: vec![0; BUFFER_BYTES / 8].into_boxed_slice(),
            remaining: 0,
            offset: 0,
        })
    }
}

impl Iterator for Listing {
    type Item = io::Result<Listed>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.remaining == 0 {
            let count = unsafe {
                libc::getattrlistbulk(
                    self.directory.as_raw_fd(),
                    &mut self.request as *mut libc::attrlist as *mut c_void,
                    self.buffer.as_mut_ptr() as *mut c_void,
                    BUFFER_BYTES,
                    0,
                )
            };
            if count < 0 {
                return Some(Err(io::Error::last_os_error()));
            }
            if count == 0 {
                return None;
            }
            (self.remaining, self.offset) = (count as usize, 0);
        }
        self.remaining -= 1;
        let group = bytes(&self.buffer).get(self.offset..).and_then(|rest| {
            let length = read::<u32>(rest, 0)? as usize;
            rest.get(..length).filter(|_| length >= 4)
        });
        let Some(group) = group else {
            self.remaining = 0;
            return Some(Err(malformed()));
        };
        self.offset += group.len();
        Some(parse(group).ok_or_else(malformed))
    }
}

/** The buffer's bytes, borrowed for as long as the buffer. */
fn bytes(words: &[u64]) -> &[u8] {
    unsafe { std::slice::from_raw_parts(words.as_ptr() as *const u8, std::mem::size_of_val(words)) }
}

fn malformed() -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, "malformed directory attributes")
}

fn read<T: Copy>(bytes: &[u8], at: usize) -> Option<T> {
    let bytes = bytes.get(at..at.checked_add(std::mem::size_of::<T>())?)?;
    Some(unsafe { std::ptr::read_unaligned(bytes.as_ptr() as *const T) })
}

struct Cursor<'a> {
    group: &'a [u8],
    at: usize,
}

impl Cursor<'_> {
    fn take<T: Copy>(&mut self) -> Option<T> {
        let value = read(self.group, self.at)?;
        self.at += std::mem::size_of::<T>();
        Some(value)
    }
}

/** Attributes follow the group length in request order; see getattrlist(2) and getattrlistbulk(2). */
fn parse(group: &[u8]) -> Option<Listed> {
    let mut cursor = Cursor { group, at: 4 };
    let returned: libc::attribute_set_t = cursor.take()?;
    let error = if returned.commonattr & ATTR_CMN_ERROR != 0 {
        cursor.take::<u32>()?
    } else {
        0
    };
    let reference_at = cursor.at;
    let reference: libc::attrreference_t = cursor.take()?;
    let start = reference_at.checked_add_signed(reference.attr_dataoffset as isize)?;
    let name = group.get(start..start.checked_add(reference.attr_length as usize)?)?;
    let name = OsStr::from_bytes(CStr::from_bytes_until_nul(name).ok()?.to_bytes()).to_owned();
    if error != 0 || returned.commonattr & COMMON != COMMON {
        return Some(Listed::Name(name));
    }
    let device: libc::dev_t = cursor.take()?;
    let object: u32 = cursor.take()?;
    let created: libc::timespec = cursor.take()?;
    let modified: libc::timespec = cursor.take()?;
    let uid: libc::uid_t = cursor.take()?;
    let gid: libc::gid_t = cursor.take()?;
    let access: u32 = cursor.take()?;
    let flags: u32 = cursor.take()?;
    let file: u64 = cursor.take()?;
    /* A firmlink reports itself, while `lstat` reports the directory it links to. */
    if flags & SF_FIRMLINK != 0 {
        return Some(Listed::Name(name));
    }
    /* `enum vtype` values from <sys/vnode.h>; links read their targets by path. */
    let (kind, format) = match object {
        1 => (Kind::File, libc::S_IFREG),
        2 => (Kind::Directory, libc::S_IFDIR),
        3 => (Kind::Other, libc::S_IFBLK),
        4 => (Kind::Other, libc::S_IFCHR),
        6 => (Kind::Other, libc::S_IFSOCK),
        7 => (Kind::Other, libc::S_IFIFO),
        _ => return Some(Listed::Name(name)),
    };
    let size: i64 = if kind == Kind::Directory {
        /* A mount point reports the directory it covers, not the mounted root that `lstat` shows. */
        if returned.dirattr & DIRECTORY != DIRECTORY
            || cursor.take::<u32>()? & libc::DIR_MNTSTATUS_MNTPOINT != 0
        {
            return Some(Listed::Name(name));
        }
        cursor.take()?
    } else {
        /* Directory attributes would precede the file's length; only directories carry them. */
        if returned.dirattr != 0 || returned.fileattr & libc::ATTR_FILE_DATALENGTH == 0 {
            return Some(Listed::Name(name));
        }
        cursor.take()?
    };
    if file == 0 {
        return Some(Listed::Name(name));
    }
    Some(Listed::Entry(Entry {
        name,
        identity: FileIdentity {
            volume: device as u64,
            file: file as u128,
        },
        kind,
        size: size as u64,
        created: Some(nanos(created)),
        modified: Some(nanos(modified)),
        mode: u32::from(format) | (access & !u32::from(libc::S_IFMT)),
        uid,
        gid,
        link: None,
        target: None,
        target_unknown: false,
        cycle: false,
        anchor: None,
    }))
}

/** Nanoseconds from the epoch, as `Entry::read` derives from the same `SystemTime`. */
fn nanos(time: libc::timespec) -> i128 {
    time.tv_sec as i128 * 1_000_000_000 + time.tv_nsec as i128
}
