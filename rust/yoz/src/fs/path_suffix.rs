use std::ffi::OsStr;
use std::io;
use std::path::{Component, Path, PathBuf};

fn invalid(message: &str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidInput, message)
}

#[cfg(unix)]
fn input_path(bytes: &[u8]) -> io::Result<&Path> {
    use std::os::unix::ffi::OsStrExt;
    Ok(Path::new(OsStr::from_bytes(bytes)))
}

#[cfg(not(unix))]
fn input_path(bytes: &[u8]) -> io::Result<&Path> {
    std::str::from_utf8(bytes)
        .map(Path::new)
        .map_err(|_| invalid("path is not UTF-8"))
}

#[cfg(unix)]
fn output_path(path: &Path) -> io::Result<Vec<u8>> {
    use std::os::unix::ffi::OsStrExt;
    Ok(path.as_os_str().as_bytes().to_vec())
}

#[cfg(not(unix))]
fn output_path(path: &Path) -> io::Result<Vec<u8>> {
    path.to_str()
        .map(|path| path.replace('\\', "/").into_bytes())
        .ok_or_else(|| invalid("path cannot be represented as UTF-8"))
}

#[cfg(any(target_os = "macos", windows))]
fn existing_directory(mut path: &Path) -> io::Result<&Path> {
    loop {
        match std::fs::metadata(path) {
            Ok(metadata) if metadata.is_dir() => return Ok(path),
            Ok(_) => return Err(invalid("containing path is not a directory")),
            Err(error) if error.kind() == io::ErrorKind::NotFound => {
                match std::fs::symlink_metadata(path) {
                    Ok(_) => return Err(error),
                    Err(error) if error.kind() != io::ErrorKind::NotFound => return Err(error),
                    Err(_) => {}
                }
                path = path.parent().ok_or(error)?;
            }
            Err(error) => return Err(error),
        }
    }
}

#[cfg(target_os = "macos")]
mod names {
    use super::*;
    use std::ffi::{CStr, CString, c_void};
    use std::os::unix::ffi::OsStrExt;

    #[link(name = "icucore")]
    unsafe extern "C" {
        fn unorm2_getNFDInstance(status: *mut i32) -> *const c_void;
        fn unorm2_normalize(
            normalizer: *const c_void,
            source: *const u16,
            length: i32,
            destination: *mut u16,
            capacity: i32,
            status: *mut i32,
        ) -> i32;
        fn u_strFoldCase(
            destination: *mut u16,
            capacity: i32,
            source: *const u16,
            length: i32,
            options: u32,
            status: *mut i32,
        ) -> i32;
    }

    fn transform(apply: impl Fn(*mut u16, i32, *mut i32) -> i32) -> io::Result<Vec<u16>> {
        let mut status = 0;
        let length = apply(std::ptr::null_mut(), 0, &mut status);
        /* ICU preflight reports U_BUFFER_OVERFLOW_ERROR with the required length. */
        if length < 0 || status > 0 && status != 15 {
            return Err(io::Error::other(format!(
                "ICU filename conversion failed: {status}"
            )));
        }
        let mut output = vec![0; length as usize];
        status = 0;
        let written = apply(output.as_mut_ptr(), length, &mut status);
        if status > 0 || written < 0 || written > length {
            return Err(io::Error::other(format!(
                "ICU filename conversion failed: {status}"
            )));
        }
        output.truncate(written as usize);
        Ok(output)
    }

    fn normalize(normalizer: *const c_void, text: &[u16]) -> io::Result<Vec<u16>> {
        let length = text
            .len()
            .try_into()
            .map_err(|_| invalid("name is too long"))?;
        transform(|output, capacity, status| unsafe {
            unorm2_normalize(normalizer, text.as_ptr(), length, output, capacity, status)
        })
    }

    fn fold(text: &[u16]) -> io::Result<Vec<u16>> {
        let length = text
            .len()
            .try_into()
            .map_err(|_| invalid("name is too long"))?;
        transform(|output, capacity, status| unsafe {
            u_strFoldCase(output, capacity, text.as_ptr(), length, 0, status)
        })
    }

    pub(super) fn equal(parent: &Path, left: &OsStr, right: &OsStr) -> io::Result<bool> {
        let canonical_equal = if left.as_bytes().is_ascii() && right.as_bytes().is_ascii() {
            if !left.as_bytes().eq_ignore_ascii_case(right.as_bytes()) {
                return Ok(false);
            }
            left == right
        } else {
            let (Some(left), Some(right)) = (left.to_str(), right.to_str()) else {
                return Ok(false);
            };
            let mut status = 0;
            let normalizer = unsafe { unorm2_getNFDInstance(&mut status) };
            if status > 0 || normalizer.is_null() {
                return Err(io::Error::other("ICU filename normalizer is unavailable"));
            }
            let a = normalize(normalizer, &left.encode_utf16().collect::<Vec<_>>())?;
            let b = normalize(normalizer, &right.encode_utf16().collect::<Vec<_>>())?;
            let canonical_equal = a == b;
            /* CoreFoundation comparison/folding misses some supplementary and Cyrillic case pairs.
             * Use the system ICU's canonical caseless form, preserving accents and ignorables. */
            if !canonical_equal
                && normalize(normalizer, &fold(&a)?)? != normalize(normalizer, &fold(&b)?)?
            {
                return Ok(false);
            }
            canonical_equal
        };
        let parent = existing_directory(parent)?;
        let parent = CString::new(parent.as_os_str().as_bytes())
            .map_err(|_| invalid("path contains NUL"))?;
        let sensitive = unsafe { libc::pathconf(parent.as_ptr(), libc::_PC_CASE_SENSITIVE) };
        if sensitive < 0 {
            return Err(io::Error::last_os_error());
        }
        let mut info = std::mem::MaybeUninit::<libc::statfs>::uninit();
        if unsafe { libc::statfs(parent.as_ptr(), info.as_mut_ptr()) } != 0 {
            return Err(io::Error::last_os_error());
        }
        let info = unsafe { info.assume_init() };
        let apfs = unsafe { CStr::from_ptr(info.f_fstypename.as_ptr()) }.to_bytes() == b"apfs";
        if apfs {
            /* APFS canonical equivalence also applies on case-sensitive volumes. */
            Ok(sensitive == 0 || canonical_equal)
        } else if left.as_bytes().eq_ignore_ascii_case(right.as_bytes()) {
            Ok(sensitive == 0)
        } else {
            /* An unknown Unicode rule must not silently permit a potentially colliding name. */
            Err(io::Error::new(
                io::ErrorKind::Unsupported,
                "Unicode filename comparison requires APFS",
            ))
        }
    }
}

#[cfg(windows)]
mod names {
    use super::*;
    use std::ffi::c_void;
    use std::os::windows::ffi::OsStrExt;
    use std::os::windows::fs::OpenOptionsExt;
    use std::os::windows::io::AsRawHandle;

    unsafe extern "system" {
        fn CompareStringOrdinal(
            left: *const u16,
            left_length: i32,
            right: *const u16,
            right_length: i32,
            ignore_case: i32,
        ) -> i32;
        fn GetFileInformationByHandleEx(
            handle: *mut c_void,
            class: i32,
            info: *mut c_void,
            size: u32,
        ) -> i32;
    }

    pub(super) fn ordinal(left: &OsStr, right: &OsStr, ignore_case: bool) -> io::Result<bool> {
        let left: Vec<_> = left.encode_wide().collect();
        let right: Vec<_> = right.encode_wide().collect();
        let result = unsafe {
            CompareStringOrdinal(
                left.as_ptr(),
                left.len()
                    .try_into()
                    .map_err(|_| invalid("name is too long"))?,
                right.as_ptr(),
                right
                    .len()
                    .try_into()
                    .map_err(|_| invalid("name is too long"))?,
                i32::from(ignore_case),
            )
        };
        if result == 0 {
            Err(io::Error::last_os_error())
        } else {
            Ok(result == 2)
        }
    }

    pub(super) fn equal(parent: &Path, left: &OsStr, right: &OsStr) -> io::Result<bool> {
        if !ordinal(left, right, true)? {
            return Ok(false);
        }
        let parent = existing_directory(parent)?;
        let directory = std::fs::OpenOptions::new()
            .access_mode(0x80)
            .custom_flags(0x02000000)
            .open(parent)?;
        let mut flags = 0u32;
        let ok = unsafe {
            GetFileInformationByHandleEx(
                directory.as_raw_handle(),
                23,
                (&mut flags as *mut u32).cast(),
                std::mem::size_of_val(&flags) as u32,
            )
        };
        if ok == 0 {
            let error = io::Error::last_os_error();
            if !matches!(error.raw_os_error(), Some(50 | 87)) {
                return Err(error);
            }
        }
        ordinal(left, right, flags & 1 == 0)
    }
}

#[cfg(not(any(target_os = "macos", windows)))]
mod names {
    use super::*;

    pub(super) fn equal(_: &Path, _: &OsStr, _: &OsStr) -> io::Result<bool> {
        Ok(false)
    }
}

fn suffix<'a>(base: &Path, path: &'a Path) -> io::Result<Option<&'a Path>> {
    if !base.is_absolute() || !path.is_absolute() {
        return Err(invalid("paths must be absolute"));
    }
    if base
        .components()
        .chain(path.components())
        .any(|part| part == Component::ParentDir)
    {
        return Err(invalid("paths must not contain parent components"));
    }
    let mut parts = path.components();
    let mut parent = PathBuf::new();
    let mut pending_error = None;
    for expected in base.components() {
        let Some(actual) = parts.next() else {
            return Ok(None);
        };
        if expected != actual {
            let matched = match (expected, actual) {
                (Component::Normal(left), Component::Normal(right)) => {
                    names::equal(&parent, left, right)
                }
                #[cfg(windows)]
                (Component::Prefix(left), Component::Prefix(right)) => {
                    names::ordinal(left.as_os_str(), right.as_os_str(), true)
                }
                _ => Ok(false),
            };
            match matched {
                Ok(false) => return Ok(None),
                Ok(true) => {}
                Err(error) => {
                    /* An uncertain ancestor must not implicate a clearly unrelated child. */
                    pending_error.get_or_insert(error);
                }
            }
        }
        parent.push(expected);
    }
    if let Some(error) = pending_error {
        return Err(error);
    }
    Ok(Some(parts.as_path()))
}

fn resolve_directory(path: &Path, links: usize) -> io::Result<PathBuf> {
    if links == 0 {
        return Err(invalid("too many parent symlinks"));
    }
    let mut ancestor = path;
    loop {
        match std::fs::symlink_metadata(ancestor) {
            Ok(metadata) => {
                let tail = path
                    .strip_prefix(ancestor)
                    .map_err(|_| invalid("parent prefix changed"))?;
                if tail.components().any(|part| part == Component::ParentDir) {
                    return Err(invalid(
                        "cannot resolve parent components through missing directories",
                    ));
                }
                let mut resolved = if metadata.file_type().is_symlink() {
                    let target = std::fs::read_link(ancestor)?;
                    let target = if target.is_absolute() {
                        target
                    } else {
                        ancestor
                            .parent()
                            .ok_or_else(|| invalid("symlink has no parent"))?
                            .join(target)
                    };
                    resolve_directory(&target, links - 1)?
                } else if metadata.is_dir() {
                    std::fs::canonicalize(ancestor)?
                } else {
                    return Err(invalid("containing path is not a directory"));
                };
                resolved.push(tail);
                return Ok(resolved);
            }
            Err(error) if error.kind() == io::ErrorKind::NotFound => {
                ancestor = ancestor.parent().ok_or(error)?;
            }
            Err(error) => return Err(error),
        }
    }
}

/**
 * Resolve parent aliases, including dangling links whose target namespace is still known.
 * Missing components and the final entry are preserved; the final entry is never dereferenced.
 * Hard links and final symlinks therefore retain distinct names.
 */
pub fn entry_path(path: &[u8]) -> Result<Vec<u8>, String> {
    let resolve = || {
        if path.contains(&0) {
            return Err(invalid("path contains NUL"));
        }
        let path = input_path(path)?;
        if !path.is_absolute() || path.components().any(|part| part == Component::ParentDir) {
            return Err(invalid("path must be absolute without parent components"));
        }
        let parent = path.parent().unwrap_or(path);
        let mut resolved = resolve_directory(parent, 40)?;
        resolved.push(
            path.strip_prefix(parent)
                .map_err(|_| invalid("parent prefix changed"))?,
        );
        #[cfg(unix)]
        return output_path(&resolved);
        #[cfg(not(unix))]
        return resolved
            .to_str()
            .map(|path| path.as_bytes().to_vec())
            .ok_or_else(|| invalid("path cannot be represented as UTF-8"));
    };
    resolve().map_err(|error| format!("[entry_path] {error}"))
}

/**
 * Return the suffix of an editor path within an entry namespace, including missing entries.
 * Components use the containing directory's filename rules. APFS includes canonical Unicode
 * equivalence; Windows respects per-directory case sensitivity. Other Unix names preserve bytes.
 * This compares names rather than file identity: hard links remain distinct, and parent symlink
 * aliases must already have been resolved through entry_path.
 */
pub fn path_suffix(base: &[u8], path: &[u8]) -> Result<Option<Vec<u8>>, String> {
    let compare = || {
        if base.contains(&0) || path.contains(&0) {
            return Err(invalid("path contains NUL"));
        }
        suffix(input_path(base)?, input_path(path)?)?
            .map(output_path)
            .transpose()
    };
    compare().map_err(|error| format!("[path_suffix] {error}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::time::{SystemTime, UNIX_EPOCH};

    struct TempDir(PathBuf);

    impl TempDir {
        fn new() -> Self {
            static NEXT: AtomicUsize = AtomicUsize::new(0);
            let parent = std::env::var_os("YOZ_PATH_TEST_VOLUME")
                .map(PathBuf::from)
                .unwrap_or_else(std::env::temp_dir);
            let path = parent.join(format!(
                "yoz_path_suffix_{}_{}_{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed),
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            fs::create_dir(&path).unwrap();
            Self(path.canonicalize().unwrap())
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            fs::remove_dir_all(&self.0).unwrap();
        }
    }

    fn compare(base: &Path, path: &Path) -> Result<Option<Vec<u8>>, String> {
        path_suffix(&output_path(base).unwrap(), &output_path(path).unwrap())
    }

    #[test]
    fn t_component_boundaries_and_missing_descendants() {
        let root = TempDir::new();
        let base = root.0.join("missing");
        assert_eq!(compare(&base, &base), Ok(Some(Vec::new())));
        assert_eq!(
            compare(&base, &base.join("cafe\u{301}/notes.txt")),
            Ok(Some("cafe\u{301}/notes.txt".as_bytes().to_vec()))
        );
        assert_eq!(compare(&base, &root.0.join("missing-other")), Ok(None));
        assert_eq!(compare(&base, &root.0), Ok(None));
        assert_eq!(
            compare(&base, &base.join("..")),
            Err("[path_suffix] paths must not contain parent components".into())
        );
        assert!(compare(Path::new("relative"), &base).is_err());
        assert!(compare(&base, Path::new("relative")).is_err());
        assert!(path_suffix(b"/nul\0", b"/nul").is_err());
    }

    #[test]
    fn t_missing_names_match_actual_filesystem_case_and_unicode_rules() {
        let root = TempDir::new();
        for (index, (left, right)) in [
            ("TARGET.txt", "target.txt"),
            ("caf\u{e9}", "cafe\u{301}"),
            ("Stra\u{df}e", "STRASSE"),
            ("\u{3c2}", "\u{3c3}"),
            ("\u{130}", "i\u{307}"),
            ("\u{130}", "i"),
            ("\u{df}", "\u{1e9e}"),
            ("\u{fb00}", "ff"),
            ("\u{f900}", "\u{8c48}"),
            ("\u{c5}", "A\u{30a}"),
            ("a\u{200c}b", "ab"),
            ("a\u{200d}b", "ab"),
            ("a\u{34f}b", "ab"),
            ("a\u{fe0f}b", "ab"),
            ("\u{f8}", "o"),
            ("\u{e9}", "e"),
            ("\u{10400}", "\u{10428}"),
            ("\u{104b0}", "\u{104d8}"),
            ("\u{10570}", "\u{10597}"),
            ("\u{1e900}", "\u{1e922}"),
            ("\u{1c80}", "\u{432}"),
            ("\u{1c88}", "\u{a64b}"),
            ("\u{1d15e}", "\u{1d157}\u{1d165}"),
        ]
        .iter()
        .enumerate()
        {
            let directory = root.0.join(index.to_string());
            fs::create_dir(&directory).unwrap();
            let left = directory.join(left);
            let right = directory.join(right);
            let missing = compare(&left, &right).unwrap();
            fs::write(&left, "sentinel").unwrap();
            let same = match fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&right)
            {
                Ok(_) => false,
                Err(error) if error.kind() == io::ErrorKind::AlreadyExists => true,
                Err(error) => panic!("create comparison entry: {error}"),
            };
            let expected = same.then(Vec::new);
            assert_eq!(missing, expected, "missing: {left:?} / {right:?}");
            assert_eq!(
                compare(&left, &right).unwrap(),
                expected,
                "existing: {left:?} / {right:?}"
            );
            assert_eq!(
                compare(&right, &left).unwrap(),
                expected,
                "reverse: {left:?} / {right:?}"
            );
        }
    }

    #[test]
    fn t_unicode_directory_alias_preserves_candidate_suffix_bytes() {
        let root = TempDir::new();
        let base = root.0.join("caf\u{e9}");
        let alias = root.0.join("cafe\u{301}");
        fs::create_dir(&base).unwrap();
        let expected = alias
            .exists()
            .then(|| "nested/cafe\u{301}.txt".as_bytes().to_vec());
        assert_eq!(
            compare(&base, &alias.join("nested/cafe\u{301}.txt")),
            Ok(expected)
        );
    }

    #[test]
    fn t_unicode_case_mapping_pairs_follow_actual_directory_rules() {
        let root = TempDir::new();
        for character in (0..=0x10ffff).filter_map(char::from_u32) {
            let original = character.to_string();
            for variant in [
                character.to_lowercase().to_string(),
                character.to_uppercase().to_string(),
            ] {
                if original == variant {
                    continue;
                }
                let left = root.0.join(format!("name-{original}"));
                let right = root.0.join(format!("name-{variant}"));
                let missing = compare(&left, &right).unwrap();
                fs::write(&left, "sentinel").unwrap();
                let same = match fs::OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .open(&right)
                {
                    Ok(_) => false,
                    Err(error) if error.kind() == io::ErrorKind::AlreadyExists => true,
                    Err(error) => panic!("create comparison entry: {error}"),
                };
                assert_eq!(
                    missing,
                    same.then(Vec::new),
                    "case pair {original:?} / {variant:?}"
                );
                fs::remove_file(left).unwrap();
                if !same {
                    fs::remove_file(right).unwrap();
                }
            }
        }
    }

    #[test]
    fn t_hard_links_are_distinct_entry_names() {
        let root = TempDir::new();
        let source = root.0.join("source");
        let alias = root.0.join("alias");
        fs::write(&source, "sentinel").unwrap();
        fs::hard_link(&source, &alias).unwrap();
        assert_eq!(compare(&source, &alias), Ok(None));
        assert_ne!(
            entry_path(&output_path(&source).unwrap()),
            entry_path(&output_path(&alias).unwrap())
        );
    }

    #[cfg(unix)]
    #[test]
    fn t_entry_path_resolves_existing_parent_aliases_and_preserves_missing_suffixes() {
        let root = TempDir::new();
        let real = root.0.join("real");
        let alias = root.0.join("alias");
        fs::create_dir(&real).unwrap();
        std::os::unix::fs::symlink(&real, &alias).unwrap();
        let buffer = alias.join("new/nested/notes.txt");
        assert_eq!(
            entry_path(&output_path(&buffer).unwrap()),
            Ok(output_path(&real.join("new/nested/notes.txt")).unwrap())
        );
        assert!(!real.join("new").exists());
        assert_eq!(
            entry_path(&output_path(&alias).unwrap()),
            Ok(output_path(&alias).unwrap()),
            "do not resolve the final symlink"
        );
    }

    #[cfg(unix)]
    #[test]
    fn t_entry_path_resolves_dangling_parents_and_rejects_symlink_loops() {
        let root = TempDir::new();
        let alias = root.0.join("dangling");
        std::os::unix::fs::symlink(root.0.join("future"), &alias).unwrap();
        assert_eq!(
            entry_path(&output_path(&alias.join("notes.txt")).unwrap()),
            Ok(output_path(&root.0.join("future/notes.txt")).unwrap())
        );
        std::os::unix::fs::symlink("loop-b", root.0.join("loop-a")).unwrap();
        std::os::unix::fs::symlink("loop-a", root.0.join("loop-b")).unwrap();
        assert!(entry_path(&output_path(&root.0.join("loop-a/notes.txt")).unwrap()).is_err());
        assert!(entry_path(b"relative").is_err());
        assert!(entry_path(b"/nul\0").is_err());
        assert!(entry_path(&output_path(&root.0.join("..")).unwrap()).is_err());
    }

    #[cfg(unix)]
    #[test]
    fn t_final_symlinks_and_non_utf8_names_preserve_entry_namespace() {
        use std::os::unix::ffi::OsStrExt;
        let root = TempDir::new();
        let source = root.0.join("source");
        let alias = root.0.join("alias");
        fs::write(&source, "sentinel").unwrap();
        std::os::unix::fs::symlink(&source, &alias).unwrap();
        assert_eq!(compare(&source, &alias), Ok(None));
        let base = root.0.join(OsStr::from_bytes(b"literal\\\xff"));
        assert_eq!(
            compare(&base, &base.join(OsStr::from_bytes(b"child\\\xfe"))),
            Ok(Some(b"child\\\xfe".to_vec()))
        );
        assert_eq!(compare(&base, &root.0.join("literal/child")), Ok(None));
    }

    #[cfg(any(target_os = "macos", windows))]
    #[test]
    fn t_query_failure_is_reported_only_for_possible_namespace_matches() {
        let root = TempDir::new();
        let blocker = root.0.join("file");
        fs::write(&blocker, "sentinel").unwrap();
        assert!(compare(&blocker.join("CHILD"), &blocker.join("child")).is_err());
        assert_eq!(
            compare(&blocker.join("CHILD/one"), &blocker.join("child/two")),
            Ok(None)
        );
    }
}
