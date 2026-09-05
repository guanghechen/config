use super::super::SEP;
use super::locate_nearest;
use std::fs;
use std::path::Path;

fn unique_temp_dir(name: &str) -> std::path::PathBuf {
    std::env::temp_dir().join(format!(
        "yoz_locate_nearest_{name}_{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0)
    ))
}

#[test]
fn t_locate_nearest_prefers_closest_match() {
    let base_dir = unique_temp_dir("closest");
    let deep_dir = base_dir.join(format!("foo{SEP}bar{SEP}baz"));
    fs::create_dir_all(&deep_dir).expect("create nested dirs");

    let target_path = base_dir.join("foo").join("target.txt");
    fs::write(&target_path, b"nearest").expect("write target");

    let start_path = deep_dir.join("dummy.lua");
    let result = locate_nearest(
        &start_path.to_string_lossy(),
        &[String::from("target.txt"), String::from("missing.txt")],
    );

    assert!(
        result
            .as_ref()
            .is_some_and(|path| Path::new(path) == target_path),
        "expected to find {:?}, got {:?}",
        target_path,
        result
    );

    fs::remove_dir_all(&base_dir).ok();
}

#[test]
fn t_locate_nearest_handles_directory_targets() {
    let base_dir = unique_temp_dir("directory");
    let nested_dir = base_dir.join(format!("foo{SEP}bar"));
    let lib_dir = base_dir.join(format!("foo{SEP}node_modules{SEP}typescript{SEP}lib"));
    fs::create_dir_all(&nested_dir).expect("create nested");
    fs::create_dir_all(&lib_dir).expect("create lib dir");

    let result = locate_nearest(
        &nested_dir.to_string_lossy(),
        &[String::from("node_modules/typescript/lib")],
    );

    assert!(
        result
            .as_ref()
            .is_some_and(|path| Path::new(path) == lib_dir),
        "expected to find {:?}, got {:?}",
        lib_dir,
        result
    );

    fs::remove_dir_all(&base_dir).ok();
}

#[test]
fn t_locate_nearest_returns_none_when_missing() {
    let base_dir = unique_temp_dir("missing");
    let nested_dir = base_dir.join(format!("foo{SEP}bar"));
    fs::create_dir_all(&nested_dir).expect("create nested");

    let result = locate_nearest(
        &nested_dir.to_string_lossy(),
        &[String::from("missing.json")],
    );

    assert!(result.is_none());

    fs::remove_dir_all(&base_dir).ok();
}
