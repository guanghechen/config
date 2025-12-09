use crate::string;
use crate::types::IFindFilesFailedResult;
use crate::types::IFindFilesOptions;
use crate::types::IFindFilesSucceedResult;
use ignore::WalkBuilder;
use ignore::overrides::Override;
use ignore::overrides::OverrideBuilder;
use regex::RegexBuilder;
use std::path::Path;
use std::path::PathBuf;

fn normalize_root(base: &Path, entry: &str) -> PathBuf {
    let path = Path::new(entry);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        base.join(path)
    }
}

fn build_matcher(options: &IFindFilesOptions) -> Result<Option<regex::Regex>, String> {
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

fn build_overrides(
    cwd: &Path,
    patterns: &[String],
    case_sensitive: bool,
) -> Result<Option<Override>, String> {
    if patterns.is_empty() {
        return Ok(None);
    }

    let mut builder = OverrideBuilder::new(cwd);
    builder
        .case_insensitive(!case_sensitive)
        .map_err(|error| format!("Failed to configure exclude globs: {}", error))?;

    for pattern in patterns {
        let trimmed = pattern.trim();
        if trimmed.is_empty() {
            continue;
        }
        builder
            .add(&format!("!{}", trimmed))
            .map_err(|error| format!("Invalid exclude glob '{}': {}", trimmed, error))?;
    }

    builder
        .build()
        .map(Some)
        .map_err(|error| format!("Failed to build exclude overrides: {}", error))
}

pub fn find_files(
    options: &IFindFilesOptions,
) -> Result<IFindFilesSucceedResult, IFindFilesFailedResult> {
    let cwd = PathBuf::from(&options.cwd);
    let search_paths = string::parse_comma_list(&options.search_paths);
    let exclude_patterns = string::parse_comma_list(&options.exclude_patterns);

    let matcher = build_matcher(options).map_err(|error| IFindFilesFailedResult { error })?;
    let overrides = build_overrides(&cwd, &exclude_patterns, options.flag_case_sensitive)
        .map_err(|error| IFindFilesFailedResult { error })?;

    let mut roots: Vec<PathBuf> = Vec::new();
    if search_paths.is_empty() {
        roots.push(cwd.clone());
    } else {
        for entry in search_paths {
            if entry.is_empty() {
                continue;
            }
            roots.push(normalize_root(&cwd, &entry));
        }
        if roots.is_empty() {
            roots.push(cwd.clone());
        }
    }

    let mut walk_builder = WalkBuilder::new(&roots[0]);
    for additional in roots.iter().skip(1) {
        walk_builder.add(additional);
    }

    walk_builder.hidden(false);
    walk_builder.ignore(options.flag_gitignore);
    walk_builder.git_ignore(options.flag_gitignore);
    walk_builder.git_global(options.flag_gitignore);
    walk_builder.git_exclude(options.flag_gitignore);
    if let Some(overrides) = overrides {
        walk_builder.overrides(overrides);
    }
    if options.flag_gitignore {
        walk_builder.add_custom_ignore_filename(".gitignore");
    }

    let mut filepaths: Vec<String> = Vec::new();

    for entry in walk_builder.build() {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => {
                continue;
            }
        };

        if !entry
            .file_type()
            .map(|file_type| file_type.is_file())
            .unwrap_or(false)
        {
            continue;
        }

        let path = entry.path();
        let relative = path.strip_prefix(&cwd).unwrap_or(path);

        #[allow(unused_mut)]
        let mut display = relative.to_string_lossy().to_string();
        #[cfg(windows)]
        {
            display = display.replace('\\', "/");
        }

        if matcher
            .as_ref()
            .is_some_and(|regex| !regex.is_match(&display))
        {
            continue;
        }

        filepaths.push(display);
    }

    filepaths.sort();
    filepaths.dedup();

    Ok(IFindFilesSucceedResult { filepaths })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;
    use std::fs;
    use std::path::{Path, PathBuf};
    use uuid::Uuid;

    struct TempWorkspace {
        path: PathBuf,
    }

    impl TempWorkspace {
        fn new(prefix: &str) -> Self {
            let path =
                std::env::temp_dir().join(format!("yoz-find-{}-{}", prefix, Uuid::new_v4()));
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

    fn setup_workspace() -> TempWorkspace {
        let workspace = TempWorkspace::new("gitignore");
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

    fn setup_pattern_workspace() -> TempWorkspace {
        let workspace = TempWorkspace::new("pattern");
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

    fn setup_nested_workspace() -> (TempWorkspace, PathBuf) {
        let workspace = TempWorkspace::new("gitignore-nested");
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
            exclude_patterns: String::new(),
        };

        let result = find_files(&options).expect("expected successful search");
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
            exclude_patterns: String::new(),
        };

        let result = find_files(&options).expect("expected successful search");
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
            exclude_patterns: String::new(),
        };

        let files: HashSet<_> = find_files(&options)
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
            exclude_patterns: String::new(),
        };

        let files: HashSet<_> = find_files(&options)
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
            exclude_patterns: String::new(),
        };

        let files: HashSet<_> = find_files(&options)
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
            exclude_patterns: "*.md".to_string(),
        };

        let files: HashSet<_> = find_files(&options)
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
}
