use rstd::search::{
    search_in_files,
    ISearchInFilesOptions,
};
use std::collections::HashSet;

fn fixtures_dir() -> String {
    let manifest_dir =
        std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not defined");
    let path = std::path::Path::new(&manifest_dir)
        .join("../nvim_tools/tests/fixtures");
    path.to_string_lossy().to_string()
}

#[test]
fn test_search_in_files_lf_pattern_matches_only_lf_files() {
    let cwd = fixtures_dir();

    let options = ISearchInFilesOptions {
        cwd: Some(cwd.clone()),
        flag_case_sensitive: true,
        flag_gitignore: true,
        flag_regex: true,
        max_filesize: Some("1M".to_string()),
        max_matches: Some(300),
        search_pattern: r#"Hello, (world|世界)!\n"#.to_string(),
        search_paths: ".".to_string(),
        include_patterns: "*.txt".to_string(),
        exclude_patterns: "c.txt".to_string(),
        specified_filepath: None,
    };

    let result = search_in_files(&options).expect("expected successful search");
    assert!(!result.items.is_empty(), "expect at least one matched file");

    let filenames: HashSet<_> = result
        .items
        .keys()
        .map(|path| std::path::Path::new(path).file_name().unwrap().to_string_lossy().to_string())
        .collect();

    assert!(filenames.contains("a.txt"), "a.txt should be present");
    assert!(
        !filenames.contains("b.txt"),
        "b.txt should not be present when searching with \\n"
    );
    assert!(
        !filenames.contains("c.txt"),
        "c.txt should be excluded by exclude_patterns"
    );
}

#[test]
fn test_search_in_files_crlf_pattern_matches_crlf_files() {
    let cwd = fixtures_dir();

    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore: true,
        flag_regex: true,
        max_filesize: Some("1M".to_string()),
        max_matches: Some(300),
        search_pattern: r#"Hello, (world|世界)!\r\n"#.to_string(),
        search_paths: ".".to_string(),
        include_patterns: "*.txt".to_string(),
        exclude_patterns: "c.txt".to_string(),
        specified_filepath: None,
    };

    let result = search_in_files(&options).expect("expected successful search");
    assert!(!result.items.is_empty(), "expect at least one matched file");

    let filenames: HashSet<_> = result
        .items
        .keys()
        .map(|path| std::path::Path::new(path).file_name().unwrap().to_string_lossy().to_string())
        .collect();

    assert!(
        !filenames.contains("a.txt"),
        "a.txt should not be present when searching with \\r\\n"
    );
    assert!(filenames.contains("b.txt"), "b.txt should be present");
}
