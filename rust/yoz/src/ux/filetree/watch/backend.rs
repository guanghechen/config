use super::Target;
#[cfg(target_os = "linux")]
use crate::ux::filetree::Entry;
use crate::ux::filetree::resource;
use crate::ux::treeview::{Error, Result};
use std::collections::{HashMap, HashSet};
use std::sync::Arc;

pub(super) const EVENT_DRIVEN: bool = cfg!(any(target_os = "macos", target_os = "linux"));
pub(super) const RECURSIVE: bool = cfg!(target_os = "macos");

#[cfg(not(target_os = "linux"))]
pub(super) type Wake = std::sync::Condvar;
#[cfg(target_os = "linux")]
pub(super) use platform::Wake;

pub(super) fn wake() -> Result<Wake> {
    #[cfg(target_os = "linux")]
    return Wake::new();
    #[cfg(not(target_os = "linux"))]
    Ok(Wake::new())
}

pub(super) struct Registration {
    pub roots: usize,
    pub targets: HashSet<u64>,
    pub limited: bool,
    pub error: Option<Error>,
}

#[cfg(target_os = "macos")]
#[path = "macos.rs"]
mod platform;

#[cfg(windows)]
#[path = "windows.rs"]
mod platform;

#[cfg(target_os = "linux")]
mod platform {
    use super::*;
    use std::collections::BTreeSet;
    use std::ffi::OsString;
    use std::fs::File;
    use std::os::fd::{AsRawFd, FromRawFd};
    use std::os::unix::ffi::OsStrExt;
    use std::os::unix::fs::OpenOptionsExt;

    pub struct Wake(File);
    impl Wake {
        pub fn new() -> Result<Self> {
            let fd = crate::ux::filetree::io::file_descriptor(|| unsafe {
                libc::eventfd(0, libc::EFD_NONBLOCK | libc::EFD_CLOEXEC)
            })
            .map_err(|error| resource::io_error("create watch wakeup", error))?;
            Ok(Self(unsafe { File::from_raw_fd(fd) }))
        }

        pub fn notify_one(&self) {
            let value = 1u64;
            loop {
                let result =
                    unsafe { libc::write(self.0.as_raw_fd(), (&value as *const u64).cast(), 8) };
                if result >= 0
                    || std::io::Error::last_os_error().kind() != std::io::ErrorKind::Interrupted
                {
                    // EAGAIN means a wakeup is already pending.
                    return;
                }
            }
        }
    }

    pub struct Backend {
        fd: File,
        watches: HashMap<i32, (u64, Option<Arc<BTreeSet<OsString>>>)>,
    }
    impl Backend {
        pub fn wait(&self, wake: &Wake, timeout: Option<std::time::Duration>) -> Result<()> {
            let deadline = timeout.map(|timeout| std::time::Instant::now() + timeout);
            loop {
                let mut descriptors = [
                    libc::pollfd {
                        fd: self.fd.as_raw_fd(),
                        events: libc::POLLIN,
                        revents: 0,
                    },
                    libc::pollfd {
                        fd: wake.0.as_raw_fd(),
                        events: libc::POLLIN,
                        revents: 0,
                    },
                ];
                let timeout = deadline.map_or(-1, |deadline| {
                    deadline
                        .saturating_duration_since(std::time::Instant::now())
                        .as_millis()
                        .saturating_add(1)
                        .min(i32::MAX as u128) as i32
                });
                let result = unsafe { libc::poll(descriptors.as_mut_ptr(), 2, timeout) };
                if result < 0 {
                    let error = std::io::Error::last_os_error();
                    if error.kind() == std::io::ErrorKind::Interrupted {
                        continue;
                    }
                    return Err(resource::io_error(
                        "wait for directory notifications",
                        error,
                    ));
                }
                if descriptors
                    .iter()
                    .any(|fd| fd.revents & (libc::POLLERR | libc::POLLHUP | libc::POLLNVAL) != 0)
                {
                    return Err(Error::invalid("directory notification descriptor closed"));
                }
                if descriptors[1].revents & libc::POLLIN != 0 {
                    let mut value = 0u64;
                    // A signal between the inbox check and this wait remains readable.
                    unsafe {
                        libc::read(wake.0.as_raw_fd(), (&mut value as *mut u64).cast(), 8);
                    }
                }
                return Ok(());
            }
        }

        pub fn registration(&self) -> Registration {
            Registration {
                roots: self.watches.len(),
                targets: self.watches.values().map(|(id, _)| *id).collect(),
                limited: false,
                error: None,
            }
        }
        pub fn ready(&self) -> bool {
            true
        }
        pub fn new(_notify: Arc<dyn Fn() + Send + Sync>) -> Result<Self> {
            let fd = crate::ux::filetree::io::file_descriptor(|| unsafe {
                libc::inotify_init1(libc::IN_NONBLOCK | libc::IN_CLOEXEC)
            })
            .map_err(|error| resource::io_error("create directory watcher", error))?;
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
            /* inotify owns the inode after registration. Keeping our directory descriptor
             * open would defer IN_DELETE_SELF until the last descriptor closes. */
            self.watches.insert(wd, (id, target.names.clone()));
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
                } else if let Some((id, names)) = self.watches.get(&event.wd) {
                    let start = at + std::mem::size_of::<libc::inotify_event>();
                    let end = start.saturating_add(event.len as usize).min(count as usize);
                    let name = &bytes[start..end];
                    let name = &name[..name
                        .iter()
                        .position(|byte| *byte == 0)
                        .unwrap_or(name.len())];
                    if names.as_ref().is_none_or(|names| {
                        name.is_empty() || names.contains(std::ffi::OsStr::from_bytes(name))
                    }) {
                        changed.insert(*id);
                    }
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
        pub fn registration(&self) -> Registration {
            Registration {
                roots: 0,
                targets: HashSet::new(),
                limited: false,
                error: None,
            }
        }
        pub fn ready(&self) -> bool {
            true
        }
        pub fn new(_notify: Arc<dyn Fn() + Send + Sync>) -> Result<Self> {
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

#[cfg(not(target_os = "macos"))]
impl Backend {
    pub fn prioritize(&mut self, _: &[u64]) {}
}
