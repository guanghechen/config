use super::*;
use crate::ux::filetree::FileIdentity;
use crate::ux::treeview::memory::Charge;
use std::ffi::{CStr, CString, c_char, c_void};
use std::fs::File;
use std::os::fd::AsRawFd;
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

#[path = "routes.rs"]
mod routes;
use routes::Routes;

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
    routes: Routes,
    covered: HashSet<u64>,
    changed: HashSet<u64>,
    since: u64,
    notify: Arc<dyn Fn() + Send + Sync>,
}
struct Directory {
    identity: FileIdentity,
    path: PathBuf,
    interested: bool,
    priority: usize,
}
struct RootWatch {
    _file: File,
    identity: FileIdentity,
    path: PathBuf,
}
impl RootWatch {
    fn open(directory: &Directory) -> Result<Self> {
        let file = std::fs::OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_EVTONLY | libc::O_CLOEXEC)
            .open(&directory.path)
            .map_err(|error| resource::io_error("open watched root", error))?;
        if FileIdentity::from_file(&file)
            .map_err(|error| resource::io_error("identify watched root", error))?
            != directory.identity
            || !file
                .metadata()
                .map_err(|error| resource::io_error("verify watched root", error))?
                .is_dir()
        {
            return Err(Error::stale(
                "directory changed while registering watch root",
            ));
        }
        let mut path = [0u8; libc::PATH_MAX as usize];
        if unsafe { libc::fcntl(file.as_raw_fd(), libc::F_GETPATH, path.as_mut_ptr()) } < 0 {
            return Err(resource::io_error(
                "resolve watched root",
                std::io::Error::last_os_error(),
            ));
        }
        let end = path
            .iter()
            .position(|byte| *byte == 0)
            .ok_or_else(|| Error::invalid("unterminated watched root path"))?;
        let path = PathBuf::from(std::ffi::OsStr::from_bytes(&path[..end]));
        if path != directory.path {
            return Err(Error::stale("directory moved while registering watch root"));
        }
        Ok(Self {
            _file: file,
            identity: directory.identity,
            path,
        })
    }
}
pub struct Backend {
    stream: Option<Stream>,
    context: Box<Mutex<Events>>,
    directories: HashMap<u64, Directory>,
    roots: HashMap<u64, RootWatch>,
    limited: bool,
    registration_error: Option<Error>,
    reconfigure: bool,
    watched: HashMap<PathBuf, FileIdentity>,
    _memory: Charge,
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
    let was_ready = events.ready;
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
        if flags & 0xee != 0 {
            let Events {
                covered, changed, ..
            } = &mut *events;
            changed.extend(covered.iter().copied());
            break;
        }
        let path = unsafe { *paths.cast::<*const c_char>().add(at) };
        if path.is_null() {
            continue;
        }
        let path = Path::new(std::ffi::OsStr::from_bytes(
            unsafe { CStr::from_ptr(path) }.to_bytes(),
        ));
        let Events {
            routes,
            covered,
            changed,
            ..
        } = &mut *events;
        /* Directory replacement and coalesced subtrees also invalidate loaded descendants. */
        if flags & 1 != 0 || flags & 0x20000 != 0 && flags & 0xb00 != 0 {
            routes.descendants(path, |id| {
                if covered.contains(&id) {
                    changed.insert(id);
                }
            });
        }
        for path in [Some(path), path.parent()].into_iter().flatten() {
            if let Some(id) = routes.get(path).filter(|id| covered.contains(id)) {
                changed.insert(id);
            }
        }
        if events.changed.len() == events.covered.len() {
            break;
        }
    }
    if !events.changed.is_empty() || events.ready != was_ready {
        let notify = events.notify.clone();
        drop(events);
        notify();
    }
}

impl Backend {
    pub fn new(notify: Arc<dyn Fn() + Send + Sync>) -> Result<Self> {
        let queue =
            unsafe { dispatch_queue_create(c"yoz.filetree.watch".as_ptr(), std::ptr::null()) };
        if queue.is_null() {
            return Err(Error::limit("cannot allocate directory event queue"));
        }
        Ok(Self {
            queue: Queue(queue),
            stream: None,
            context: Box::new(Mutex::new(Events {
                routes: Routes::default(),
                covered: HashSet::new(),
                changed: HashSet::new(),
                since: unsafe { FSEventsGetCurrentEventId() },
                ready: false,
                notify,
            })),
            directories: HashMap::new(),
            roots: HashMap::new(),
            limited: false,
            registration_error: None,
            reconfigure: false,
            watched: HashMap::new(),
            _memory: Charge::new(0),
        })
    }
    pub fn remove(&mut self, id: u64) {
        if self.directories.remove(&id).is_some() {
            self.reconfigure = true;
        }
    }
    pub fn add(&mut self, id: u64, target: &Target) -> Result<()> {
        let path = std::fs::canonicalize(&*target.path)
            .map_err(|error| resource::io_error("resolve directory interest", error))?;
        let metadata = std::fs::metadata(&path)
            .map_err(|error| resource::io_error("verify directory interest", error))?;
        if !metadata.is_dir()
            || FileIdentity::at(&path, &metadata, true)
                .map_err(|error| resource::io_error("identify directory interest", error))?
                != target.identity
        {
            return Err(Error::stale("directory changed while registering interest"));
        }
        self.directories.insert(
            id,
            Directory {
                identity: target.identity,
                path,
                interested: !target.nodes.is_empty(),
                priority: usize::MAX,
            },
        );
        self.reconfigure = true;
        Ok(())
    }
    pub fn prioritize(&mut self, ids: &[u64]) {
        for (priority, id) in ids.iter().enumerate() {
            if let Some(directory) = self.directories.get_mut(id) {
                directory.priority = priority;
            }
        }
        self.reconfigure = true;
    }
    pub fn registration(&self) -> Registration {
        Registration {
            roots: self.roots.len(),
            targets: self
                .context
                .lock()
                .unwrap_or_else(|error| error.into_inner())
                .covered
                .clone(),
            limited: self.limited,
            error: self.registration_error.clone(),
        }
    }
    fn configure(&mut self) -> Result<()> {
        self.reconfigure = false;
        let mut routes = Routes::default();
        for (id, directory) in &self.directories {
            routes.insert(&directory.path, *id);
        }
        let mut candidates = routes.roots();
        candidates.sort_unstable_by_key(|id| (self.directories[id].priority, *id));
        self.limited = candidates.len() > super::super::LIMIT;
        self.registration_error = None;
        let mut previous = std::mem::take(&mut self.roots);
        for id in candidates.into_iter().take(super::super::LIMIT) {
            let directory = &self.directories[&id];
            let retained = previous
                .remove(&id)
                .filter(|root| root.identity == directory.identity && root.path == directory.path);
            let root = match retained
                .map(Ok)
                .unwrap_or_else(|| RootWatch::open(directory))
            {
                Ok(root) => root,
                Err(error) => {
                    self.registration_error = Some(error);
                    continue;
                }
            };
            self.roots.insert(id, root);
        }
        let watched: HashMap<_, _> = self
            .roots
            .values()
            .map(|root| (root.path.clone(), root.identity))
            .collect();
        let changed = watched != self.watched;
        if changed {
            self.stream = None;
        }
        let mut context = self
            .context
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let mut covered = HashSet::new();
        for root in self.roots.values() {
            routes.descendants(&root.path, |id| {
                if self.directories[&id].interested {
                    covered.insert(id);
                }
            });
        }
        let added: Vec<_> = covered.difference(&context.covered).copied().collect();
        context.changed.retain(|id| covered.contains(id));
        context.changed.extend(added);
        context.covered = covered;
        context.routes = routes;
        self._memory = Charge::new(
            self.directories.capacity() * (std::mem::size_of::<(u64, Directory)>() + 16)
                + self
                    .directories
                    .values()
                    .map(|directory| directory.path.capacity())
                    .sum::<usize>()
                + self.roots.capacity() * (std::mem::size_of::<(u64, RootWatch)>() + 16)
                + self
                    .roots
                    .values()
                    .map(|root| root.path.capacity() * 3)
                    .sum::<usize>()
                + context.routes.bytes() * 2
                + (context.covered.capacity() + context.changed.capacity()) * 24,
        );
        crate::ux::treeview::memory::check()?;
        if !changed {
            /* Failed initial roots have no stream that could finish replaying history. */
            if watched.is_empty() {
                context.ready = true;
            }
            return Ok(());
        }
        if self.watched.is_empty() {
            context.since = unsafe { FSEventsGetCurrentEventId() };
        }
        self.watched = watched;
        context.ready = self.watched.is_empty();
        if context.ready {
            return Ok(());
        }
        let mut strings = Vec::new();
        for directory in self.watched.keys() {
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
        let notifications = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let observed = notifications.clone();
        let mut routes = Routes::default();
        routes.insert(Path::new("/watched"), 3);
        let context = Mutex::new(Events {
            ready: false,
            routes,
            covered: HashSet::from([3]),
            changed: HashSet::new(),
            since: 42,
            notify: Arc::new(move || {
                observed.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            }),
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
        assert_eq!(notifications.load(std::sync::atomic::Ordering::Relaxed), 2);
        let context = context.into_inner().unwrap();
        assert!(context.ready);
        assert_eq!(context.since, 43);
        assert_eq!(context.changed, HashSet::from([3]));
    }

    #[test]
    fn t_file_notifications_only_dirty_the_watched_parent() {
        let mut routes = Routes::default();
        routes.insert(Path::new("/watched"), 1);
        routes.insert(Path::new("/watched/sub"), 2);
        let context = Mutex::new(Events {
            ready: true,
            routes,
            covered: HashSet::from([1, 2]),
            changed: HashSet::new(),
            since: 42,
            notify: Arc::new(|| {}),
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

    #[test]
    fn t_directory_events_invalidate_only_the_affected_interest_subtree() {
        for flag in [0x20800, 0x20200, 1] {
            let mut routes = Routes::default();
            for (path, id) in [
                ("/work", 1),
                ("/work/sub", 2),
                ("/work/sub/deep", 3),
                ("/work/sub-other", 4),
            ] {
                routes.insert(Path::new(path), id);
            }
            let context = Mutex::new(Events {
                ready: true,
                routes,
                covered: HashSet::from([1, 2, 3, 4]),
                changed: HashSet::new(),
                since: 42,
                notify: Arc::new(|| {}),
            });
            let path = CString::new("/work/sub").unwrap();
            let mut paths = [path.as_ptr()];
            unsafe {
                events(
                    std::ptr::null_mut(),
                    (&context as *const Mutex<Events>).cast_mut().cast(),
                    1,
                    paths.as_mut_ptr().cast(),
                    &flag,
                    &43,
                );
            }
            assert_eq!(
                context.into_inner().unwrap().changed,
                HashSet::from([1, 2, 3])
            );
        }
    }

    #[test]
    fn t_initial_root_registration_failure_can_report_and_recover() {
        use crate::ux::filetree::{Entry, tests::Directory as Fixture};
        let directory = Fixture::new();
        let target = || Target {
            identity: Entry::read(&directory.0).unwrap().identity,
            path: Arc::new(directory.0.clone()),
            nodes: Arc::new(vec![crate::ux::treeview::NodeId(1)]),
            names: None,
            _memory: Arc::new(Charge::new(0)),
        };
        let mut backend = Backend::new(Arc::new(|| {})).unwrap();
        backend.add(1, &target()).unwrap();
        std::fs::remove_dir(&directory.0).unwrap();
        assert!(backend.poll().unwrap().is_empty());
        let registration = backend.registration();
        assert_eq!(registration.roots, 0);
        assert!(registration.targets.is_empty());
        assert!(registration.error.is_some());
        assert!(backend.stream.is_none());
        assert!(
            backend.ready(),
            "no stream can deliver HistoryDone after registration failure"
        );

        std::fs::create_dir(&directory.0).unwrap();
        backend.add(1, &target()).unwrap();
        backend.poll().unwrap();
        let began = std::time::Instant::now();
        while !backend.ready() {
            backend.poll().unwrap();
            assert!(began.elapsed() < std::time::Duration::from_secs(5));
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        let registration = backend.registration();
        assert_eq!(registration.roots, 1);
        assert_eq!(registration.targets, HashSet::from([1]));
        assert!(registration.error.is_none());
    }

    #[test]
    fn t_many_directory_interests_share_one_root_and_one_descriptor() {
        use crate::ux::filetree::{Entry, tests::Directory as Fixture};
        let directory = Fixture::new();
        let target = |path: PathBuf, interested: bool| Target {
            identity: Entry::read(&path).unwrap().identity,
            path: Arc::new(path),
            nodes: Arc::new(if interested {
                vec![crate::ux::treeview::NodeId(1)]
            } else {
                Vec::new()
            }),
            names: None,
            _memory: Arc::new(Charge::new(0)),
        };
        let mut backend = Backend::new(Arc::new(|| {})).unwrap();
        backend.add(0, &target(directory.0.clone(), true)).unwrap();
        for index in 1..=96 {
            let path = directory.0.join(format!("dir-{index}"));
            std::fs::create_dir(&path).unwrap();
            backend.add(index, &target(path, true)).unwrap();
        }
        backend.prioritize(&(0..=96).collect::<Vec<_>>());
        let began = std::time::Instant::now();
        while !backend.ready() {
            backend.poll().unwrap();
            assert!(began.elapsed() < std::time::Duration::from_secs(5));
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        assert_eq!(backend.registration().roots, 1);
        assert_eq!(backend.registration().targets.len(), 97);
        assert!(!backend.registration().limited);
        assert_eq!(backend.roots.len(), 1);
        let stream = backend.stream.as_ref().unwrap().raw;

        /* Narrowing the view keeps the workspace subscription while changing its routing interest. */
        backend.add(0, &target(directory.0.clone(), false)).unwrap();
        for index in 2..=96 {
            backend.remove(index);
        }
        backend.prioritize(&[0, 1]);
        backend.poll().unwrap();
        assert_eq!(backend.registration().roots, 1);
        assert_eq!(backend.registration().targets, HashSet::from([1]));
        assert_eq!(backend.stream.as_ref().unwrap().raw, stream);
        assert_eq!(
            backend.roots.values().next().unwrap().path,
            std::fs::canonicalize(&directory.0).unwrap()
        );
    }
}
