use super::normalize::normalize_splits;
use super::resolve::resolve;
use super::sep::SEP;
use super::split::split;
use std::path::Path;

pub fn locate_nearest(start_dirpath: &str, filenames: &[String]) -> Option<String> {
    if filenames.is_empty() {
        return None;
    }

    let pieces = split(start_dirpath, false);
    if pieces.is_empty() {
        return None;
    }

    for end in (0..pieces.len()).rev() {
        let base = normalize_splits(&pieces[..=end], SEP);
        if !Path::new(&base).is_dir() {
            continue;
        }

        for filename in filenames {
            if filename.is_empty() {
                continue;
            }

            let candidate = resolve(&base, filename, false, SEP);
            if Path::new(&candidate).exists() {
                return Some(candidate);
            }
        }
    }

    None
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/path/locate_nearest_test.rs"
    ));
}
