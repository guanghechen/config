use std::sync::OnceLock;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Platform {
    Win,
    Wsl,
    Nix,
    Osx,
}

pub fn current_platform() -> Platform {
    *PLATFORM.get_or_init(detect_platform)
}

static PLATFORM: OnceLock<Platform> = OnceLock::new();

fn detect_platform() -> Platform {
    if cfg!(target_os = "macos") {
        return Platform::Osx;
    }
    if cfg!(target_os = "windows") {
        return Platform::Win;
    }
    if cfg!(target_os = "linux") && is_wsl() {
        return Platform::Wsl;
    }
    Platform::Nix
}

fn is_wsl() -> bool {
    std::env::var_os("WSL_DISTRO_NAME").is_some()
        || std::env::var_os("WSL_INTEROP").is_some()
        || file_contains_ci("/proc/sys/kernel/osrelease", &["microsoft", "wsl"])
        || file_contains_ci("/proc/version", &["microsoft", "wsl"])
}

fn file_contains_ci(path: &str, needles: &[&str]) -> bool {
    let Ok(content) = std::fs::read_to_string(path) else {
        return false;
    };
    let content = content.to_ascii_lowercase();
    needles.iter().any(|needle| content.contains(needle))
}

#[cfg(test)]
mod tests {
    use super::Platform;

    #[test]
    fn platform_is_copyable() {
        let platform = Platform::Osx;
        assert_eq!(platform, Platform::Osx);
    }
}
