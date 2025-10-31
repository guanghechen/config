use crate::string;
use crate::types::{
    ISearchBlockMatch, ISearchFileMatch, ISearchInFilesFailedResult, ISearchInFilesOptions,
    ISearchInFilesSucceedResult, ISearchMatchPoint,
};
use grep::matcher::Matcher;
use grep::regex::{RegexMatcher, RegexMatcherBuilder};
use grep::searcher::{BinaryDetection, Searcher, SearcherBuilder, Sink, SinkMatch};
use ignore::WalkBuilder;
use ignore::overrides::OverrideBuilder;
use regex::escape;
use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

fn format_elapsed(duration: Duration) -> String {
    format!("{:.3}s", duration.as_secs_f32())
}

fn parse_max_matches(options: &ISearchInFilesOptions) -> u32 {
    match options.max_matches {
        Some(value) if value >= 0 => value as u32,
        _ => u32::MAX,
    }
}

fn parse_max_filesize(value: &Option<String>) -> Result<Option<u64>, String> {
    let Some(raw) = value.as_ref() else {
        return Ok(None);
    };
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }

    let mut digits_end = 0usize;
    for ch in trimmed.chars() {
        if ch.is_ascii_digit() {
            digits_end += 1;
        } else {
            break;
        }
    }

    let number_part = trimmed[..digits_end].trim();
    if number_part.is_empty() {
        return Err(format!("Invalid max_filesize value: {}", raw));
    }

    let value: u64 = number_part
        .parse()
        .map_err(|_| format!("Unable to parse max_filesize numeric portion from: {}", raw))?;

    let unit_part = trimmed[digits_end..].trim().to_ascii_lowercase();
    let multiplier: u64 = match unit_part.as_str() {
        "" | "b" => 1,
        "k" | "kb" => 1_000,
        "m" | "mb" => 1_000_000,
        "g" | "gb" => 1_000_000_000,
        "t" | "tb" => 1_000_000_000_000,
        "p" | "pb" => 1_000_000_000_000_000,
        "ki" | "kib" => 1 << 10,
        "mi" | "mib" => 1 << 20,
        "gi" | "gib" => 1 << 30,
        "ti" | "tib" => 1 << 40,
        "pi" | "pib" => 1 << 50,
        other => {
            return Err(format!(
                "Unsupported max_filesize unit: {} (value: {})",
                other, raw
            ));
        }
    };

    Ok(Some(value.saturating_mul(multiplier)))
}

fn resolve_base_dir(options: &ISearchInFilesOptions) -> Result<PathBuf, String> {
    if let Some(cwd) = options.cwd.as_ref().filter(|cwd| !cwd.is_empty()) {
        Ok(PathBuf::from(cwd))
    } else {
        std::env::current_dir()
            .map_err(|error| format!("Failed to determine current directory: {}", error))
    }
}

fn resolve_search_paths(base: &Path, options: &ISearchInFilesOptions) -> Vec<PathBuf> {
    if let Some(filepath) = options
        .specified_filepath
        .as_ref()
        .filter(|path| !path.is_empty())
    {
        return vec![normalize_path(base, Path::new(filepath))];
    }

    let mut resolved_paths = Vec::new();
    for path in string::parse_comma_list(&options.search_paths) {
        if path.is_empty() {
            continue;
        }
        resolved_paths.push(normalize_path(base, Path::new(&path)));
    }

    if resolved_paths.is_empty() {
        resolved_paths.push(base.to_path_buf());
    }

    resolved_paths
}

fn normalize_path(base: &Path, path: &Path) -> PathBuf {
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        base.join(path)
    }
}

fn display_path(path: &Path, base: &Path) -> String {
    let relative = path
        .strip_prefix(base)
        .unwrap_or(path)
        .to_string_lossy()
        .to_string();
    if cfg!(windows) {
        relative.replace('\\', "/")
    } else {
        relative
    }
}

fn build_overrides(
    base: &Path,
    include_patterns: &[String],
    exclude_patterns: &[String],
) -> Result<Option<ignore::overrides::Override>, String> {
    if include_patterns.is_empty() && exclude_patterns.is_empty() {
        return Ok(None);
    }

    let mut builder = OverrideBuilder::new(base);

    for pattern in include_patterns {
        builder
            .add(pattern)
            .map_err(|error| format!("Invalid include glob '{}': {}", pattern, error))?;
    }

    for pattern in exclude_patterns {
        let glob = format!("!{}", pattern);
        builder
            .add(&glob)
            .map_err(|error| format!("Invalid exclude glob '{}': {}", pattern, error))?;
    }

    builder
        .build()
        .map(Some)
        .map_err(|error| format!("Failed to build glob overrides: {}", error))
}

fn build_matcher(options: &ISearchInFilesOptions) -> Result<RegexMatcher, String> {
    if options.search_pattern.is_empty() {
        return Err("Search pattern cannot be empty".into());
    }

    let mut builder = RegexMatcherBuilder::new();
    builder.case_insensitive(!options.flag_case_sensitive);
    builder.multi_line(true);
    builder.unicode(true);
    builder.dot_matches_new_line(true);

    if options.flag_regex {
        builder
            .build(&options.search_pattern)
            .map_err(|error| format!("Failed to build regex matcher: {}", error))
    } else {
        builder
            .build(&escape(&options.search_pattern))
            .map_err(|error| format!("Failed to build literal matcher: {}", error))
    }
}

struct FileMatchSink<'matcher, 'count> {
    matcher: &'matcher RegexMatcher,
    blocks: &'matcher mut Vec<ISearchBlockMatch>,
    matches_count: &'count mut u32,
    max_matches: u32,
}

impl<'matcher, 'count> Sink for FileMatchSink<'matcher, 'count> {
    type Error = io::Error;

    fn matched(&mut self, _searcher: &Searcher, mat: &SinkMatch<'_>) -> Result<bool, Self::Error> {
        if *self.matches_count >= self.max_matches {
            return Ok(false);
        }

        let bytes = mat.bytes();
        let line_number = mat.line_number().unwrap_or(0) as usize;
        let absolute_offset = mat.absolute_byte_offset() as usize;

        let mut match_points: Vec<ISearchMatchPoint> = Vec::new();
        let mut continue_search = true;

        let result = self.matcher.find_iter(bytes, |range| {
            if *self.matches_count >= self.max_matches {
                continue_search = false;
                return false;
            }

            match_points.push(ISearchMatchPoint {
                l: range.start(),
                r: range.end(),
            });
            *self.matches_count = self.matches_count.saturating_add(1);
            true
        });

        if let Err(error) = result {
            return Err(io::Error::other(error));
        }

        if match_points.is_empty() {
            return Ok(continue_search && *self.matches_count < self.max_matches);
        }

        let text = String::from_utf8_lossy(bytes).into_owned();
        self.blocks.push(ISearchBlockMatch {
            lnum: line_number,
            text,
            offset: absolute_offset,
            matches: match_points,
        });

        Ok(continue_search && *self.matches_count < self.max_matches)
    }
}

pub fn search_in_files(
    options: &ISearchInFilesOptions,
) -> Result<ISearchInFilesSucceedResult, ISearchInFilesFailedResult> {
    if options.search_pattern.is_empty() {
        return Ok(ISearchInFilesSucceedResult {
            elapsed_time: "0s".into(),
            items: HashMap::new(),
        });
    }

    let start = Instant::now();

    let base_dir = match resolve_base_dir(options) {
        Ok(path) => path,
        Err(error) => {
            return Err(ISearchInFilesFailedResult {
                elapsed_time: "0s".into(),
                error,
            });
        }
    };

    let include_patterns = string::parse_comma_list(&options.include_patterns);
    let exclude_patterns = string::parse_comma_list(&options.exclude_patterns);

    let overrides = match build_overrides(&base_dir, &include_patterns, &exclude_patterns) {
        Ok(overrides) => overrides,
        Err(error) => {
            return Err(ISearchInFilesFailedResult {
                elapsed_time: "0s".into(),
                error,
            });
        }
    };

    let matcher = match build_matcher(options) {
        Ok(matcher) => matcher,
        Err(error) => {
            return Err(ISearchInFilesFailedResult {
                elapsed_time: "0s".into(),
                error,
            });
        }
    };

    let mut searcher_builder = SearcherBuilder::new();
    searcher_builder
        .multi_line(true)
        .line_number(true)
        .binary_detection(BinaryDetection::quit(b'\x00'));
    let mut searcher = searcher_builder.build();

    let max_matches = parse_max_matches(options);
    let resolved_paths = resolve_search_paths(&base_dir, options);
    let filesize_limit = match parse_max_filesize(&options.max_filesize) {
        Ok(limit) => limit,
        Err(error) => {
            return Err(ISearchInFilesFailedResult {
                elapsed_time: "0s".into(),
                error,
            });
        }
    };

    let mut walk_builder = WalkBuilder::new(&resolved_paths[0]);
    for additional in resolved_paths.iter().skip(1) {
        walk_builder.add(additional);
    }

    walk_builder.hidden(true);
    walk_builder.git_ignore(options.flag_gitignore);
    walk_builder.git_global(options.flag_gitignore);
    walk_builder.git_exclude(options.flag_gitignore);

    if let Some(limit) = filesize_limit {
        walk_builder.max_filesize(Some(limit));
    }

    if let Some(overrides) = overrides {
        walk_builder.overrides(overrides);
    }

    let mut matches_count: u32 = 0;
    let mut filematches: HashMap<String, ISearchFileMatch> = HashMap::new();

    for result in walk_builder.build() {
        if matches_count >= max_matches {
            break;
        }

        let entry = match result {
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

        let path = entry.into_path();
        let display = display_path(&path, &base_dir);

        let mut blocks: Vec<ISearchBlockMatch> = Vec::new();
        let mut sink = FileMatchSink {
            matcher: &matcher,
            blocks: &mut blocks,
            matches_count: &mut matches_count,
            max_matches,
        };

        let search_result = searcher.search_path(&matcher, &path, &mut sink);

        if let Err(error) = search_result {
            return Err(ISearchInFilesFailedResult {
                elapsed_time: format_elapsed(start.elapsed()),
                error: format!("Failed to search '{}': {}", display, error),
            });
        }

        if !blocks.is_empty() {
            filematches.insert(display, ISearchFileMatch { matches: blocks });
        }
    }

    Ok(ISearchInFilesSucceedResult {
        elapsed_time: format_elapsed(start.elapsed()),
        items: filematches,
    })
}
