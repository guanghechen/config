//! Cross-platform input-method domain.

#[cfg(target_os = "macos")]
mod osx;
#[cfg(any(target_os = "linux", target_os = "windows", test))]
mod win;
#[cfg(any(target_os = "linux", test))]
mod wsl;

#[cfg(target_os = "macos")]
pub use osx::Backend;
#[cfg(target_os = "windows")]
pub use win::Backend;
#[cfg(target_os = "linux")]
pub use wsl::{Backend, is_available};

#[derive(Debug, Eq, PartialEq)]
pub enum CaptureAndSelectError {
    Capture(String),
    Select { snapshot: String, error: String },
}
