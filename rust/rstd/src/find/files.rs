use crate::string;
use crate::types::{IFindFilesFailedResult, IFindFilesOptions, IFindFilesSucceedResult};
use globset::{Glob, GlobSet};
use ignore::WalkBuilder;
use regex::RegexBuilder;
use std::path::{Path, PathBuf};

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

fn build_excludes(patterns: &[String]) -> Result<Option<GlobSet>, String> {
    if patterns.is_empty() {
        return Ok(None);
    }

    let mut builder = globset::GlobSetBuilder::new();
    for pattern in patterns {
        builder.add(
            Glob::new(pattern)
                .map_err(|error| format!("Invalid exclude glob '{}': {}", pattern, error))?,
        );
    }

    builder
        .build()
        .map(Some)
        .map_err(|error| format!("Failed to build exclude globs: {}", error))
}

pub fn find_files(
    options: &IFindFilesOptions,
) -> Result<IFindFilesSucceedResult, IFindFilesFailedResult> {
    let cwd = PathBuf::from(&options.cwd);
    let search_paths = string::parse_comma_list(&options.search_paths);
    let exclude_patterns = string::parse_comma_list(&options.exclude_patterns);

    let matcher = build_matcher(options).map_err(|error| IFindFilesFailedResult { error })?;
    let excludes =
        build_excludes(&exclude_patterns).map_err(|error| IFindFilesFailedResult { error })?;

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

    walk_builder.hidden(true);
    walk_builder.git_ignore(options.flag_gitignore);
    walk_builder.git_global(options.flag_gitignore);
    walk_builder.git_exclude(options.flag_gitignore);

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
        let filename = match path.file_name().and_then(|name| name.to_str()) {
            Some(name) => name,
            None => continue,
        };

        if excludes
            .as_ref()
            .is_some_and(|exclude_set| exclude_set.is_match(filename))
        {
            continue;
        }

        if matcher
            .as_ref()
            .is_some_and(|regex| !regex.is_match(filename))
        {
            continue;
        }

        let relative = path.strip_prefix(&cwd).unwrap_or(path);
        let mut display = relative.to_string_lossy().to_string();
        if cfg!(windows) {
            display = display.replace('\\', "/");
        }
        filepaths.push(display);
    }

    filepaths.sort();
    filepaths.dedup();

    Ok(IFindFilesSucceedResult { filepaths })
}
