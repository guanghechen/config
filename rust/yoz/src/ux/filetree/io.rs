use super::{Entry, FileIdentity, Kind};
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
#[cfg(unix)]
use std::os::fd::{AsRawFd, FromRawFd};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};

pub(crate) const COPY_BUFFER: usize = 1024 * 1024;

#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct Signature {
    pub identity: FileIdentity,
    pub kind: Kind,
    #[cfg(windows)]
    directory_link: bool,
    link: Option<PathBuf>,
    target: Option<FileIdentity>,
}
impl Signature {
    pub fn entry(entry: &Entry, parent: bool) -> Self {
        Self {
            identity: entry.identity,
            kind: entry.kind,
            /* Windows file attributes preserve the link's intrinsic directory bit,
             * including when its referent is absent. They are already in the payload. */
            #[cfg(windows)]
            directory_link: entry.kind == Kind::Link && entry.mode & 0x10 != 0,
            link: entry.link.clone(),
            target: if parent && entry.kind == Kind::Link {
                entry.target_identity()
            } else {
                None
            },
        }
    }
    pub fn read(path: &Path, parent: bool) -> io::Result<Self> {
        let metadata = fs::symlink_metadata(path)?;
        let kind = Kind::metadata(&metadata);
        let target = if parent && kind == Kind::Link {
            let metadata = fs::metadata(path)?;
            if !metadata.is_dir() {
                return Err(io::Error::new(
                    io::ErrorKind::NotADirectory,
                    "target parent is not a directory",
                ));
            }
            Some(FileIdentity::at(path, &metadata, true)?)
        } else {
            None
        };
        Ok(Self {
            identity: FileIdentity::at(path, &metadata, false)?,
            kind,
            #[cfg(windows)]
            directory_link: {
                use std::os::windows::fs::FileTypeExt;
                metadata.file_type().is_symlink_dir()
            },
            link: if kind == Kind::Link {
                Some(fs::read_link(path)?)
            } else {
                None
            },
            target,
        })
    }
    pub fn verify(&self, path: &Path, parent: bool) -> io::Result<()> {
        if Self::read(path, parent)? == *self {
            Ok(())
        } else {
            Err(io::Error::new(
                io::ErrorKind::AlreadyExists,
                "resource identity or type changed",
            ))
        }
    }
}

pub(crate) fn existing(path: &Path) -> io::Result<Option<Signature>> {
    match Signature::read(path, false) {
        Ok(value) => Ok(Some(value)),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(error),
    }
}

pub(crate) fn verify_target(path: &Path, expected: Option<&Signature>) -> io::Result<()> {
    if existing(path)?.as_ref() == expected {
        Ok(())
    } else {
        Err(io::Error::new(
            io::ErrorKind::AlreadyExists,
            "destination changed since confirmation",
        ))
    }
}

pub(crate) fn cancelled(cancel: &AtomicBool) -> io::Result<()> {
    if cancel.load(Ordering::Acquire) {
        Err(io::Error::new(
            io::ErrorKind::Interrupted,
            "file operation cancelled",
        ))
    } else {
        Ok(())
    }
}

#[cfg(unix)]
fn c_path(path: &Path) -> io::Result<std::ffi::CString> {
    use std::os::unix::ffi::OsStrExt;
    std::ffi::CString::new(path.as_os_str().as_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "path contains NUL"))
}

/** Publish without following the final destination link or clobbering an unconfirmed new entry. */
pub(crate) fn rename(source: &Path, target: &Path, replace: bool) -> io::Result<()> {
    if replace {
        return fs::rename(source, target);
    }
    #[cfg(target_os = "macos")]
    {
        let source = c_path(source)?;
        let target = c_path(target)?;
        let result =
            unsafe { libc::renamex_np(source.as_ptr(), target.as_ptr(), libc::RENAME_EXCL) };
        if result == 0 {
            Ok(())
        } else {
            Err(io::Error::last_os_error())
        }
    }
    #[cfg(target_os = "linux")]
    {
        let source = c_path(source)?;
        let target = c_path(target)?;
        let result = unsafe {
            libc::renameat2(
                libc::AT_FDCWD,
                source.as_ptr(),
                libc::AT_FDCWD,
                target.as_ptr(),
                libc::RENAME_NOREPLACE,
            )
        };
        if result == 0 {
            Ok(())
        } else {
            Err(io::Error::last_os_error())
        }
    }
    #[cfg(windows)]
    {
        use std::os::windows::ffi::OsStrExt;
        #[link(name = "kernel32")]
        unsafe extern "system" {
            fn MoveFileExW(source: *const u16, target: *const u16, flags: u32) -> i32;
        }
        let source: Vec<_> = source.as_os_str().encode_wide().chain(Some(0)).collect();
        let target: Vec<_> = target.as_os_str().encode_wide().chain(Some(0)).collect();
        if unsafe { MoveFileExW(source.as_ptr(), target.as_ptr(), 0) } != 0 {
            Ok(())
        } else {
            Err(io::Error::last_os_error())
        }
    }
    #[cfg(not(any(target_os = "macos", target_os = "linux", windows)))]
    {
        Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "atomic no-replace rename is unavailable",
        ))
    }
}

pub(crate) struct Destination {
    pub path: PathBuf,
    pub parent: Signature,
    pub expected: Option<Signature>,
}
impl Destination {
    pub fn verify(&self) -> io::Result<()> {
        let parent = self.path.parent().ok_or_else(|| {
            io::Error::new(io::ErrorKind::InvalidInput, "destination has no parent")
        })?;
        self.parent.verify(parent, true)?;
        verify_target(&self.path, self.expected.as_ref())
    }
}

#[derive(Debug)]
struct CleanupError {
    original: io::Error,
    cleanup: io::Error,
}
impl std::fmt::Display for CleanupError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            formatter,
            "{} (os={:?}); temporary cleanup: {} (os={:?})",
            self.original,
            self.original.raw_os_error(),
            self.cleanup,
            self.cleanup.raw_os_error()
        )
    }
}
impl std::error::Error for CleanupError {}
pub(crate) fn os_code(error: &io::Error) -> Option<i32> {
    error.raw_os_error().or_else(|| {
        error
            .get_ref()
            .and_then(|error| error.downcast_ref::<CleanupError>())
            .and_then(|error| error.original.raw_os_error())
    })
}
struct Temporary {
    #[cfg(unix)]
    parent: File,
    file: Option<File>,
    path: PathBuf,
    identity: Option<FileIdentity>,
    created: bool,
    directory: bool,
}
impl Temporary {
    fn new(target: &Destination, directory: bool) -> io::Result<Self> {
        let parent = target.path.parent().expect("validated destination");
        let path = parent.join(format!(".yoz-filetree-{}.tmp", uuid::Uuid::new_v4()));
        #[cfg(unix)]
        let parent = {
            use std::os::unix::fs::OpenOptionsExt;
            let file = OpenOptions::new()
                .read(true)
                .custom_flags(libc::O_DIRECTORY | libc::O_CLOEXEC)
                .open(parent)?;
            if FileIdentity::from_file(&file)?
                != target.parent.target.unwrap_or(target.parent.identity)
            {
                return Err(io::Error::new(
                    io::ErrorKind::AlreadyExists,
                    "destination parent changed before temporary creation",
                ));
            }
            file
        };
        Ok(Self {
            #[cfg(unix)]
            parent,
            file: None,
            path,
            identity: None,
            created: false,
            directory,
        })
    }
    #[cfg(unix)]
    fn name(&self) -> io::Result<std::ffi::CString> {
        c_path(Path::new(self.path.file_name().expect("temporary name")))
    }
    fn entry_identity(&self) -> io::Result<Option<FileIdentity>> {
        #[cfg(unix)]
        {
            let mut metadata: libc::stat = unsafe { std::mem::zeroed() };
            if unsafe {
                libc::fstatat(
                    self.parent.as_raw_fd(),
                    self.name()?.as_ptr(),
                    &mut metadata,
                    libc::AT_SYMLINK_NOFOLLOW,
                )
            } < 0
            {
                let error = io::Error::last_os_error();
                return if error.kind() == io::ErrorKind::NotFound {
                    Ok(None)
                } else {
                    Err(error)
                };
            }
            if metadata.st_ino == 0 {
                return Err(io::Error::new(
                    io::ErrorKind::Unsupported,
                    "temporary identity unavailable",
                ));
            }
            Ok(Some(FileIdentity {
                volume: metadata.st_dev as u64,
                file: metadata.st_ino as u128,
            }))
        }
        #[cfg(not(unix))]
        {
            existing(&self.path).map(|entry| entry.map(|entry| entry.identity))
        }
    }
    fn open_file(&self, mode: u32) -> io::Result<File> {
        #[cfg(unix)]
        {
            let fd = unsafe {
                libc::openat(
                    self.parent.as_raw_fd(),
                    self.name()?.as_ptr(),
                    libc::O_WRONLY
                        | libc::O_CREAT
                        | libc::O_EXCL
                        | libc::O_CLOEXEC
                        | libc::O_NOFOLLOW,
                    mode,
                )
            };
            if fd < 0 {
                Err(io::Error::last_os_error())
            } else {
                Ok(unsafe { File::from_raw_fd(fd) })
            }
        }
        #[cfg(not(unix))]
        {
            let _ = mode;
            OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&self.path)
        }
    }
    fn publish(&mut self, target: &Destination) -> io::Result<()> {
        target.verify()?;
        if self.entry_identity()? != self.identity || self.identity.is_none() {
            return Err(io::Error::new(
                io::ErrorKind::AlreadyExists,
                "temporary output was replaced",
            ));
        }
        #[cfg(unix)]
        {
            let name = self.name()?;
            let target_name = c_path(Path::new(
                target.path.file_name().expect("destination name"),
            ))?;
            let fd = self.parent.as_raw_fd();
            let result = if target.expected.is_some() {
                unsafe { libc::renameat(fd, name.as_ptr(), fd, target_name.as_ptr()) }
            } else {
                #[cfg(target_os = "macos")]
                {
                    unsafe {
                        libc::renameatx_np(
                            fd,
                            name.as_ptr(),
                            fd,
                            target_name.as_ptr(),
                            libc::RENAME_EXCL,
                        )
                    }
                }
                #[cfg(target_os = "linux")]
                {
                    unsafe {
                        libc::renameat2(
                            fd,
                            name.as_ptr(),
                            fd,
                            target_name.as_ptr(),
                            libc::RENAME_NOREPLACE,
                        )
                    }
                }
                #[cfg(not(any(target_os = "macos", target_os = "linux")))]
                {
                    return Err(io::Error::new(
                        io::ErrorKind::Unsupported,
                        "atomic no-replace rename is unavailable",
                    ));
                }
            };
            if result < 0 {
                return Err(io::Error::last_os_error());
            }
        }
        #[cfg(not(unix))]
        rename(&self.path, &target.path, target.expected.is_some())?;
        self.created = false;
        Ok(())
    }
    fn clean(&mut self) -> io::Result<()> {
        if !self.created {
            return Ok(());
        }
        let Some(identity) = self.identity else {
            return Err(io::Error::other(format!(
                "cannot verify temporary output identity: {}",
                self.path.display()
            )));
        };
        {
            match self.entry_identity()? {
                Some(entry) if entry == identity => {
                    #[cfg(unix)]
                    {
                        if unsafe {
                            libc::unlinkat(
                                self.parent.as_raw_fd(),
                                self.name()?.as_ptr(),
                                if self.directory {
                                    libc::AT_REMOVEDIR
                                } else {
                                    0
                                },
                            )
                        } < 0
                        {
                            return Err(io::Error::last_os_error());
                        }
                    }
                    #[cfg(not(unix))]
                    {
                        if self.directory {
                            fs::remove_dir(&self.path)?;
                        } else {
                            fs::remove_file(&self.path)?;
                        }
                    }
                }
                Some(_) => {
                    return Err(io::Error::new(
                        io::ErrorKind::AlreadyExists,
                        "temporary output was replaced",
                    ));
                }
                None => {}
            }
            self.created = false;
            self.identity = None;
        }
        Ok(())
    }
}
impl Drop for Temporary {
    fn drop(&mut self) {
        let _ = self.clean();
    }
}

pub(crate) fn copy(
    source: &Path,
    expected: &Signature,
    target: &Destination,
    cancel: &AtomicBool,
    progress: &AtomicU64,
) -> io::Result<()> {
    cancelled(cancel)?;
    expected.verify(source, false)?;
    target.verify()?;
    let mut temporary = Temporary::new(target, false)?;
    let result: io::Result<()> = (|| {
        match expected.kind {
            Kind::File => {
                let mut options = OpenOptions::new();
                options.read(true);
                #[cfg(unix)]
                {
                    use std::os::unix::fs::OpenOptionsExt;
                    options.custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC);
                }
                #[cfg(windows)]
                {
                    use std::os::windows::fs::OpenOptionsExt;
                    options.custom_flags(0x00200000);
                }
                let mut input = options.open(source)?;
                if !input.metadata()?.is_file()
                    || FileIdentity::from_file(&input)? != expected.identity
                {
                    return Err(io::Error::new(
                        io::ErrorKind::AlreadyExists,
                        "source changed before open",
                    ));
                }
                temporary.file = Some(temporary.open_file(0o600)?);
                temporary.created = true;
                let output = temporary.file.as_mut().expect("created output");
                temporary.identity = Some(FileIdentity::from_file(output)?);
                let mut buffer = vec![0u8; COPY_BUFFER];
                loop {
                    cancelled(cancel)?;
                    let size = input.read(&mut buffer)?;
                    if size == 0 {
                        break;
                    }
                    output.write_all(&buffer[..size])?;
                    progress.fetch_add(size as u64, Ordering::Relaxed);
                }
                output.set_permissions(input.metadata()?.permissions())?;
            }
            Kind::Link => {
                let text = expected.link.as_ref().ok_or_else(|| {
                    io::Error::new(io::ErrorKind::InvalidData, "missing link text")
                })?;
                #[cfg(unix)]
                {
                    if unsafe {
                        libc::symlinkat(
                            c_path(text)?.as_ptr(),
                            temporary.parent.as_raw_fd(),
                            temporary.name()?.as_ptr(),
                        )
                    } < 0
                    {
                        return Err(io::Error::last_os_error());
                    }
                }
                #[cfg(windows)]
                {
                    if expected.directory_link {
                        std::os::windows::fs::symlink_dir(text, &temporary.path)?;
                        temporary.directory = true;
                    } else {
                        std::os::windows::fs::symlink_file(text, &temporary.path)?;
                    }
                }
                temporary.created = true;
                temporary.identity = temporary.entry_identity()?;
            }
            _ => {
                return Err(io::Error::new(
                    io::ErrorKind::Unsupported,
                    "entry is not a regular file or symlink",
                ));
            }
        }
        cancelled(cancel)?;
        expected.verify(source, false)?;
        target.verify()?;
        temporary.publish(target)?;
        temporary.created = false;
        temporary.identity = None;
        Ok(())
    })();
    if let Err(error) = result {
        if let Err(cleanup) = temporary.clean() {
            return Err(io::Error::new(
                error.kind(),
                CleanupError {
                    original: error,
                    cleanup,
                },
            ));
        }
        return Err(error);
    }
    Ok(())
}

pub(crate) fn remove(path: &Path, expected: &Signature, cancel: &AtomicBool) -> io::Result<()> {
    cancelled(cancel)?;
    expected.verify(path, false)?;
    #[cfg(windows)]
    if expected.directory_link {
        return fs::remove_dir(path);
    }
    if expected.kind == Kind::Directory {
        fs::remove_dir(path)
    } else {
        fs::remove_file(path)
    }
}

/** Publish an empty directory only after checking the confirmed destination. */
pub(crate) fn create_directory(target: &Destination) -> io::Result<()> {
    create_new(target, true, 0o700).map(|_| ())
}

pub(crate) fn create_new(
    target: &Destination,
    directory: bool,
    mode: u32,
) -> io::Result<FileIdentity> {
    target.verify()?;
    let mut temporary = Temporary::new(target, directory)?;
    let result: io::Result<FileIdentity> = (|| {
        if directory {
            #[cfg(unix)]
            {
                if unsafe {
                    libc::mkdirat(
                        temporary.parent.as_raw_fd(),
                        temporary.name()?.as_ptr(),
                        mode as libc::mode_t,
                    )
                } < 0
                {
                    return Err(io::Error::last_os_error());
                }
            }
            #[cfg(not(unix))]
            fs::create_dir(&temporary.path)?;
        } else {
            temporary.file = Some(temporary.open_file(mode)?);
        }
        temporary.created = true;
        temporary.identity = temporary.entry_identity()?;
        target.verify()?;
        temporary.publish(target)?;
        temporary.created = false;
        Ok(temporary.identity.expect("published output identity"))
    })();
    if let Err(error) = result {
        if let Err(cleanup) = temporary.clean() {
            return Err(io::Error::new(
                error.kind(),
                CleanupError {
                    original: error,
                    cleanup,
                },
            ));
        }
        return Err(error);
    }
    result
}

pub(crate) fn directory_permissions(
    source: &Path,
    expected: &Signature,
    target: &Path,
    target_expected: &Signature,
) -> io::Result<Entry> {
    expected.verify(source, false)?;
    target_expected.verify(target, false)?;
    let permissions = fs::metadata(source)?.permissions();
    let mut options = OpenOptions::new();
    options.read(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC);
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::OpenOptionsExt;
        options
            .access_mode(0x80 | 0x100)
            .custom_flags(0x02000000 | 0x00200000);
    }
    let directory = options.open(target)?;
    if FileIdentity::from_file(&directory)? != target_expected.identity {
        return Err(io::Error::new(
            io::ErrorKind::AlreadyExists,
            "destination directory changed before permissions update",
        ));
    }
    directory.set_permissions(permissions)?;
    Entry::from_metadata(target, &directory.metadata()?)
}
