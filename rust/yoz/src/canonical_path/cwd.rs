use super::SEP;
use super::normalize;
use std::ops::Deref;
use std::sync::OnceLock;
use std::sync::RwLock;
use std::sync::RwLockReadGuard;

struct CwdState {
    filepath: String,
    without_trailing_len: usize,
}

impl CwdState {
    fn new(value: &str) -> Self {
        let mut buffer = value.to_string();
        buffer.push('/');

        let filepath = normalize(&buffer, true);
        let without_trailing_len = filepath
            .strip_suffix(SEP)
            .filter(|prefix| !prefix.is_empty())
            .map_or(filepath.len(), str::len);

        Self {
            filepath,
            without_trailing_len,
        }
    }
}

static CWD: OnceLock<RwLock<CwdState>> = OnceLock::new();

fn cwd_lock() -> &'static RwLock<CwdState> {
    CWD.get_or_init(|| {
        let initial = std::env::current_dir()
            .map(|path| path.to_string_lossy().into_owned())
            .unwrap_or_else(|_| ".".to_string());
        RwLock::new(CwdState::new(&initial))
    })
}

pub fn set_cwd(value: impl AsRef<str>) {
    let state = CwdState::new(value.as_ref());
    let lock = cwd_lock();
    let mut guard = lock.write().expect("CWD write lock poisoned");
    *guard = state;
}

pub struct CwdGuard(RwLockReadGuard<'static, CwdState>);

impl Deref for CwdGuard {
    type Target = str;

    fn deref(&self) -> &Self::Target {
        self.0.filepath.as_str()
    }
}

impl AsRef<str> for CwdGuard {
    fn as_ref(&self) -> &str {
        self.0.filepath.as_str()
    }
}

pub struct CwdWithoutTrailingGuard(RwLockReadGuard<'static, CwdState>);

impl Deref for CwdWithoutTrailingGuard {
    type Target = str;

    fn deref(&self) -> &Self::Target {
        &self.0.filepath[..self.0.without_trailing_len]
    }
}

impl AsRef<str> for CwdWithoutTrailingGuard {
    fn as_ref(&self) -> &str {
        self
    }
}

pub fn get_cwd() -> CwdGuard {
    let lock = cwd_lock();
    let state = lock.read().expect("CWD read lock poisoned");
    CwdGuard(state)
}

pub fn get_cwd_without_trailing() -> CwdWithoutTrailingGuard {
    let lock = cwd_lock();
    let state = lock.read().expect("CWD read lock poisoned");
    CwdWithoutTrailingGuard(state)
}
