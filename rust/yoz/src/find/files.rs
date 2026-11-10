use crate::job::{self, QueryJob};
use crate::search::build_overrides;
use crate::string;
use crate::types::IFindFilesOptions;
use crate::types::IFindFilesSucceedResult;
use ignore::overrides::Override;
use ignore::{DirEntry, ParallelVisitor, ParallelVisitorBuilder, WalkBuilder, WalkState};
use regex::Regex;
use regex::RegexBuilder;
use std::path::Path;
use std::path::PathBuf;
use std::sync::Mutex;
use std::sync::atomic::{AtomicBool, Ordering};

pub type FindFilesJob = QueryJob<IFindFilesSucceedResult>;

/// A walk checked before its worker starts, so that a bad pattern fails at once.
struct Walk {
    cwd: PathBuf,
    roots: Vec<PathBuf>,
    matcher: Option<Regex>,
    overrides: Option<Override>,
    gitignore: bool,
}

fn normalize_root(base: &Path, entry: &str) -> PathBuf {
    let path = Path::new(entry);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        base.join(path)
    }
}

fn build_matcher(options: &IFindFilesOptions) -> Result<Option<Regex>, String> {
    if options.search_pattern.trim().is_empty() {
        return Ok(None);
    }

    let expression = if options.flag_regex {
        options.search_pattern.clone()
    } else {
        regex::escape(&options.search_pattern)
    };

    RegexBuilder::new(&expression)
        .case_insensitive(!options.flag_case_sensitive)
        .unicode(true)
        .build()
        .map(Some)
        .map_err(|error| format!("Failed to build search pattern: {}", error))
}

fn prepare(options: &IFindFilesOptions) -> Result<Walk, String> {
    let cwd = PathBuf::from(&options.cwd);
    let matcher = build_matcher(options)?;
    let overrides = build_overrides(
        &cwd,
        &string::parse_comma_list(&options.include_patterns),
        &string::parse_comma_list(&options.exclude_patterns),
        options.flag_case_sensitive,
    )?;

    let mut roots: Vec<PathBuf> = string::parse_comma_list(&options.search_paths)
        .iter()
        .filter(|entry| !entry.is_empty())
        .map(|entry| normalize_root(&cwd, entry))
        .collect();
    if roots.is_empty() {
        roots.push(cwd.clone());
    }

    Ok(Walk {
        cwd,
        roots,
        matcher,
        overrides,
        gitignore: options.flag_gitignore,
    })
}

/// What every walker thread shares: the files each one finds join `found` when the thread is done.
#[derive(Clone, Copy)]
struct Collect<'s> {
    cwd: &'s Path,
    matcher: Option<&'s Regex>,
    cancelled: &'s AtomicBool,
    found: &'s Mutex<Vec<String>>,
}

impl<'s> ParallelVisitorBuilder<'s> for Collect<'s> {
    fn build(&mut self) -> Box<dyn ParallelVisitor + 's> {
        Box::new(Visitor {
            scope: *self,
            filepaths: Vec::new(),
        })
    }
}

struct Visitor<'s> {
    scope: Collect<'s>,
    filepaths: Vec<String>,
}

impl ParallelVisitor for Visitor<'_> {
    fn visit(&mut self, entry: Result<DirEntry, ignore::Error>) -> WalkState {
        if self.scope.cancelled.load(Ordering::Relaxed) {
            return WalkState::Quit;
        }
        let Ok(entry) = entry else {
            return WalkState::Continue;
        };
        if !entry
            .file_type()
            .map(|file_type| file_type.is_file())
            .unwrap_or(false)
        {
            return WalkState::Continue;
        }

        let path = entry.path();
        let relative = path.strip_prefix(self.scope.cwd).unwrap_or(path);

        #[allow(unused_mut)]
        let mut display = relative.to_string_lossy().to_string();
        #[cfg(windows)]
        {
            display = display.replace('\\', "/");
        }

        if self
            .scope
            .matcher
            .is_some_and(|regex| !regex.is_match(&display))
        {
            return WalkState::Continue;
        }

        self.filepaths.push(display);
        WalkState::Continue
    }
}

impl Drop for Visitor<'_> {
    fn drop(&mut self) {
        self.scope
            .found
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .append(&mut self.filepaths);
    }
}

fn collect(walk: Walk, cancelled: &AtomicBool) -> IFindFilesSucceedResult {
    let mut walk_builder = WalkBuilder::new(&walk.roots[0]);
    for additional in walk.roots.iter().skip(1) {
        walk_builder.add(additional);
    }

    walk_builder.hidden(false);
    walk_builder.ignore(walk.gitignore);
    walk_builder.git_ignore(walk.gitignore);
    walk_builder.git_global(walk.gitignore);
    walk_builder.git_exclude(walk.gitignore);
    if let Some(overrides) = walk.overrides {
        walk_builder.overrides(overrides);
    }
    if walk.gitignore {
        walk_builder.add_custom_ignore_filename(".gitignore");
    }

    let found = Mutex::new(Vec::new());
    walk_builder.build_parallel().visit(&mut Collect {
        cwd: &walk.cwd,
        matcher: walk.matcher.as_ref(),
        cancelled,
        found: &found,
    });

    let mut filepaths = found
        .into_inner()
        .unwrap_or_else(|error| error.into_inner());
    filepaths.sort_unstable();
    filepaths.dedup();
    IFindFilesSucceedResult { filepaths }
}

/// Walks on a worker thread, several directories at a time; the files come sorted.
pub fn start_find_files(options: &IFindFilesOptions) -> Result<FindFilesJob, String> {
    let walk = prepare(options)?;
    job::spawn("yoz-find-files", move |cancelled| {
        Ok(collect(walk, cancelled))
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::job::Outcome;
    use crate::test_support::TempDir;
    use crate::test_support::eventually;
    use std::collections::HashSet;
    use std::fs;
    use std::path::PathBuf;

    fn find(options: &IFindFilesOptions) -> Result<IFindFilesSucceedResult, String> {
        Ok(collect(prepare(options)?, &AtomicBool::new(false)))
    }

    fn setup_workspace() -> TempDir {
        let workspace = TempDir::new();
        let base = workspace.path();

        fs::write(base.join(".gitignore"), "ignored.txt\nignored_dir/\n")
            .expect("failed to write .gitignore fixture");
        fs::write(base.join(".ignore"), "*.log\n").expect("failed to write .ignore fixture");
        fs::write(base.join("tracked.txt"), "tracked file\n")
            .expect("failed to write tracked fixture");
        fs::write(base.join("ignored.txt"), "ignored file\n")
            .expect("failed to write gitignored fixture");
        fs::write(base.join("ignored.log"), "should be hidden by .ignore\n")
            .expect("failed to write ignored fixture");
        fs::create_dir_all(base.join("ignored_dir")).expect("failed to create ignored_dir");
        fs::write(
            base.join("ignored_dir/hidden.txt"),
            "should be hidden by gitignore directory rule\n",
        )
        .expect("failed to write ignored dir fixture");

        workspace
    }

    fn setup_pattern_workspace() -> TempDir {
        let workspace = TempDir::new();
        let base = workspace.path();

        fs::write(base.join("root.txt"), "root file\n").expect("failed to write root file");

        let nested = base.join("nested");
        fs::create_dir_all(&nested).expect("failed to create nested directory");
        fs::write(nested.join("TestFile.TXT"), "test file\n")
            .expect("failed to write nested test file");
        fs::write(nested.join("notes.md"), "notes\n").expect("failed to write markdown file");
        fs::create_dir_all(nested.join("deep")).expect("failed to create deep directory");
        fs::write(nested.join("deep/sample.rs"), "sample\n").expect("failed to write sample file");

        workspace
    }

    fn setup_nested_workspace() -> (TempDir, PathBuf) {
        let workspace = TempDir::new();
        let base = workspace.path();
        let root = base.join("nested");

        fs::create_dir_all(&root).expect("failed to create nested workspace root");
        fs::write(base.join(".gitignore"), "ignored.txt\nignored_dir/\n")
            .expect("failed to write parent .gitignore");
        fs::write(root.join("tracked.txt"), "tracked file\n")
            .expect("failed to write nested tracked file");
        fs::create_dir_all(root.join("ignored_dir")).expect("failed to create nested ignored_dir");
        fs::write(
            root.join("ignored_dir/nested.txt"),
            "should be hidden by parent gitignore directory rule\n",
        )
        .expect("failed to write nested ignored dir fixture");
        fs::write(root.join("ignored.txt"), "ignored file\n")
            .expect("failed to write nested ignored file");

        (workspace, root)
    }

    fn find_in_workspace(flag_gitignore: bool) -> HashSet<String> {
        let workspace = setup_workspace();
        let options = IFindFilesOptions {
            cwd: workspace.path().to_string_lossy().to_string(),
            flag_case_sensitive: false,
            flag_gitignore,
            flag_regex: false,
            search_pattern: String::new(),
            search_paths: ".".to_string(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
        };

        let result = find(&options).expect("expected successful search");
        result.filepaths.into_iter().collect()
    }

    fn find_in_nested_workspace(flag_gitignore: bool) -> HashSet<String> {
        let (_workspace, root) = setup_nested_workspace();
        let options = IFindFilesOptions {
            cwd: root.to_string_lossy().to_string(),
            flag_case_sensitive: false,
            flag_gitignore,
            flag_regex: false,
            search_pattern: String::new(),
            search_paths: ".".to_string(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
        };

        let result = find(&options).expect("expected successful search");
        result.filepaths.into_iter().collect()
    }

    #[test]
    fn t_find_files_matches_literal_pattern_case_insensitive() {
        let workspace = setup_pattern_workspace();
        let options = IFindFilesOptions {
            cwd: workspace.path().to_string_lossy().to_string(),
            flag_case_sensitive: false,
            flag_gitignore: false,
            flag_regex: false,
            search_pattern: "testfile".to_string(),
            search_paths: String::new(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
        };

        let files: HashSet<_> = find(&options)
            .expect("expected successful search")
            .filepaths
            .into_iter()
            .collect();

        assert!(
            files.contains("nested/TestFile.TXT"),
            "literal pattern should match nested/TestFile.TXT"
        );
        assert!(
            !files.contains("nested/notes.md"),
            "literal pattern should not match non-matching files"
        );
    }

    #[test]
    fn t_find_files_matches_regex_pattern_case_sensitive() {
        let workspace = setup_pattern_workspace();
        let options = IFindFilesOptions {
            cwd: workspace.path().to_string_lossy().to_string(),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: true,
            search_pattern: r"nested/.+\.TXT$".to_string(),
            search_paths: String::new(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
        };

        let files: HashSet<_> = find(&options)
            .expect("expected successful search")
            .filepaths
            .into_iter()
            .collect();

        assert!(
            files.contains("nested/TestFile.TXT"),
            "regex pattern should match nested/TestFile.TXT"
        );
        assert!(
            !files.contains("nested/notes.md"),
            "regex pattern should not match nested/notes.md"
        );
    }

    #[test]
    fn t_find_files_respects_search_paths() {
        let workspace = setup_pattern_workspace();
        let options = IFindFilesOptions {
            cwd: workspace.path().to_string_lossy().to_string(),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: false,
            search_pattern: String::new(),
            search_paths: "nested".to_string(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
        };

        let files: HashSet<_> = find(&options)
            .expect("expected successful search")
            .filepaths
            .into_iter()
            .collect();

        assert!(
            files.contains("nested/TestFile.TXT"),
            "nested files should be returned when search path targets nested directory"
        );
        assert!(
            files.contains("nested/notes.md"),
            "nested files should include all matching entries"
        );
        assert!(
            !files.contains("root.txt"),
            "files outside the search path should not be returned"
        );
    }

    #[test]
    fn t_find_files_respects_exclude_patterns() {
        let workspace = setup_pattern_workspace();
        let options = IFindFilesOptions {
            cwd: workspace.path().to_string_lossy().to_string(),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: false,
            search_pattern: String::new(),
            search_paths: String::new(),
            include_patterns: String::new(),
            exclude_patterns: "*.md".to_string(),
        };

        let files: HashSet<_> = find(&options)
            .expect("expected successful search")
            .filepaths
            .into_iter()
            .collect();

        assert!(
            files.contains("nested/TestFile.TXT"),
            "non-excluded files should be returned"
        );
        assert!(
            !files.contains("nested/notes.md"),
            "exclude patterns should filter matching files"
        );
    }

    #[test]
    fn t_find_files_respects_gitignore_and_ignore_when_enabled() {
        let files = find_in_workspace(true);
        assert!(
            files.contains("tracked.txt"),
            "tracked.txt should be returned"
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
            !files.contains("ignored_dir/hidden.txt"),
            "files inside ignored directories should be filtered"
        );
    }

    #[test]
    fn t_find_files_includes_gitignored_when_flag_disabled() {
        let files = find_in_workspace(false);
        assert!(
            files.contains("tracked.txt"),
            "tracked.txt should still be returned"
        );
        assert!(
            files.contains("ignored.txt"),
            "ignored.txt should be visible when gitignore is disabled"
        );
        assert!(
            files.contains("ignored.log"),
            "ignored.log should be visible when gitignore is disabled"
        );
        assert!(
            files.contains("ignored_dir/hidden.txt"),
            "files inside ignored directories should be visible when gitignore is disabled"
        );
    }

    #[test]
    fn t_find_files_respects_parent_gitignore_rules() {
        let files = find_in_nested_workspace(true);
        assert!(
            files.contains("tracked.txt"),
            "tracked.txt should be returned from nested workspace"
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
    fn t_find_files_includes_parent_gitignored_when_disabled() {
        let files = find_in_nested_workspace(false);
        assert!(
            files.contains("tracked.txt"),
            "tracked.txt should be returned from nested workspace"
        );
        assert!(
            files.contains("ignored.txt"),
            "ignored.txt should be visible when gitignore is disabled"
        );
        assert!(
            files.contains("ignored_dir/nested.txt"),
            "nested ignored files should be visible when gitignore is disabled"
        );
    }

    #[test]
    fn t_find_files_lists_only_included_files() {
        let workspace = setup_pattern_workspace();
        let options = IFindFilesOptions {
            cwd: workspace.path().to_string_lossy().to_string(),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: false,
            search_pattern: String::new(),
            search_paths: String::new(),
            include_patterns: "*.md,*.rs".to_string(),
            exclude_patterns: "deep/".to_string(),
        };

        let result = find(&options).expect("expected successful search");
        assert_eq!(vec!["nested/notes.md".to_string()], result.filepaths);
    }

    #[test]
    fn t_find_files_job_completes_with_every_file_sorted() {
        let workspace = TempDir::new();
        let mut expected = Vec::new();
        for directory in 0..12 {
            for depth in 0..3 {
                let relative = format!("d{directory:02}/{}", "sub/".repeat(depth));
                fs::create_dir_all(workspace.path().join(&relative))
                    .expect("failed to create a directory");
                for file in 0..8 {
                    let filepath = format!("{relative}f{file}.txt");
                    fs::write(workspace.path().join(&filepath), "x\n")
                        .expect("failed to write a file");
                    expected.push(filepath);
                }
            }
        }
        expected.sort();

        let options = IFindFilesOptions {
            cwd: workspace.path().to_string_lossy().to_string(),
            flag_case_sensitive: false,
            flag_gitignore: false,
            flag_regex: false,
            search_pattern: String::new(),
            search_paths: String::new(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
        };
        let mut job = start_find_files(&options).expect("the worker should start");
        eventually(|| job.poll().unwrap().is_some());
        let Some(Outcome::Completed(result)) = job.poll().unwrap() else {
            panic!("completed")
        };
        assert_eq!(expected, result.filepaths);
    }

    #[test]
    fn t_find_files_job_rejects_a_bad_glob_before_its_worker() {
        let workspace = setup_pattern_workspace();
        let options = IFindFilesOptions {
            cwd: workspace.path().to_string_lossy().to_string(),
            flag_case_sensitive: false,
            flag_gitignore: false,
            flag_regex: false,
            search_pattern: String::new(),
            search_paths: String::new(),
            include_patterns: "[".to_string(),
            exclude_patterns: String::new(),
        };
        let Err(error) = start_find_files(&options) else {
            panic!("an invalid include glob must not start a walk")
        };
        assert!(error.contains("Invalid include glob '['"), "{error}");
    }
}
