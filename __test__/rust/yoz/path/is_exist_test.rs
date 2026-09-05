use super::super::SEP;
use super::super::join;
use super::*;
use std::fs;

struct PreparedPaths {
    base: String,
    dir: String,
    file: String,
    missing: String,
}

fn prepare_paths() -> PreparedPaths {
    let base_dir = std::env::temp_dir().join(format!(
        "yoz_path_is_exist_{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0)
    ));
    let base = base_dir.to_string_lossy().to_string();
    let dir = join(&base, "dir", false, SEP);
    let file = join(&base, "file.txt", false, SEP);
    let missing = join(&base, "missing.txt", false, SEP);

    fs::create_dir_all(&dir).expect("create dir");
    fs::write(&file, b"data").expect("write file");

    PreparedPaths {
        base,
        dir,
        file,
        missing,
    }
}

#[test]
fn t_is_exist_directory() {
    let paths = prepare_paths();
    assert!(is_exist(&paths.dir));
    assert!(is_exist_directory(&paths.dir));
    assert!(!is_exist_file(&paths.dir));

    assert!(is_exist(&paths.file));
    assert!(!is_exist_directory(&paths.file));
    assert!(is_exist_file(&paths.file));

    assert!(!is_exist(&paths.missing));
    assert!(!is_exist_directory(&paths.missing));
    assert!(!is_exist_file(&paths.missing));

    assert!(!is_exist(""));
    assert!(!is_exist_directory(""));
    assert!(!is_exist_file(""));

    fs::remove_dir_all(&paths.base).ok();
}
