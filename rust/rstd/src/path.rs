use std::borrow::Cow;
use std::env;
use std::path::{Component, Path, PathBuf};

#[cfg(windows)]
pub const SEP: &str = "\\";

#[cfg(not(windows))]
pub const SEP: &str = "/";

fn trim_suffix_separators(filepath: &str) -> &str {
    let mut end = filepath.len();
    let bytes = filepath.as_bytes();
    while end > 0 {
        let byte = bytes[end - 1];
        if byte == b'/' || byte == b'\\' {
            end -= 1;
        } else {
            break;
        }
    }
    &filepath[..end]
}

pub fn is_absolute(filepath: &str) -> bool {
    if filepath.is_empty() {
        return false;
    }

    #[cfg(windows)]
    {
        if filepath.len() < 2 {
            return false;
        }

        let bytes = filepath.as_bytes();
        bytes[1] == b':' && bytes[0].is_ascii_alphabetic()
    }

    #[cfg(not(windows))]
    {
        if filepath.is_empty() {
            return false;
        }

        let bytes = filepath.as_bytes();
        bytes[0] == b'/'
    }
}

pub fn is_dirpath(filepath: &str) -> bool {
    if filepath.is_empty() {
        return false;
    }
    let bytes = filepath.as_bytes();
    let last_byte = bytes[bytes.len() - 1];
    last_byte == b'/' || last_byte == b'\\'
}

pub fn is_exist(filepath: &str) -> bool {
    if filepath.is_empty() {
        return false;
    }
    Path::new(filepath).exists()
}

pub fn is_exist_dirpath(filepath: &str) -> bool {
    if filepath.is_empty() {
        return false;
    }
    match Path::new(filepath).metadata() {
        Ok(metadata) => metadata.is_dir(),
        Err(_) => false,
    }
}

pub fn is_exist_filepath(filepath: &str) -> bool {
    if filepath.is_empty() {
        return false;
    }
    match Path::new(filepath).metadata() {
        Ok(metadata) => metadata.is_file(),
        Err(_) => false,
    }
}

fn resolve_from_cwd(path: &Path) -> PathBuf {
    match env::current_dir() {
        Ok(cwd) => cwd.join(path),
        Err(_) => PathBuf::from(path),
    }
}

pub fn is_descendant(from: &str, to: &str) -> bool {
    if from.is_empty() {
        return true;
    }

    let from_absolute = is_absolute(from);
    let to_absolute = is_absolute(to);

    if from_absolute && !to_absolute {
        return true;
    }

    let mut owned_from: Option<PathBuf> = None;
    let mut owned_to: Option<PathBuf> = None;

    if to_absolute && !from_absolute {
        owned_from = Some(resolve_from_cwd(Path::new(from)));
    }

    if !to_absolute && from_absolute {
        owned_to = Some(resolve_from_cwd(Path::new(to)));
    }

    let from_path: Cow<'_, Path> = match owned_from {
        Some(ref buf) => Cow::Borrowed(buf.as_path()),
        None => Cow::Borrowed(Path::new(from)),
    };

    let to_path: Cow<'_, Path> = match owned_to {
        Some(ref buf) => Cow::Borrowed(buf.as_path()),
        None => Cow::Borrowed(Path::new(to)),
    };

    let from_components: Vec<Component<'_>> = from_path.as_ref().components().collect();
    let to_components: Vec<Component<'_>> = to_path.as_ref().components().collect();

    if to_components.len() < from_components.len() {
        return false;
    }

    from_components
        .iter()
        .zip(to_components.iter())
        .all(|(lhs, rhs)| lhs == rhs)
}

pub fn dirname(filepath: &str) -> String {
    if filepath.is_empty() {
        return String::new();
    }

    let trimmed = trim_suffix_separators(filepath);
    if trimmed.is_empty() {
        return filepath.to_string();
    }

    let bytes = trimmed.as_bytes();
    for index in (0..bytes.len()).rev() {
        let byte = bytes[index];
        if byte == b'/' || byte == b'\\' {
            if index == 0 && (byte == b'/' || byte == b'\\') {
                return filepath[..=index].to_string();
            }
            return filepath[..index].to_string();
        }
    }

    trimmed.to_string()
}

pub fn basename(filepath: &str) -> String {
    if filepath.is_empty() {
        return String::new();
    }

    let bytes = filepath.as_bytes();
    let n = bytes.len();
    for index in (0..n).rev() {
        let byte = bytes[index];
        if byte == b'/' || byte == b'\\' {
            if index + 1 == n {
                return String::new();
            }
            return filepath[index + 1..].to_string();
        }
    }
    filepath.to_string()
}

pub fn extname(filepath: &str) -> String {
    if filepath.is_empty() {
        return String::new();
    }

    let bytes = filepath.as_bytes();
    let n = bytes.len();
    for index in (0..n).rev() {
        let byte = bytes[index];
        if byte == b'.' {
            if index + 1 == n {
                return String::new();
            }
            return filepath[index..].to_string();
        }
        if byte == b'/' || byte == b'\\' {
            return String::new();
        }
    }
    String::new()
}
