use rstd::search::{ISearchInFilesOptions, search_in_files};
use std::collections::HashSet;

fn fixtures_dir() -> String {
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not defined");
    let path = std::path::Path::new(&manifest_dir).join("tests/fixtures");
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
        .map(|path| {
            std::path::Path::new(path)
                .file_name()
                .unwrap()
                .to_string_lossy()
                .to_string()
        })
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
        .map(|path| {
            std::path::Path::new(path)
                .file_name()
                .unwrap()
                .to_string_lossy()
                .to_string()
        })
        .collect();

    assert!(
        !filenames.contains("a.txt"),
        "a.txt should not be present when searching with \\r\\n"
    );
    assert!(filenames.contains("b.txt"), "b.txt should be present");
}

#[test]
fn test_search_in_files_respects_max_matches_limit() {
    let cwd = fixtures_dir();

    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore: true,
        flag_regex: false,
        max_filesize: None,
        max_matches: Some(5),
        search_pattern: "Hello".to_string(),
        search_paths: ".".to_string(),
        include_patterns: "*.txt".to_string(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let result = search_in_files(&options).expect("expected successful search");
    assert_eq!(result.items.len(), 1, "only a.txt should be included");

    let file_match = result
        .items
        .get("a.txt")
        .expect("a.txt should be present in results");

    assert_eq!(
        file_match.matches.len(),
        5,
        "expected exactly 5 matches to be recorded"
    );

    let last_block = file_match
        .matches
        .last()
        .expect("matches collection should not be empty");
    assert!(
        !last_block.matches.is_empty(),
        "last block should retain the final match"
    );
    assert_eq!(
        last_block.lnum, 5,
        "the final recorded match should correspond to line 5"
    );
}
