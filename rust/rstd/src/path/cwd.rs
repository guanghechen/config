use super::normalize;
use super::sep::SEP;
use std::ops::Deref;
use std::sync::OnceLock;
use std::sync::RwLock;
use std::sync::RwLockReadGuard;

static CWD: OnceLock<RwLock<String>> = OnceLock::new();

fn cwd_lock() -> &'static RwLock<String> {
    CWD.get_or_init(|| {
        let initial = std::env::current_dir()
            .map(|path| path.to_string_lossy().into_owned())
            .unwrap_or_else(|_| ".".to_string());
        RwLock::new(initial)
    })
}

pub fn set_cwd(value: impl AsRef<str>) {
    let mut buffer = value.as_ref().to_string();
    buffer.push('/');

    let lock = cwd_lock();
    let mut guard = lock.write().expect("CWD write lock poisoned");
    *guard = normalize(&buffer, true, SEP);
}

pub struct CwdGuard(RwLockReadGuard<'static, String>);

impl Deref for CwdGuard {
    type Target = str;

    fn deref(&self) -> &Self::Target {
        self.0.as_str()
    }
}

impl AsRef<str> for CwdGuard {
    fn as_ref(&self) -> &str {
        self.0.as_str()
    }
}

pub fn get_cwd() -> CwdGuard {
    let lock = cwd_lock();
    let guard = lock.read().expect("CWD read lock poisoned");
    CwdGuard(guard)
}
