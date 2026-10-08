use super::{CleanupError, Copier, Destination, Signature, Temporary, c_path, cancelled};
use crate::ux::filetree::memory::{Memory, Reservation};
use crate::ux::filetree::{Entry, FileIdentity, Kind};
use std::collections::HashMap;
use std::ffi::{CStr, OsStr, OsString};
use std::fs::{File, Permissions};
use std::io;
use std::os::fd::{AsRawFd, FromRawFd};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::PermissionsExt;
use std::path::{Component, Path};
use std::sync::atomic::AtomicBool;
use std::sync::{Arc, LazyLock, Mutex, Weak};

#[derive(Default)]
struct Registry {
    directories: HashMap<FileIdentity, Weak<Private>>,
    roots: Vec<Weak<Private>>,
    scans: Vec<Weak<Hidden>>,
}

struct Private {
    parent: FileIdentity,
    name: OsString,
    identity: FileIdentity,
    _memory: Reservation,
}

struct Hidden {
    parent: FileIdentity,
    roots: Mutex<Vec<Arc<Private>>>,
}

static REGISTRY: LazyLock<Mutex<Registry>> = LazyLock::new(|| Mutex::new(Registry::default()));

#[cfg(test)]
mod tests;

/** A directory iterator may still return an old private name after its root was published. */
pub(crate) struct Filter(Arc<Hidden>);

impl Filter {
    pub fn new(parent: FileIdentity) -> Self {
        let mut registry = REGISTRY.lock().unwrap_or_else(|error| error.into_inner());
        registry.scans.retain(|scan| scan.strong_count() != 0);
        let mut roots = Vec::new();
        for private in registry.roots.iter().filter_map(Weak::upgrade) {
            if private.parent == parent {
                roots.push(private);
            }
        }
        let result = Self(Arc::new(Hidden {
            parent,
            roots: Mutex::new(roots),
        }));
        registry.scans.push(Arc::downgrade(&result.0));
        result
    }

    pub fn read(&self, path: &Path) -> io::Result<Option<Entry>> {
        observe(path, Some(&self.0))
    }
}

pub(crate) fn private_directory(identity: FileIdentity) -> bool {
    REGISTRY
        .lock()
        .unwrap_or_else(|error| error.into_inner())
        .directories
        .get(&identity)
        .and_then(Weak::upgrade)
        .is_some()
}

pub(crate) fn read(path: &Path) -> io::Result<Option<Entry>> {
    observe(path, None)
}

fn observe(path: &Path, scan: Option<&Hidden>) -> io::Result<Option<Entry>> {
    let private_name = path
        .file_name()
        .is_some_and(|name| name.as_bytes().starts_with(b".yoz-filetree-"));
    /* Namespace creation and publication hold this same gate. Ordinary file metadata
     * remains parallel; only a possible private name needs the gate around its read. */
    if private_name {
        let registry = REGISTRY.lock().unwrap_or_else(|error| error.into_inner());
        return match Entry::read(path) {
            Ok(entry)
                if registry
                    .directories
                    .get(&entry.identity)
                    .and_then(Weak::upgrade)
                    .is_some() =>
            {
                Ok(None)
            }
            Ok(entry) => Ok(Some(entry)),
            Err(error)
                if error.kind() == io::ErrorKind::NotFound
                    && scan.is_some_and(|scan| {
                        scan.roots
                            .lock()
                            .unwrap_or_else(|error| error.into_inner())
                            .iter()
                            .any(|root| Some(root.name.as_os_str()) == path.file_name())
                    }) =>
            {
                Ok(None)
            }
            Err(error) => Err(error),
        };
    }
    let entry = Entry::read(path)?;
    if entry.kind == Kind::Directory && private_directory(entry.identity) {
        return Ok(None);
    }
    Ok(Some(entry))
}

mod journal;
use journal::Journal;

/** A bounded filesystem ownership journal, independent of Filetree's browse nodes. */
pub(crate) struct Staging {
    temporary: Temporary,
    root: Arc<File>,
    private: Arc<Private>,
    entries: Journal,
    directory: (usize, Arc<File>),
    damaged: bool,
}

fn changed(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::AlreadyExists, message)
}

fn capacity() -> io::Error {
    io::Error::other(crate::ux::treeview::Error::limit(
        "copy staging and results exceed task capacity",
    ))
}

fn identity_at(parent: &File, name: &OsStr) -> io::Result<Option<(FileIdentity, Kind)>> {
    let mut metadata: libc::stat = unsafe { std::mem::zeroed() };
    if unsafe {
        libc::fstatat(
            parent.as_raw_fd(),
            c_path(Path::new(name))?.as_ptr(),
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
            "staged entry identity unavailable",
        ));
    }
    let kind = match metadata.st_mode & libc::S_IFMT {
        libc::S_IFREG => Kind::File,
        libc::S_IFDIR => Kind::Directory,
        libc::S_IFLNK => Kind::Link,
        _ => Kind::Other,
    };
    Ok(Some((
        FileIdentity {
            volume: metadata.st_dev as u64,
            file: metadata.st_ino as u128,
        },
        kind,
    )))
}

fn open_directory(parent: &File, name: &OsStr, expected: FileIdentity) -> io::Result<Arc<File>> {
    let name = c_path(Path::new(name))?;
    let fd = super::file_descriptor(|| unsafe {
        libc::openat(
            parent.as_raw_fd(),
            name.as_ptr(),
            libc::O_RDONLY | libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC,
        )
    })?;
    let file = unsafe { File::from_raw_fd(fd) };
    if FileIdentity::from_file(&file)? != expected {
        return Err(changed("private directory identity changed"));
    }
    Ok(Arc::new(file))
}

impl Staging {
    pub fn new(
        target: &Destination,
        permissions: Permissions,
        memory: Arc<Memory>,
    ) -> io::Result<Self> {
        target.verify()?;
        if target.expected.is_some() {
            return Err(changed("directory staging requires an absent destination"));
        }
        let mut temporary = Temporary::new(target, true, None)?;
        let parent = FileIdentity::from_file(&temporary.parent)?;
        let name = temporary
            .path
            .file_name()
            .expect("private root name")
            .to_owned();
        let mut registry = REGISTRY.lock().unwrap_or_else(|error| error.into_inner());
        registry.scans.retain(|scan| scan.strong_count() != 0);
        let bytes = 65536 + temporary.path.as_os_str().len() * 2 + registry.scans.len() * 32 + 2048;
        let charge = memory.reserve(bytes).map_err(io::Error::other)?;
        let mut entries = Journal::new(&memory)?;
        entries.push(None, &name, Kind::Directory)?;
        entries.directory_mut(0).permissions = Some(permissions);
        if unsafe {
            libc::mkdirat(
                temporary.parent.as_raw_fd(),
                temporary.name()?.as_ptr(),
                0o700,
            )
        } < 0
        {
            return Err(io::Error::last_os_error());
        }
        temporary.created = true;
        let opened = (|| {
            temporary.identity = temporary.entry_identity()?;
            let identity = temporary
                .identity
                .ok_or_else(|| changed("private root disappeared"))?;
            open_directory(&temporary.parent, &name, identity).map(|root| (identity, root))
        })();
        let (identity, root) = match opened {
            Ok(opened) => opened,
            Err(error) => {
                return Err(match temporary.clean() {
                    Ok(()) => error,
                    Err(cleanup) => io::Error::new(
                        error.kind(),
                        format!("{error}; {}: {cleanup}", temporary.path.display()),
                    ),
                });
            }
        };
        let private = Arc::new(Private {
            parent,
            name: name.clone(),
            identity,
            _memory: charge,
        });
        for scan in registry.scans.iter().filter_map(Weak::upgrade) {
            if scan.parent == parent {
                scan.roots
                    .lock()
                    .unwrap_or_else(|error| error.into_inner())
                    .push(private.clone());
            }
        }
        registry
            .directories
            .insert(identity, Arc::downgrade(&private));
        registry.roots.push(Arc::downgrade(&private));
        drop(registry);
        entries[0].set_identity(Some(identity));
        Ok(Self {
            temporary,
            directory: (0, root.clone()),
            root,
            private,
            entries,
            damaged: false,
        })
    }

    pub fn damaged(&self) -> bool {
        self.damaged
    }

    pub fn file(&self) -> &File {
        &self.root
    }

    fn directory(&mut self, index: usize) -> io::Result<Arc<File>> {
        if self.entries[self.directory.0].identity().is_none() {
            self.directory = (0, self.root.clone());
        }
        if index == 0 {
            return Ok(self.root.clone());
        }
        if self.directory.0 == index {
            return Ok(self.directory.1.clone());
        }
        let expected = self.entries[index].identity().expect("owned directory");
        let file = if self.entries[index].parent() == Some(self.directory.0) {
            open_directory(&self.directory.1, &self.entries[index].name, expected)?
        } else if self.entries[self.directory.0].parent() == Some(index) {
            match open_directory(&self.directory.1, OsStr::new(".."), expected) {
                Ok(file) => file,
                Err(_) => self.from_root(index)?,
            }
        } else {
            self.from_root(index)?
        };
        self.directory = (index, file.clone());
        Ok(file)
    }

    fn from_root(&self, index: usize) -> io::Result<Arc<File>> {
        let mut path = Vec::new();
        let mut node = index;
        while node != 0 {
            path.push(node);
            node = self.entries[node].parent().expect("staging ancestor");
        }
        let mut file = self.root.clone();
        for node in path.into_iter().rev() {
            file = open_directory(
                &file,
                &self.entries[node].name,
                self.entries[node].identity().expect("owned ancestor"),
            )?;
        }
        Ok(file)
    }

    fn reserve(&mut self, parent: usize, name: &OsStr, kind: Kind) -> io::Result<usize> {
        #[cfg(test)]
        let _span =
            crate::ux::filetree::profile::span(crate::ux::filetree::profile::Stage::Journal);
        let mut components = Path::new(name).components();
        if !matches!(components.next(), Some(Component::Normal(_))) || components.next().is_some() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "staging name must be one component",
            ));
        }
        self.entries.push(Some(parent), name, kind)
    }

    fn discard_last(&mut self) {
        self.entries.pop();
    }

    pub fn create_directory(
        &mut self,
        parent: usize,
        name: &OsStr,
        permissions: Permissions,
    ) -> io::Result<usize> {
        let file = self.directory(parent)?;
        let index = self.reserve(parent, name, Kind::Directory)?;
        let mut registry = REGISTRY.lock().unwrap_or_else(|error| error.into_inner());
        if unsafe { libc::mkdirat(file.as_raw_fd(), c_path(Path::new(name))?.as_ptr(), 0o700) } < 0
        {
            self.discard_last();
            return Err(io::Error::last_os_error());
        }
        let identity = identity_at(&file, name)
            .and_then(|entry| entry.ok_or_else(|| changed("staged directory disappeared")))
            .inspect_err(|_| self.damaged = true)?;
        if identity.1 != Kind::Directory {
            self.damaged = true;
            return Err(changed("staged directory replaced"));
        }
        self.entries[index].set_identity(Some(identity.0));
        self.entries.directory_mut(index).permissions = Some(permissions);
        self.entries.directory_mut(parent).children += 1;
        registry
            .directories
            .insert(identity.0, Arc::downgrade(&self.private));
        Ok(index)
    }

    pub fn copy(
        &mut self,
        copier: &mut Copier,
        source: &Path,
        expected: &Signature,
        parent: usize,
        name: &OsStr,
        cancel: &AtomicBool,
        progress: impl Fn(u64),
    ) -> io::Result<()> {
        #[cfg(test)]
        let _span =
            crate::ux::filetree::profile::span(crate::ux::filetree::profile::Stage::Staging);
        cancelled(cancel)?;
        let mut input = copier.open_source(source, expected)?;
        if !matches!(expected.kind, Kind::File | Kind::Link) {
            return Err(io::Error::new(
                io::ErrorKind::Unsupported,
                "entry is not a regular file or symlink",
            ));
        }
        let directory = self.directory(parent)?;
        let index = self.reserve(parent, name, expected.kind)?;
        let result = (|| {
            if let Some(input) = input.as_mut() {
                let fd = {
                    #[cfg(test)]
                    let _span = crate::ux::filetree::profile::span(
                        crate::ux::filetree::profile::Stage::CreateCall,
                    );
                    let name = c_path(Path::new(name))?;
                    super::file_descriptor(|| unsafe {
                        libc::openat(
                            directory.as_raw_fd(),
                            name.as_ptr(),
                            libc::O_WRONLY
                                | libc::O_CREAT
                                | libc::O_EXCL
                                | libc::O_NOFOLLOW
                                | libc::O_CLOEXEC,
                            0o600,
                        )
                    })?
                };
                let mut output = unsafe { File::from_raw_fd(fd) };
                self.entries[index].set_identity(Some(
                    FileIdentity::from_file(&output).inspect_err(|_| self.damaged = true)?,
                ));
                self.entries.directory_mut(parent).children += 1;
                copier.stream(&mut input.file, &mut output, cancel, &progress)?;
                #[cfg(test)]
                {
                    let _span = crate::ux::filetree::profile::span(
                        crate::ux::filetree::profile::Stage::Close,
                    );
                    drop(output);
                }
            } else {
                let text = expected.link.as_ref().ok_or_else(|| {
                    io::Error::new(io::ErrorKind::InvalidData, "missing link text")
                })?;
                if unsafe {
                    libc::symlinkat(
                        c_path(text)?.as_ptr(),
                        directory.as_raw_fd(),
                        c_path(Path::new(name))?.as_ptr(),
                    )
                } < 0
                {
                    return Err(io::Error::last_os_error());
                }
                let identity = identity_at(&directory, name)
                    .and_then(|entry| entry.ok_or_else(|| changed("staged link disappeared")))
                    .inspect_err(|_| self.damaged = true)?;
                if identity.1 != Kind::Link {
                    self.damaged = true;
                    return Err(changed("staged link replaced"));
                }
                self.entries[index].set_identity(Some(identity.0));
                self.entries.directory_mut(parent).children += 1;
            }
            cancelled(cancel)?;
            expected.verify(source, false)?;
            if identity_at(&directory, name)?
                != self.entries[index].identity().map(|id| (id, expected.kind))
            {
                return Err(changed("staged output replaced"));
            }
            Ok(())
        })();
        if let Err(error) = result {
            if let Err(cleanup) = self.remove(index) {
                self.damaged = true;
                return Err(io::Error::new(
                    error.kind(),
                    CleanupError {
                        original: error,
                        cleanup,
                    },
                ));
            }
            self.discard_last();
            return Err(error);
        }
        #[cfg(test)]
        {
            let _span =
                crate::ux::filetree::profile::span(crate::ux::filetree::profile::Stage::Close);
            drop(input);
        }
        Ok(())
    }

    fn remove(&mut self, index: usize) -> io::Result<()> {
        let Some(identity) = self.entries[index].identity() else {
            return Ok(());
        };
        let parent = self.entries[index].parent().expect("private child");
        let file = self.directory(parent)?;
        match identity_at(&file, &self.entries[index].name)? {
            None => {}
            Some(observed) if observed == (identity, self.entries[index].kind) => {
                if unsafe {
                    libc::unlinkat(
                        file.as_raw_fd(),
                        c_path(Path::new(&self.entries[index].name))?.as_ptr(),
                        if self.entries[index].kind == Kind::Directory {
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
            Some(_) => return Err(changed("private entry was replaced; cleanup refused")),
        }
        self.entries[index].set_identity(None);
        self.entries.directory_mut(parent).children -= 1;
        Ok(())
    }

    fn verify(&mut self) -> io::Result<()> {
        if self.damaged {
            return Err(changed("private output could not be safely cleaned"));
        }
        if self.temporary.entry_identity()? != Some(self.private.identity) {
            return Err(changed("private root was replaced"));
        }
        for index in 1..self.entries.len() {
            let parent = self.entries[index].parent().expect("staged parent");
            let directory = self.directory(parent)?;
            let expected = self.entries[index]
                .identity()
                .map(|id| (id, self.entries[index].kind));
            if expected.is_none() || identity_at(&directory, &self.entries[index].name)? != expected
            {
                return Err(changed("staged entry changed before publication"));
            }
        }
        for index in 0..self.entries.len() {
            if self.entries[index].kind == Kind::Directory {
                let directory = self.directory(index)?;
                if children(&directory, self.entries.directory(index).children)?
                    != self.entries.directory(index).children
                {
                    return Err(changed("private directory membership changed"));
                }
            }
        }
        Ok(())
    }

    fn unregister(&self, registry: &mut Registry) {
        registry.directories.retain(|_, owner| {
            owner
                .upgrade()
                .is_some_and(|owner| !Arc::ptr_eq(&owner, &self.private))
        });
        if registry.directories.is_empty() {
            registry.directories.shrink_to_fit();
        }
        registry.roots.retain(|root| {
            root.upgrade()
                .is_some_and(|root| !Arc::ptr_eq(&root, &self.private))
        });
        if registry.roots.is_empty() {
            registry.roots.shrink_to_fit();
        }
    }

    /** Only the root rename commits output; callers may deliver successes after it returns. */
    pub fn publish(&mut self, target: &Destination) -> io::Result<()> {
        #[cfg(test)]
        let _span =
            crate::ux::filetree::profile::span(crate::ux::filetree::profile::Stage::PublishFs);
        self.verify()?;
        for index in (0..self.entries.len()).rev() {
            if let Some(permissions) = self.entries.permissions(index) {
                self.directory(index)?.set_permissions(permissions)?;
            }
        }
        let mut registry = REGISTRY.lock().unwrap_or_else(|error| error.into_inner());
        self.temporary.publish(target)?;
        self.unregister(&mut registry);
        Ok(())
    }

    /** Cleanup follows owned descriptors and refuses replacement entries and foreign children. */
    pub fn clean(&mut self) -> io::Result<()> {
        if !self.temporary.created {
            return Ok(());
        }
        let mut failure = None;
        for index in 0..self.entries.len() {
            if self.entries[index].kind == Kind::Directory
                && self.entries[index].identity().is_some()
            {
                let restored = self
                    .directory(index)
                    .and_then(|file| file.set_permissions(Permissions::from_mode(0o700)));
                if let Err(error) = restored {
                    failure.get_or_insert(error);
                }
            }
        }
        for index in (1..self.entries.len()).rev() {
            if let Err(error) = self.remove(index) {
                failure.get_or_insert(error);
            }
        }
        let mut registry = REGISTRY.lock().unwrap_or_else(|error| error.into_inner());
        if let Err(error) = self.temporary.clean() {
            failure.get_or_insert(error);
        }
        self.unregister(&mut registry);
        match failure {
            None => Ok(()),
            Some(error) => Err(io::Error::new(
                error.kind(),
                format!(
                    "{}; staging cleanup: {error}",
                    self.temporary.path.display()
                ),
            )),
        }
    }
}

impl Drop for Staging {
    fn drop(&mut self) {
        let _ = self.clean();
    }
}

fn children(file: &File, maximum: usize) -> io::Result<usize> {
    let fd = super::file_descriptor(|| unsafe { libc::dup(file.as_raw_fd()) })?;
    let directory = unsafe { libc::fdopendir(fd) };
    if directory.is_null() {
        let error = io::Error::last_os_error();
        unsafe {
            libc::close(fd);
        }
        return Err(error);
    }
    struct Reading(*mut libc::DIR);
    impl Drop for Reading {
        fn drop(&mut self) {
            unsafe {
                libc::closedir(self.0);
            }
        }
    }
    let _reading = Reading(directory);
    unsafe {
        libc::rewinddir(directory);
    }
    let mut count = 0;
    loop {
        #[cfg(target_os = "macos")]
        let errno = unsafe { libc::__error() };
        #[cfg(target_os = "linux")]
        let errno = unsafe { libc::__errno_location() };
        unsafe {
            *errno = 0;
        }
        let entry = unsafe { libc::readdir(directory) };
        if entry.is_null() {
            let code = unsafe { *errno };
            return if code == 0 {
                Ok(count)
            } else {
                Err(io::Error::from_raw_os_error(code))
            };
        }
        let name = unsafe { CStr::from_ptr((*entry).d_name.as_ptr()) }.to_bytes();
        if name != b"." && name != b".." {
            count += 1;
            if count > maximum {
                return Err(changed("private directory contains unowned entries"));
            }
        }
    }
}
