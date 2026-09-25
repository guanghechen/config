use super::Target;
#[cfg(target_os = "linux")]
use crate::ux::filetree::Entry;
use crate::ux::filetree::resource;
use crate::ux::treeview::{Error, Result};
use std::collections::{HashMap, HashSet};

#[cfg(target_os = "macos")]
#[path = "macos.rs"]
mod platform;

#[cfg(windows)]
#[path = "windows.rs"]
mod platform;

#[cfg(target_os = "linux")]
mod platform {
    use super::*;
    use std::fs::File;
    use std::os::fd::{AsRawFd, FromRawFd};
    use std::os::unix::fs::OpenOptionsExt;

    pub struct Backend {
        fd: File,
        watches: HashMap<i32, (u64, File)>,
    }
    impl Backend {
        pub fn ready(&self) -> bool {
            true
        }
        pub fn new() -> Result<Self> {
            let fd = unsafe { libc::inotify_init1(libc::IN_NONBLOCK | libc::IN_CLOEXEC) };
            if fd < 0 {
                return Err(resource::io_error(
                    "create directory watcher",
                    std::io::Error::last_os_error(),
                ));
            }
            Ok(Self {
                fd: unsafe { File::from_raw_fd(fd) },
                watches: HashMap::new(),
            })
        }
        pub fn remove(&mut self, id: u64) {
            if let Some(wd) = self
                .watches
                .iter()
                .find_map(|(wd, current)| (current.0 == id).then_some(*wd))
            {
                unsafe {
                    libc::inotify_rm_watch(self.fd.as_raw_fd(), wd);
                }
                self.watches.remove(&wd);
            }
        }
        pub fn add(&mut self, id: u64, target: &Target) -> Result<()> {
            let file = std::fs::OpenOptions::new()
                .read(true)
                .custom_flags(libc::O_DIRECTORY | libc::O_CLOEXEC)
                .open(&*target.path)
                .map_err(|error| resource::io_error("open watched directory", error))?;
            let metadata = file
                .metadata()
                .map_err(|error| resource::io_error("verify watched directory", error))?;
            let entry = Entry::from_metadata(&target.path, &metadata)
                .map_err(|error| resource::io_error("identify watched directory", error))?;
            if entry.identity != target.identity {
                return Err(Error::stale("directory changed while registering watch"));
            }
            /* Bind the watch to the validated descriptor, not a path that can be replaced. */
            let path = std::ffi::CString::new(format!("/proc/self/fd/{}", file.as_raw_fd()))
                .expect("descriptor path");
            let mask = libc::IN_CREATE
                | libc::IN_DELETE
                | libc::IN_MOVED_FROM
                | libc::IN_MOVED_TO
                | libc::IN_ATTRIB
                | libc::IN_MODIFY
                | libc::IN_DELETE_SELF
                | libc::IN_MOVE_SELF
                | libc::IN_ONLYDIR;
            let wd = unsafe { libc::inotify_add_watch(self.fd.as_raw_fd(), path.as_ptr(), mask) };
            if wd < 0 {
                return Err(resource::io_error(
                    "register directory watch",
                    std::io::Error::last_os_error(),
                ));
            }
            self.watches.insert(wd, (id, file));
            Ok(())
        }
        pub fn poll(&mut self) -> Result<HashSet<u64>> {
            let mut bytes = [0u8; 64 * 1024];
            let count =
                unsafe { libc::read(self.fd.as_raw_fd(), bytes.as_mut_ptr().cast(), bytes.len()) };
            if count < 0 {
                let error = std::io::Error::last_os_error();
                if matches!(
                    error.kind(),
                    std::io::ErrorKind::WouldBlock | std::io::ErrorKind::Interrupted
                ) {
                    return Ok(HashSet::new());
                }
                return Err(resource::io_error("poll directory watches", error));
            }
            let mut changed = HashSet::new();
            let mut at = 0;
            while at + std::mem::size_of::<libc::inotify_event>() <= count as usize {
                let event = unsafe {
                    std::ptr::read_unaligned(bytes.as_ptr().add(at).cast::<libc::inotify_event>())
                };
                if event.mask & libc::IN_Q_OVERFLOW != 0 {
                    changed.extend(self.watches.values().map(|(id, _)| *id));
                } else if let Some((id, _)) = self.watches.get(&event.wd) {
                    changed.insert(*id);
                }
                at += std::mem::size_of::<libc::inotify_event>() + event.len as usize;
            }
            Ok(changed)
        }
    }
}

#[cfg(not(any(target_os = "macos", target_os = "linux", windows)))]
mod platform {
    use super::*;
    pub struct Backend;
    impl Backend {
        pub fn ready(&self) -> bool {
            true
        }
        pub fn new() -> Result<Self> {
            Err(Error::new(
                crate::ux::treeview::ErrorCode::ProviderError,
                "native directory notifications are unavailable on this platform",
            ))
        }
        pub fn remove(&mut self, _: u64) {}
        pub fn add(&mut self, _: u64, _: &Target) -> Result<()> {
            unreachable!()
        }
        pub fn poll(&mut self) -> Result<HashSet<u64>> {
            unreachable!()
        }
    }
}
pub(super) use platform::Backend;
