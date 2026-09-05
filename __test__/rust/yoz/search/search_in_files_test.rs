use super::*;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

fn fixtures_dir() -> String {
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not defined");
    let path = std::path::Path::new(&manifest_dir).join("../../__test__/fixtures/yoz");
    path.to_string_lossy().to_string()
}

struct TempWorkspace {
    path: PathBuf,
}

impl TempWorkspace {
    fn new(prefix: &str) -> Self {
        let path = std::env::temp_dir().join(format!("yoz-search-{}-{}", prefix, Uuid::new_v4()));
        fs::create_dir_all(&path).expect("failed to create temp workspace");
        Self { path }
    }

    fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for TempWorkspace {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.path);
    }
}

fn setup_gitignore_workspace() -> TempWorkspace {
    let workspace = TempWorkspace::new("gitignore");
    let base = workspace.path();

    fs::write(base.join(".gitignore"), "ignored.txt\nignored_dir/\n")
        .expect("failed to write .gitignore fixture");
    fs::write(base.join(".ignore"), "*.log\n").expect("failed to write .ignore fixture");
    fs::write(base.join("tracked.txt"), "needle in tracked file\n")
        .expect("failed to write tracked fixture");
    fs::write(base.join("ignored.txt"), "needle hidden by gitignore\n")
        .expect("failed to write ignored fixture");
    fs::write(base.join("ignored.log"), "needle hidden by ignore\n")
        .expect("failed to write .ignore fixture");
    fs::create_dir_all(base.join("ignored_dir")).expect("failed to create ignored_dir");
    fs::write(
        base.join("ignored_dir/nested.txt"),
        "needle hidden in ignored directory\n",
    )
    .expect("failed to write ignored dir fixture");

    workspace
}

fn setup_nested_gitignore_workspace() -> (TempWorkspace, PathBuf) {
    let workspace = TempWorkspace::new("gitignore-nested");
    let base = workspace.path();
    let root = base.join("nested");

    fs::create_dir_all(&root).expect("failed to create nested workspace root");
    fs::write(base.join(".gitignore"), "ignored.txt\nignored_dir/\n")
        .expect("failed to write parent .gitignore");
    fs::write(root.join("tracked.txt"), "needle in tracked file\n")
        .expect("failed to write nested tracked fixture");
    fs::write(
        root.join("ignored.txt"),
        "needle hidden by parent gitignore\n",
    )
    .expect("failed to write nested ignored fixture");
    fs::create_dir_all(root.join("ignored_dir")).expect("failed to create nested ignored_dir");
    fs::write(
        root.join("ignored_dir/nested.txt"),
        "needle hidden in parent ignored directory\n",
    )
    .expect("failed to write nested ignored dir fixture");

    (workspace, root)
}

fn setup_pattern_workspace() -> TempWorkspace {
    let workspace = TempWorkspace::new("pattern");
    let base = workspace.path();

    fs::write(base.join("root.txt"), "needle in root\n").expect("failed to write root fixture");

    let nested = base.join("nested");
    fs::create_dir_all(&nested).expect("failed to create nested directory");
    fs::write(nested.join("TestFile.TXT"), "Needle inside nested\n")
        .expect("failed to write nested fixture");
    fs::write(nested.join("notes.md"), "notes without keyword\n")
        .expect("failed to write markdown fixture");

    let deep = nested.join("deep");
    fs::create_dir_all(&deep).expect("failed to create deep directory");
    fs::write(deep.join("sample.rs"), "needle appears here\n")
        .expect("failed to write sample fixture");

    workspace
}

fn search_in_workspace(flag_gitignore: bool) -> HashSet<String> {
    let workspace = setup_gitignore_workspace();
    let cwd = workspace.path().to_string_lossy().to_string();

    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: ".".to_string(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let result = search_in_files(&options).expect("expected successful search");
    result.items.into_iter().map(|file| file.p).collect()
}

fn collect_result_paths(result: ISearchFileResult) -> HashSet<String> {
    result.items.into_iter().map(|file| file.p).collect()
}

fn search_in_nested_workspace(flag_gitignore: bool) -> HashSet<String> {
    let (_workspace, root) = setup_nested_gitignore_workspace();
    let cwd = root.to_string_lossy().to_string();

    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: ".".to_string(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let result = search_in_files(&options).expect("expected successful search");
    result.items.into_iter().map(|file| file.p).collect()
}

#[test]
fn t_search_in_files_lf_pattern_matches_only_lf_files() {
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
        .iter()
        .map(|file| {
            std::path::Path::new(&file.p)
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
fn t_search_in_files_crlf_pattern_matches_crlf_files() {
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
        .iter()
        .map(|file| {
            std::path::Path::new(&file.p)
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
fn t_search_in_files_respects_max_matches_limit() {
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
    assert!(
        result.limit_reached,
        "the match budget should stop traversal"
    );
    assert_eq!(result.items.len(), 1, "only a.txt should be included");

    let file_match = result
        .items
        .iter()
        .find(|file| file.p == "a.txt")
        .expect("a.txt should be present in results");

    assert_eq!(
        file_match.matches.len(),
        5,
        "expected exactly 5 matches to be recorded"
    );

    let last_match = file_match
        .matches
        .last()
        .expect("matches collection should not be empty");
    assert!(
        last_match.lx == last_match.ly,
        "match should occur on a single line"
    );
    assert_eq!(last_match.lx, 5, "last match should be on line 5");
}

#[test]
fn t_search_in_files_without_limit_reports_exhaustive_result() {
    let cwd = fixtures_dir();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore: true,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "Hello".to_string(),
        search_paths: ".".to_string(),
        include_patterns: "*.txt".to_string(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let result = search_in_files(&options).expect("expected successful search");
    assert!(
        !result.limit_reached,
        "unlimited traversal should be exhaustive"
    );
}

#[test]
fn t_search_in_files_rejects_non_positive_match_limit() {
    let cwd = fixtures_dir();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore: true,
        flag_regex: false,
        max_filesize: None,
        max_matches: Some(0),
        search_pattern: "Hello".to_string(),
        search_paths: ".".to_string(),
        include_patterns: "*.txt".to_string(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let error =
        search_in_files(&options).expect_err("zero must not silently produce an empty result");
    assert!(error.error.contains("positive integer or nil"));
}

#[test]
fn t_search_in_files_respects_gitignore_and_ignore_when_enabled() {
    let files = search_in_workspace(true);
    assert!(
        files.contains("tracked.txt"),
        "tracked.txt should be present in results"
    );
    assert!(
        !files.contains("ignored.txt"),
        "ignored.txt should be filtered by .gitignore"
    );
    assert!(
        !files.contains("ignored.log"),
        "ignored.log should be filtered by .ignore"
    );
    assert!(
        !files.contains("ignored_dir/nested.txt"),
        "ignored_dir/nested.txt should be filtered by gitignore directory rule"
    );
}

#[test]
fn t_search_in_files_includes_gitignored_when_flag_disabled() {
    let files = search_in_workspace(false);
    assert!(
        files.contains("tracked.txt"),
        "tracked.txt should be present in results"
    );
    assert!(
        files.contains("ignored.txt"),
        "ignored.txt should appear when gitignore is disabled"
    );
    assert!(
        files.contains("ignored.log"),
        "ignored.log should appear when gitignore is disabled"
    );
    assert!(
        files.contains("ignored_dir/nested.txt"),
        "ignored_dir/nested.txt should appear when gitignore is disabled"
    );
}

#[test]
fn t_search_in_files_respects_parent_gitignore_rules() {
    let files = search_in_nested_workspace(true);
    assert!(
        files.contains("tracked.txt"),
        "tracked.txt should be present from nested workspace"
    );
    assert!(
        !files.contains("ignored.txt"),
        "ignored.txt should be filtered by parent .gitignore"
    );
    assert!(
        !files.contains("ignored_dir/nested.txt"),
        "nested ignored files should be filtered by parent .gitignore"
    );
}

#[test]
fn t_search_in_files_includes_parent_gitignored_when_disabled() {
    let files = search_in_nested_workspace(false);
    assert!(
        files.contains("tracked.txt"),
        "tracked.txt should be present from nested workspace"
    );
    assert!(
        files.contains("ignored.txt"),
        "ignored.txt should appear when gitignore is disabled"
    );
    assert!(
        files.contains("ignored_dir/nested.txt"),
        "nested ignored files should appear when gitignore is disabled"
    );
}

#[test]
fn t_search_in_files_matches_literal_case_insensitive() {
    let workspace = setup_pattern_workspace();
    let cwd = workspace.path().to_string_lossy().to_string();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: false,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: String::new(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let files = collect_result_paths(search_in_files(&options).expect("expected search success"));
    assert!(
        files.contains("root.txt"),
        "case-insensitive search should include root.txt"
    );
    assert!(
        files.contains("nested/TestFile.TXT"),
        "case-insensitive search should match nested/TestFile.TXT"
    );
    assert!(
        files.contains("nested/deep/sample.rs"),
        "case-insensitive search should match nested/deep/sample.rs"
    );
    assert!(
        !files.contains("nested/notes.md"),
        "files without matches should not be included"
    );
}

#[test]
fn t_search_in_files_matches_literal_case_sensitive() {
    let workspace = setup_pattern_workspace();
    let cwd = workspace.path().to_string_lossy().to_string();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: String::new(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let files = collect_result_paths(search_in_files(&options).expect("expected search success"));
    assert!(
        files.contains("root.txt"),
        "case-sensitive search should include root.txt"
    );
    assert!(
        files.contains("nested/deep/sample.rs"),
        "case-sensitive search should include lowercase matches"
    );
    assert!(
        !files.contains("nested/TestFile.TXT"),
        "case-sensitive search should not match differently cased occurrences"
    );
}

#[test]
fn t_search_in_files_respects_include_patterns() {
    let workspace = setup_pattern_workspace();
    let cwd = workspace.path().to_string_lossy().to_string();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: false,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: String::new(),
        include_patterns: "nested/*.txt".to_string(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let files = collect_result_paths(search_in_files(&options).expect("expected search success"));
    assert_eq!(
        files,
        HashSet::from(["nested/TestFile.TXT".to_string()]),
        "include patterns should restrict results to matching files"
    );
}

#[test]
fn t_search_in_files_respects_exclude_patterns() {
    let workspace = setup_pattern_workspace();
    let cwd = workspace.path().to_string_lossy().to_string();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: false,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: String::new(),
        include_patterns: String::new(),
        exclude_patterns: "nested/*.txt".to_string(),
        specified_filepath: None,
    };

    let files = collect_result_paths(search_in_files(&options).expect("expected search success"));
    assert!(
        files.contains("root.txt"),
        "root.txt should remain when excluding nested txt files"
    );
    assert!(
        files.contains("nested/deep/sample.rs"),
        "sample.rs should remain when excluding nested txt files"
    );
    assert!(
        !files.contains("nested/TestFile.TXT"),
        "exclude patterns should filter matching files"
    );
}

#[test]
fn t_search_in_files_respects_search_paths() {
    let workspace = setup_pattern_workspace();
    let cwd = workspace.path().to_string_lossy().to_string();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: false,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: "nested".to_string(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let files = collect_result_paths(search_in_files(&options).expect("expected search success"));
    assert!(
        !files.contains("root.txt"),
        "files outside the search path should not be returned"
    );
    assert!(
        files.contains("nested/TestFile.TXT"),
        "search path should include nested/TestFile.TXT"
    );
    assert!(
        files.contains("nested/deep/sample.rs"),
        "search path should include nested/deep/sample.rs"
    );
}

#[test]
fn t_search_in_files_respects_specified_filepath() {
    let workspace = setup_pattern_workspace();
    let cwd = workspace.path().to_string_lossy().to_string();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: false,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: String::new(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: Some("nested/deep/sample.rs".to_string()),
    };

    let files = collect_result_paths(search_in_files(&options).expect("expected search success"));
    assert_eq!(
        files,
        HashSet::from(["nested/deep/sample.rs".to_string()]),
        "specified filepath should restrict results to that file"
    );
}

#[test]
fn t_search_in_files_handles_empty_pattern() {
    let workspace = setup_pattern_workspace();
    let cwd = workspace.path().to_string_lossy().to_string();
    let options = ISearchInFilesOptions {
        cwd: Some(cwd),
        flag_case_sensitive: false,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: String::new(),
        search_paths: String::new(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let result = search_in_files(&options).expect("expected search success");
    assert!(
        result.items.is_empty(),
        "empty search pattern should produce no matches"
    );
    assert_eq!(
        result.elapsed_time, 0,
        "empty search pattern should report zero elapsed time"
    );
}

#[test]
fn t_search_in_files_pre_cancel_dominates_setup() {
    let workspace = setup_pattern_workspace();
    let options = ISearchInFilesOptions {
        cwd: Some(workspace.path().to_string_lossy().to_string()),
        flag_case_sensitive: true,
        flag_gitignore: false,
        flag_regex: true,
        max_filesize: Some("invalid".to_string()),
        max_matches: None,
        search_pattern: "[".to_string(),
        search_paths: String::new(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };
    let cancelled = AtomicBool::new(true);

    let outcome = search_in_files_cancellable(&options, workspace.path().to_path_buf(), &cancelled);
    assert!(matches!(outcome, SearchInFilesOutcome::Cancelled));
}

#[test]
fn t_resolve_base_dir_captures_relative_cwd() {
    let relative_cwd = PathBuf::from("relative-search-root");
    let options = ISearchInFilesOptions {
        cwd: Some(relative_cwd.to_string_lossy().to_string()),
        flag_case_sensitive: true,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: String::new(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };

    let current_dir = std::env::current_dir().expect("current directory should be available");
    let resolved = resolve_base_dir(&options).expect("relative cwd should resolve");

    assert!(resolved.is_absolute());
    assert_eq!(current_dir.join(relative_cwd), resolved);
}

#[test]
fn t_cancellable_reader_returns_typed_non_interrupted_error() {
    struct CancelAfterRead<'cancel> {
        cancelled: &'cancel AtomicBool,
    }

    impl Read for CancelAfterRead<'_> {
        fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
            buffer[0] = b'x';
            self.cancelled.store(true, Ordering::Release);
            Ok(1)
        }
    }

    let cancelled = AtomicBool::new(false);
    let inner = CancelAfterRead {
        cancelled: &cancelled,
    };
    let mut reader = CancellableReader::new(inner, &cancelled);
    let error = reader
        .read(&mut [0u8; 1])
        .expect_err("cancellation after a read must be observed");

    assert_ne!(error.kind(), io::ErrorKind::Interrupted);
    assert!(
        error
            .get_ref()
            .is_some_and(|source| source.downcast_ref::<SearchCancelled>().is_some()),
        "expected the typed cancellation sentinel"
    );
}

#[test]
fn t_file_match_sink_reports_cancellation() {
    let options = ISearchInFilesOptions {
        cwd: None,
        flag_case_sensitive: true,
        flag_gitignore: false,
        flag_regex: false,
        max_filesize: None,
        max_matches: None,
        search_pattern: "needle".to_string(),
        search_paths: String::new(),
        include_patterns: String::new(),
        exclude_patterns: String::new(),
        specified_filepath: None,
    };
    let matcher = build_matcher(&options).expect("matcher should build");
    let cancelled = AtomicBool::new(true);
    let mut lines = Vec::new();
    let mut matches_count = 0;
    let mut sink = FileMatchSink {
        matcher: &matcher,
        lines: &mut lines,
        matches_count: &mut matches_count,
        max_matches: Some(100),
        cancelled: &cancelled,
    };
    let mut searcher = SearcherBuilder::new().multi_line(true).build();

    let error = searcher
        .search_reader(&matcher, io::Cursor::new(b"needle\n"), &mut sink)
        .expect_err("cancelled sink must stop the search");

    assert_ne!(error.kind(), io::ErrorKind::Interrupted);
    assert!(
        error
            .get_ref()
            .is_some_and(|source| source.downcast_ref::<SearchCancelled>().is_some()),
        "expected the typed cancellation sentinel"
    );
}
