use super::*;
use crate::ux::filetree::FileIdentity;
use std::ffi::{CStr, CString, c_char, c_void};
use std::fs::File;
use std::os::fd::AsRawFd;
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

type CfRef = *const c_void;
type StreamRef = *mut c_void;
#[repr(C)]
struct StreamContext {
    version: isize,
    info: *mut c_void,
    retain: Option<unsafe extern "C" fn(*const c_void) -> *const c_void>,
    release: Option<unsafe extern "C" fn(*const c_void)>,
    description: Option<unsafe extern "C" fn(*const c_void) -> CfRef>,
}
#[link(name = "CoreFoundation", kind = "framework")]
unsafe extern "C" {
    static kCFTypeArrayCallBacks: u8;
    fn CFStringCreateWithFileSystemRepresentation(allocator: CfRef, path: *const c_char) -> CfRef;
    fn CFArrayCreate(
        allocator: CfRef,
        values: *const CfRef,
        count: isize,
        callbacks: *const c_void,
    ) -> CfRef;
    fn CFRelease(value: CfRef);
}
#[link(name = "CoreServices", kind = "framework")]
unsafe extern "C" {
    fn FSEventsGetCurrentEventId() -> u64;
    fn FSEventStreamCreate(
        allocator: CfRef,
        callback: unsafe extern "C" fn(
            StreamRef,
            *mut c_void,
            usize,
            *mut c_void,
            *const u32,
            *const u64,
        ),
        context: *mut StreamContext,
        paths: CfRef,
        since: u64,
        latency: f64,
        flags: u32,
    ) -> StreamRef;
    fn FSEventStreamSetDispatchQueue(stream: StreamRef, queue: *mut c_void);
    fn FSEventStreamStart(stream: StreamRef) -> u8;
    fn FSEventStreamStop(stream: StreamRef);
    fn FSEventStreamInvalidate(stream: StreamRef);
    fn FSEventStreamRelease(stream: StreamRef);
}
#[link(name = "System")]
unsafe extern "C" {
    fn dispatch_queue_create(label: *const c_char, attributes: *const c_void) -> *mut c_void;
    fn dispatch_sync_f(
        queue: *mut c_void,
        context: *mut c_void,
        work: unsafe extern "C" fn(*mut c_void),
    );
    fn dispatch_release(object: *mut c_void);
}
struct Queue(*mut c_void);
impl Drop for Queue {
    fn drop(&mut self) {
        unsafe {
            dispatch_release(self.0);
        }
    }
}
unsafe extern "C" fn drained(_: *mut c_void) {}
struct Cf(CfRef);
impl Drop for Cf {
    fn drop(&mut self) {
        unsafe {
            CFRelease(self.0);
        }
    }
}
struct Stream {
    queue: *mut c_void,
    raw: StreamRef,
    started: bool,
}
impl Drop for Stream {
    fn drop(&mut self) {
        unsafe {
            if self.started {
                FSEventStreamStop(self.raw);
            }
            FSEventStreamInvalidate(self.raw);
            dispatch_sync_f(self.queue, std::ptr::null_mut(), drained);
            FSEventStreamRelease(self.raw);
        }
    }
}
struct Events {
    ready: bool,
    paths: HashMap<PathBuf, u64>,
    changed: HashSet<u64>,
    since: u64,
}
struct Directory {
    _file: File,
    path: PathBuf,
}
pub struct Backend {
    stream: Option<Stream>,
    context: Box<Mutex<Events>>,
    directories: HashMap<u64, Directory>,
    reconfigure: bool,
    watched: HashSet<PathBuf>,
    queue: Queue,
}

/** Stop and drain the serial dispatch queue before releasing the callback context. */
unsafe extern "C" fn events(
    _: StreamRef,
    info: *mut c_void,
    count: usize,
    paths: *mut c_void,
    flags: *const u32,
    ids: *const u64,
) {
    let context = unsafe { &*info.cast::<Mutex<Events>>() };
    let mut events = context.lock().unwrap_or_else(|error| error.into_inner());
    if count == 0 {
        return;
    }
    let ids = unsafe { std::slice::from_raw_parts(ids, count) };
    let flags = unsafe { std::slice::from_raw_parts(flags, count) };
    if flags.iter().any(|flags| flags & 8 != 0) {
        events.since = unsafe { FSEventsGetCurrentEventId() };
    } else {
        /* RootChanged has event ID zero; it must not restart history from the beginning. */
        events.since = events.since.max(ids.iter().copied().max().unwrap_or(0));
    }
    for at in 0..count {
        let flags = flags[at];
        if flags & 0x10 != 0 {
            events.ready = true;
            continue;
        }
        /* Dropped history, root moves, and volume changes invalidate all registered directories. */
        if flags & 0xef != 0 {
            let watched: Vec<_> = events.paths.values().copied().collect();
            events.changed.extend(watched);
            break;
        }
        let path = unsafe { *paths.cast::<*const c_char>().add(at) };
        if path.is_null() {
            continue;
        }
        let path = Path::new(std::ffi::OsStr::from_bytes(
            unsafe { CStr::from_ptr(path) }.to_bytes(),
        ));
        for path in [Some(path), path.parent()].into_iter().flatten() {
            if let Some(id) = events.paths.get(path).copied() {
                events.changed.insert(id);
            }
        }
        if events.changed.len() == events.paths.len() {
            break;
        }
    }
}

impl Backend {
    pub fn new() -> Result<Self> {
        let queue =
            unsafe { dispatch_queue_create(c"yoz.filetree.watch".as_ptr(), std::ptr::null()) };
        if queue.is_null() {
            return Err(Error::limit("cannot allocate directory event queue"));
        }
        Ok(Self {
            queue: Queue(queue),
            stream: None,
            context: Box::new(Mutex::new(Events {
                paths: HashMap::new(),
                changed: HashSet::new(),
                since: unsafe { FSEventsGetCurrentEventId() },
                ready: false,
            })),
            directories: HashMap::new(),
            reconfigure: false,
            watched: HashSet::new(),
        })
    }
    pub fn remove(&mut self, id: u64) {
        if self.directories.remove(&id).is_some() {
            self.reconfigure = true;
        }
    }
    pub fn add(&mut self, id: u64, target: &Target) -> Result<()> {
        let file = std::fs::OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_EVTONLY | libc::O_CLOEXEC)
            .open(&*target.path)
            .map_err(|error| resource::io_error("open watched directory", error))?;
        if FileIdentity::from_file(&file)
            .map_err(|error| resource::io_error("identify watched directory", error))?
            != target.identity
            || !file
                .metadata()
                .map_err(|error| resource::io_error("verify watched directory", error))?
                .is_dir()
        {
            return Err(Error::stale("directory changed while registering watch"));
        }
        let mut path = [0u8; libc::PATH_MAX as usize];
        if unsafe { libc::fcntl(file.as_raw_fd(), libc::F_GETPATH, path.as_mut_ptr()) } < 0 {
            return Err(resource::io_error(
                "resolve watched directory",
                std::io::Error::last_os_error(),
            ));
        }
        let end = path
            .iter()
            .position(|byte| *byte == 0)
            .ok_or_else(|| Error::invalid("unterminated watched path"))?;
        let path = PathBuf::from(std::ffi::OsStr::from_bytes(&path[..end]));
        self.directories.insert(id, Directory { _file: file, path });
        self.reconfigure = true;
        Ok(())
    }
    fn configure(&mut self) -> Result<()> {
        self.reconfigure = false;
        /* FSEvents is recursive. Fold covered paths under existing roots to avoid redundant
         * kernel root watches; context.paths still limits observable coverage to admitted directories. */
        let roots: HashSet<_> = self
            .directories
            .values()
            .filter(|directory| {
                !self.directories.values().any(|other| {
                    other.path != directory.path && directory.path.starts_with(&other.path)
                })
            })
            .map(|directory| directory.path.clone())
            .collect();
        let changed = roots != self.watched;
        if changed {
            self.stream = None;
        }
        let mut context = self
            .context
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        context.paths = self
            .directories
            .iter()
            .map(|(id, directory)| (directory.path.clone(), *id))
            .collect();
        context
            .changed
            .retain(|id| self.directories.contains_key(id));
        if !changed {
            return Ok(());
        }
        if self.watched.is_empty() {
            context.since = unsafe { FSEventsGetCurrentEventId() };
        }
        self.watched = roots;
        context.ready = self.watched.is_empty();
        if context.ready {
            return Ok(());
        }
        let mut strings = Vec::new();
        for directory in &self.watched {
            let path = CString::new(directory.as_os_str().as_bytes())
                .map_err(|_| Error::invalid("watched path contains NUL"))?;
            let string = unsafe {
                CFStringCreateWithFileSystemRepresentation(std::ptr::null(), path.as_ptr())
            };
            if string.is_null() {
                return Err(Error::new(
                    crate::ux::treeview::ErrorCode::ProviderError,
                    "FSEvents cannot represent the watched directory path",
                ));
            }
            strings.push(Cf(string));
        }
        let pointers: Vec<_> = strings.iter().map(|string| string.0).collect();
        let array = unsafe {
            CFArrayCreate(
                std::ptr::null(),
                pointers.as_ptr(),
                pointers.len() as isize,
                (&raw const kCFTypeArrayCallBacks).cast(),
            )
        };
        if array.is_null() {
            return Err(Error::limit("cannot allocate watched directory list"));
        }
        let array = Cf(array);
        let mut stream_context = StreamContext {
            version: 0,
            info: (&*self.context as *const Mutex<Events>).cast_mut().cast(),
            retain: None,
            release: None,
            description: None,
        };
        /* FullHistory overlaps the first journal chunk when rebuilding coverage. Wait for
         * HistoryDone before publishing coverage and scheduling the registration scan. */
        let since = context.since;
        let raw = unsafe {
            FSEventStreamCreate(
                std::ptr::null(),
                events,
                &mut stream_context,
                array.0,
                since,
                0.01,
                0x96,
            )
        };
        if raw.is_null() {
            return Err(Error::new(
                crate::ux::treeview::ErrorCode::ProviderError,
                "cannot create FSEvents directory stream",
            ));
        }
        let mut stream = Stream {
            queue: self.queue.0,
            raw,
            started: false,
        };
        drop(context);
        unsafe {
            FSEventStreamSetDispatchQueue(raw, self.queue.0);
            stream.started = FSEventStreamStart(raw) != 0;
        }
        if !stream.started {
            return Err(Error::new(
                crate::ux::treeview::ErrorCode::ProviderError,
                "cannot start FSEvents directory stream",
            ));
        }
        self.stream = Some(stream);
        Ok(())
    }
    pub fn ready(&self) -> bool {
        self.context
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .ready
    }
    pub fn poll(&mut self) -> Result<HashSet<u64>> {
        if self.reconfigure {
            self.configure()?;
        }
        let mut context = self
            .context
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        Ok(std::mem::take(&mut context.changed))
    }
}
impl Drop for Backend {
    fn drop(&mut self) {
        self.stream = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_fsevents_history_and_root_change_preserve_the_resume_cursor() {
        let context = Mutex::new(Events {
            ready: false,
            paths: HashMap::from([(PathBuf::from("/watched"), 3)]),
            changed: HashSet::new(),
            since: 42,
        });
        let root = CString::new("/watched").unwrap();
        let mut paths = [root.as_ptr()];
        for (flag, id) in [(0x10, 43), (0x20, 0)] {
            unsafe {
                events(
                    std::ptr::null_mut(),
                    (&context as *const Mutex<Events>).cast_mut().cast(),
                    1,
                    paths.as_mut_ptr().cast(),
                    &flag,
                    &id,
                );
            }
        }
        let context = context.into_inner().unwrap();
        assert!(context.ready);
        assert_eq!(context.since, 43);
        assert_eq!(context.changed, HashSet::from([3]));
    }

    #[test]
    fn t_file_notifications_only_dirty_the_watched_parent() {
        let context = Mutex::new(Events {
            ready: true,
            paths: HashMap::from([
                (PathBuf::from("/watched"), 1),
                (PathBuf::from("/watched/sub"), 2),
            ]),
            changed: HashSet::new(),
            since: 42,
        });
        let file = CString::new("/watched/sub/file").unwrap();
        let mut paths = [file.as_ptr()];
        unsafe {
            events(
                std::ptr::null_mut(),
                (&context as *const Mutex<Events>).cast_mut().cast(),
                1,
                paths.as_mut_ptr().cast(),
                &0x11000,
                &43,
            );
        }
        let context = context.into_inner().unwrap();
        assert_eq!(context.changed, HashSet::from([2]));
    }
}
