use super::text_utils::build_preview_string;
use super::text_utils::compute_line_offsets;
use super::text_utils::locate_line;
use crate::string;
use crate::types::IFileMatch;
use crate::types::ISearchFailedResult;
use crate::types::ISearchFileResult;
use crate::types::ISearchInFilesOptions;
use crate::types::ITextMatch;
use grep::matcher::Matcher;
use grep::regex::RegexMatcher;
use grep::regex::RegexMatcherBuilder;
use grep::searcher::BinaryDetection;
use grep::searcher::Searcher;
use grep::searcher::SearcherBuilder;
use grep::searcher::Sink;
use grep::searcher::SinkMatch;
use ignore::WalkBuilder;
use ignore::overrides::OverrideBuilder;
use regex::escape;
use std::io;
use std::path::Path;
use std::path::PathBuf;
use std::time::Instant;

#[derive(Clone)]
struct MatchRange {
    start: usize,
    end: usize,
}

struct LineMatch {
    line_number: u64,
    offset: usize,
    text: Vec<u8>,
    matches: Vec<MatchRange>,
}

fn convert_line_matches(line: LineMatch) -> Vec<ITextMatch> {
    if line.text.is_empty() {
        return Vec::new();
    }

    let offsets = compute_line_offsets(&line.text);
    if offsets.len() < 2 {
        return Vec::new();
    }

    let mut matches = Vec::new();

    for range in line.matches {
        if range.start >= range.end || range.start >= line.text.len() {
            continue;
        }
        let end_exclusive = range.end.min(line.text.len());
        if end_exclusive <= range.start {
            continue;
        }

        let end_inclusive = end_exclusive - 1;
        let start_line = locate_line(&offsets, range.start);
        let end_line = locate_line(&offsets, end_inclusive);

        let line_start_rel = offsets[start_line - 1];
        let end_line_start_rel = offsets[end_line - 1];

        let ox = line.offset + range.start;
        let oy = line.offset + end_inclusive;

        let line_start_abs = line.offset + line_start_rel;
        let line_end_abs_exclusive = line.offset + offsets[end_line];
        let line_content_end_rel = if start_line == end_line {
            trim_line_trailing_newline(&line.text, line_start_rel, offsets[start_line])
        } else {
            offsets[start_line]
        };
        let line_content_end_abs = line.offset + line_content_end_rel;

        let preview_start_abs = std::cmp::max(line_start_abs, ox.saturating_sub(16));
        let preview_line_limit = if start_line == end_line && end_exclusive <= line_content_end_rel
        {
            line_content_end_abs
        } else {
            line_end_abs_exclusive
        };
        let preview_end_abs_exclusive =
            std::cmp::min(preview_line_limit, (oy + 1).saturating_add(16));

        let preview_start_rel = preview_start_abs.saturating_sub(line.offset);
        let preview_end_rel = preview_end_abs_exclusive.saturating_sub(line.offset);

        if preview_end_rel <= preview_start_rel || preview_end_rel > line.text.len() {
            continue;
        }

        let preview_bytes = &line.text[preview_start_rel..preview_end_rel];
        let start_rel_in_preview = range.start.saturating_sub(preview_start_rel);
        let end_rel_in_preview = end_inclusive.saturating_sub(preview_start_rel);

        let (preview_string, sx, sy) =
            build_preview_string(preview_bytes, start_rel_in_preview, end_rel_in_preview);

        let lx = (line.line_number as u32)
            .saturating_add((start_line - 1) as u32)
            .max(1);
        let ly = (line.line_number as u32)
            .saturating_add((end_line - 1) as u32)
            .max(lx);

        let cx = (range.start - line_start_rel) as u32;
        let cy = (end_inclusive - end_line_start_rel) as u32;

        matches.push(ITextMatch {
            lx,
            ly,
            cx,
            cy,
            ox,
            oy,
            s: preview_string,
            sx,
            sy,
        });
    }

    matches
}

fn trim_line_trailing_newline(bytes: &[u8], start: usize, end: usize) -> usize {
    let mut cursor = end;
    while cursor > start {
        let byte = bytes[cursor.saturating_sub(1)];
        match byte {
            b'\n' => {
                cursor = cursor.saturating_sub(1);
                if cursor > start && bytes[cursor - 1] == b'\r' {
                    cursor -= 1;
                }
            }
            b'\r' => cursor = cursor.saturating_sub(1),
            _ => break,
        }
    }
    cursor
}

fn flatten_line_matches(lines: Vec<LineMatch>) -> Vec<ITextMatch> {
    let mut result = Vec::new();
    for line in lines {
        result.extend(convert_line_matches(line));
    }
    result
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
    lines: &'matcher mut Vec<LineMatch>,
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
        let line_number = mat.line_number().unwrap_or(0);
        let absolute_offset = mat.absolute_byte_offset() as usize;

        let mut match_ranges: Vec<MatchRange> = Vec::new();
        let mut continue_search = true;

        let result = self.matcher.find_iter(bytes, |range| {
            if *self.matches_count >= self.max_matches {
                continue_search = false;
                return false;
            }

            match_ranges.push(MatchRange {
                start: range.start(),
                end: range.end(),
            });
            *self.matches_count = self.matches_count.saturating_add(1);
            true
        });

        if let Err(error) = result {
            return Err(io::Error::other(error));
        }

        if match_ranges.is_empty() {
            return Ok(continue_search && *self.matches_count < self.max_matches);
        }

        self.lines.push(LineMatch {
            line_number,
            offset: absolute_offset,
            text: bytes.to_vec(),
            matches: match_ranges,
        });

        Ok(continue_search && *self.matches_count < self.max_matches)
    }
}

pub fn search_in_files(
    options: &ISearchInFilesOptions,
) -> Result<ISearchFileResult, ISearchFailedResult> {
    if options.search_pattern.is_empty() {
        return Ok(ISearchFileResult {
            elapsed_time: 0,
            items: Vec::new(),
        });
    }

    let start = Instant::now();

    let base_dir = match resolve_base_dir(options) {
        Ok(path) => path,
        Err(error) => {
            return Err(ISearchFailedResult {
                elapsed_time: 0,
                error,
            });
        }
    };

    let include_patterns = string::parse_comma_list(&options.include_patterns);
    let exclude_patterns = string::parse_comma_list(&options.exclude_patterns);

    let overrides = match build_overrides(&base_dir, &include_patterns, &exclude_patterns) {
        Ok(overrides) => overrides,
        Err(error) => {
            return Err(ISearchFailedResult {
                elapsed_time: 0,
                error,
            });
        }
    };

    let matcher = match build_matcher(options) {
        Ok(matcher) => matcher,
        Err(error) => {
            return Err(ISearchFailedResult {
                elapsed_time: 0,
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
            return Err(ISearchFailedResult {
                elapsed_time: 0,
                error,
            });
        }
    };

    let mut walk_builder = WalkBuilder::new(&resolved_paths[0]);
    for additional in resolved_paths.iter().skip(1) {
        walk_builder.add(additional);
    }

    walk_builder.sort_by_file_path(|a, b| a.cmp(b));
    walk_builder.hidden(false);
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
    let mut items: Vec<IFileMatch> = Vec::new();

    for entry in walk_builder.build() {
        if matches_count >= max_matches {
            break;
        }

        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
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

        let mut lines: Vec<LineMatch> = Vec::new();
        let mut sink = FileMatchSink {
            matcher: &matcher,
            lines: &mut lines,
            matches_count: &mut matches_count,
            max_matches,
        };

        if let Err(error) = searcher.search_path(&matcher, &path, &mut sink) {
            return Err(ISearchFailedResult {
                elapsed_time: start.elapsed().as_millis() as u64,
                error: format!("Failed to search '{}': {}", display, error),
            });
        }

        if lines.is_empty() {
            continue;
        }

        let matches = flatten_line_matches(lines);
        if matches.is_empty() {
            continue;
        }

        items.push(IFileMatch {
            p: display,
            matches,
        });
    }

    Ok(ISearchFileResult {
        elapsed_time: start.elapsed().as_millis() as u64,
        items,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    fn fixtures_dir() -> String {
        let manifest_dir =
            std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not defined");
        let path = std::path::Path::new(&manifest_dir).join("tests/fixtures");
        path.to_string_lossy().to_string()
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
}
