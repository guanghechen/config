use super::*;
use crate::ux::filetree::FileIdentity;
use crate::ux::treeview::memory::Charge;
use std::ffi::c_void;
use std::fs::{File, OpenOptions};
use std::os::windows::{fs::OpenOptionsExt, io::AsRawHandle};

type Handle = *mut c_void;
const BUFFER_WORDS: usize = 4096;
const IO_INCOMPLETE: i32 = 996;
const IO_PENDING: i32 = 997;
const NOTIFY_ENUM_DIR: i32 = 1022;

#[repr(C)]
struct Overlapped {
    internal: usize,
    internal_high: usize,
    offset: u32,
    offset_high: u32,
    event: Handle,
}

#[link(name = "kernel32")]
unsafe extern "system" {
    fn CreateEventW(attributes: Handle, manual: i32, initial: i32, name: *const u16) -> Handle;
    fn ResetEvent(event: Handle) -> i32;
    fn CloseHandle(handle: Handle) -> i32;
    fn ReadDirectoryChangesW(
        file: Handle,
        buffer: Handle,
        length: u32,
        subtree: i32,
        filter: u32,
        returned: *mut u32,
        overlapped: *mut Overlapped,
        completion: Handle,
    ) -> i32;
    fn GetOverlappedResult(
        file: Handle,
        overlapped: *mut Overlapped,
        transferred: *mut u32,
        wait: i32,
    ) -> i32;
    fn CancelIoEx(file: Handle, overlapped: *mut Overlapped) -> i32;
}

struct Watch {
    file: File,
    buffer: Box<[u32]>,
    overlapped: Box<Overlapped>,
    pending: bool,
    _memory: Charge,
}

/* Each watch is used exclusively by the controller worker. The kernel writes only to
 * pinned heap allocations, and Drop waits for cancelled IO before releasing them. */
unsafe impl Send for Watch {}

impl Watch {
    fn arm(&mut self) -> Result<()> {
        unsafe {
            ResetEvent(self.overlapped.event);
        }
        self.overlapped.internal = 0;
        self.overlapped.internal_high = 0;
        let result = unsafe {
            ReadDirectoryChangesW(
                self.file.as_raw_handle(),
                self.buffer.as_mut_ptr().cast(),
                (self.buffer.len() * 4) as u32,
                0,
                1 | 2 | 4 | 8 | 16 | 64,
                std::ptr::null_mut(),
                &mut *self.overlapped,
                std::ptr::null_mut(),
            )
        };
        if result == 0 {
            let error = std::io::Error::last_os_error();
            if error.raw_os_error() != Some(IO_PENDING) {
                return Err(resource::io_error("register directory notification", error));
            }
        }
        self.pending = true;
        Ok(())
    }
}

impl Drop for Watch {
    fn drop(&mut self) {
        unsafe {
            if self.pending {
                CancelIoEx(self.file.as_raw_handle(), &mut *self.overlapped);
                let mut transferred = 0;
                GetOverlappedResult(
                    self.file.as_raw_handle(),
                    &mut *self.overlapped,
                    &mut transferred,
                    1,
                );
            }
            CloseHandle(self.overlapped.event);
        }
    }
}

pub struct Backend {
    watches: HashMap<u64, Watch>,
}

impl Backend {
    pub fn ready(&self) -> bool {
        true
    }

    pub fn new() -> Result<Self> {
        Ok(Self {
            watches: HashMap::new(),
        })
    }

    pub fn remove(&mut self, id: u64) {
        self.watches.remove(&id);
    }

    pub fn add(&mut self, id: u64, target: &Target) -> Result<()> {
        let memory = Charge::new(BUFFER_WORDS * 4 + 256);
        crate::ux::treeview::memory::check()?;
        let file = OpenOptions::new()
            .access_mode(1 | 0x80)
            .share_mode(7)
            .custom_flags(0x02000000 | 0x40000000)
            .open(&*target.path)
            .map_err(|error| resource::io_error("open watched directory", error))?;
        if FileIdentity::from_file(&file)
            .map_err(|error| resource::io_error("identify watched directory", error))?
            != target.identity
        {
            return Err(Error::stale("directory changed while registering watch"));
        }
        let event = unsafe { CreateEventW(std::ptr::null_mut(), 1, 0, std::ptr::null()) };
        if event.is_null() {
            return Err(resource::io_error(
                "create directory notification event",
                std::io::Error::last_os_error(),
            ));
        }
        let mut watch = Watch {
            file,
            buffer: vec![0; BUFFER_WORDS].into_boxed_slice(),
            overlapped: Box::new(Overlapped {
                internal: 0,
                internal_high: 0,
                offset: 0,
                offset_high: 0,
                event,
            }),
            pending: false,
            _memory: memory,
        };
        watch.arm()?;
        self.watches.insert(id, watch);
        Ok(())
    }

    pub fn poll(&mut self) -> Result<HashSet<u64>> {
        let mut changed = HashSet::new();
        for (id, watch) in &mut self.watches {
            let mut transferred = 0;
            let result = unsafe {
                GetOverlappedResult(
                    watch.file.as_raw_handle(),
                    &mut *watch.overlapped,
                    &mut transferred,
                    0,
                )
            };
            if result == 0 {
                let error = std::io::Error::last_os_error();
                match error.raw_os_error() {
                    Some(IO_INCOMPLETE) => continue,
                    Some(NOTIFY_ENUM_DIR) => {}
                    _ => return Err(resource::io_error("poll directory notification", error)),
                }
            }
            watch.pending = false;
            changed.insert(*id);
            watch.arm()?;
        }
        Ok(changed)
    }
}
