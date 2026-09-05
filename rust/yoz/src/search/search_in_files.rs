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
use ignore::overrides::Override;
use ignore::overrides::OverrideBuilder;
use regex::escape;
use std::fmt;
use std::fs::File;
use std::io;
use std::io::Read;
use std::path::Path;
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::time::Instant;

#[derive(Clone, Debug)]
pub(crate) enum SearchInFilesOutcome {
    Completed(ISearchFileResult),
    Cancelled,
    Failed(ISearchFailedResult),
}

#[derive(Debug)]
struct SearchCancelled;

impl fmt::Display for SearchCancelled {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("search cancelled")
    }
}

impl std::error::Error for SearchCancelled {}

fn cancellation_error() -> io::Error {
    io::Error::other(SearchCancelled)
}

fn is_cancelled(cancelled: &AtomicBool) -> bool {
    cancelled.load(Ordering::Acquire)
}

struct CancellableReader<'cancel, R> {
    inner: R,
    cancelled: &'cancel AtomicBool,
}

impl<'cancel, R> CancellableReader<'cancel, R> {
    fn new(inner: R, cancelled: &'cancel AtomicBool) -> Self {
        Self { inner, cancelled }
    }
}

impl<R: Read> Read for CancellableReader<'_, R> {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if is_cancelled(self.cancelled) {
            return Err(cancellation_error());
        }

        let result = self.inner.read(buffer);
        if is_cancelled(self.cancelled) {
            return Err(cancellation_error());
        }
        result
    }
}

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

fn append_line_matches(line: LineMatch, result: &mut Vec<ITextMatch>) {
    if line.text.is_empty() {
        return;
    }

    let offsets = compute_line_offsets(&line.text);
    if offsets.len() < 2 {
        return;
    }

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

        let preview_start_abs = std::cmp::max(line_start_abs, ox.saturating_sub(64));
        let preview_line_limit = if start_line == end_line && end_exclusive <= line_content_end_rel
        {
            line_content_end_abs
        } else {
            line_end_abs_exclusive
        };
        let preview_end_abs_exclusive =
            std::cmp::min(preview_line_limit, (oy + 1).saturating_add(64));

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

        result.push(ITextMatch {
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
    let capacity = lines.iter().map(|line| line.matches.len()).sum();
    let mut result = Vec::with_capacity(capacity);
    for line in lines {
        append_line_matches(line, &mut result);
    }
    result
}

fn parse_max_matches(options: &ISearchInFilesOptions) -> Result<Option<u32>, String> {
    match options.max_matches {
        Some(value) if value > 0 => Ok(Some(value as u32)),
        Some(value) => Err(format!(
            "Invalid max_matches '{}': expected a positive integer or nil",
            value
        )),
        None => Ok(None),
    }
}

fn reached_match_limit(matches_count: u32, max_matches: Option<u32>) -> bool {
    max_matches.is_some_and(|limit| matches_count >= limit)
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

pub(crate) fn resolve_base_dir(options: &ISearchInFilesOptions) -> Result<PathBuf, String> {
    if let Some(cwd) = options.cwd.as_ref().filter(|cwd| !cwd.is_empty()) {
        let cwd = PathBuf::from(cwd);
        if cwd.is_absolute() {
            return Ok(cwd);
        }

        return std::env::current_dir()
            .map(|current_dir| current_dir.join(cwd))
            .map_err(|error| format!("Failed to determine current directory: {}", error));
    }

    std::env::current_dir()
        .map_err(|error| format!("Failed to determine current directory: {}", error))
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
    case_sensitive: bool,
) -> Result<Option<Override>, String> {
    if include_patterns.is_empty() && exclude_patterns.is_empty() {
        return Ok(None);
    }

    let mut builder = OverrideBuilder::new(base);
    builder
        .case_insensitive(!case_sensitive)
        .map_err(|error| format!("Failed to configure glob overrides: {}", error))?;

    for pattern in include_patterns {
        let trimmed = pattern.trim();
        if trimmed.is_empty() {
            continue;
        }
        builder
            .add(trimmed)
            .map_err(|error| format!("Invalid include glob '{}': {}", trimmed, error))?;
    }

    for pattern in exclude_patterns {
        let trimmed = pattern.trim();
        if trimmed.is_empty() {
            continue;
        }
        let glob = format!("!{}", trimmed);
        builder
            .add(&glob)
            .map_err(|error| format!("Invalid exclude glob '{}': {}", trimmed, error))?;
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

struct FileMatchSink<'matcher, 'count, 'cancel> {
    matcher: &'matcher RegexMatcher,
    lines: &'matcher mut Vec<LineMatch>,
    matches_count: &'count mut u32,
    max_matches: Option<u32>,
    cancelled: &'cancel AtomicBool,
}

impl<'matcher, 'count, 'cancel> Sink for FileMatchSink<'matcher, 'count, 'cancel> {
    type Error = io::Error;

    fn matched(&mut self, _searcher: &Searcher, mat: &SinkMatch<'_>) -> Result<bool, Self::Error> {
        if is_cancelled(self.cancelled) {
            return Err(cancellation_error());
        }

        if reached_match_limit(*self.matches_count, self.max_matches) {
            return Ok(false);
        }

        let bytes = mat.bytes();
        let line_number = mat.line_number().unwrap_or(0);
        let absolute_offset = mat.absolute_byte_offset() as usize;

        let mut match_ranges: Vec<MatchRange> = Vec::new();
        let mut continue_search = true;

        let result = self.matcher.find_iter(bytes, |range| {
            if is_cancelled(self.cancelled) {
                continue_search = false;
                return false;
            }

            if reached_match_limit(*self.matches_count, self.max_matches) {
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
        if is_cancelled(self.cancelled) {
            return Err(cancellation_error());
        }

        if match_ranges.is_empty() {
            return Ok(
                continue_search && !reached_match_limit(*self.matches_count, self.max_matches)
            );
        }

        self.lines.push(LineMatch {
            line_number,
            offset: absolute_offset,
            text: bytes.to_vec(),
            matches: match_ranges,
        });

        Ok(continue_search && !reached_match_limit(*self.matches_count, self.max_matches))
    }
}

pub fn search_in_files(
    options: &ISearchInFilesOptions,
) -> Result<ISearchFileResult, ISearchFailedResult> {
    if options.search_pattern.is_empty() {
        return Ok(ISearchFileResult {
            elapsed_time: 0,
            items: Vec::new(),
            limit_reached: false,
        });
    }

    let base_dir = match resolve_base_dir(options) {
        Ok(path) => path,
        Err(error) => {
            return Err(ISearchFailedResult {
                elapsed_time: 0,
                error,
            });
        }
    };

    let cancelled = AtomicBool::new(false);
    match search_in_files_cancellable(options, base_dir, &cancelled) {
        SearchInFilesOutcome::Completed(result) => Ok(result),
        SearchInFilesOutcome::Failed(error) => Err(error),
        SearchInFilesOutcome::Cancelled => Err(ISearchFailedResult {
            elapsed_time: 0,
            error: "Synchronous search was unexpectedly cancelled".to_string(),
        }),
    }
}

pub(crate) fn search_in_files_cancellable(
    options: &ISearchInFilesOptions,
    base_dir: PathBuf,
    cancelled: &AtomicBool,
) -> SearchInFilesOutcome {
    if is_cancelled(cancelled) {
        return SearchInFilesOutcome::Cancelled;
    }

    if options.search_pattern.is_empty() {
        return SearchInFilesOutcome::Completed(ISearchFileResult {
            elapsed_time: 0,
            items: Vec::new(),
            limit_reached: false,
        });
    }

    let start = Instant::now();

    let include_patterns = string::parse_comma_list(&options.include_patterns);
    let exclude_patterns = string::parse_comma_list(&options.exclude_patterns);

    if is_cancelled(cancelled) {
        return SearchInFilesOutcome::Cancelled;
    }

    let overrides = match build_overrides(
        &base_dir,
        &include_patterns,
        &exclude_patterns,
        options.flag_case_sensitive,
    ) {
        Ok(overrides) => overrides,
        Err(error) => {
            return SearchInFilesOutcome::Failed(ISearchFailedResult {
                elapsed_time: 0,
                error,
            });
        }
    };

    let matcher = match build_matcher(options) {
        Ok(matcher) => matcher,
        Err(error) => {
            return SearchInFilesOutcome::Failed(ISearchFailedResult {
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

    if is_cancelled(cancelled) {
        return SearchInFilesOutcome::Cancelled;
    }

    let max_matches = match parse_max_matches(options) {
        Ok(limit) => limit,
        Err(error) => {
            return SearchInFilesOutcome::Failed(ISearchFailedResult {
                elapsed_time: 0,
                error,
            });
        }
    };
    let resolved_paths = resolve_search_paths(&base_dir, options);
    let filesize_limit = match parse_max_filesize(&options.max_filesize) {
        Ok(limit) => limit,
        Err(error) => {
            return SearchInFilesOutcome::Failed(ISearchFailedResult {
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
    walk_builder.ignore(options.flag_gitignore);
    walk_builder.git_ignore(options.flag_gitignore);
    walk_builder.git_global(options.flag_gitignore);
    walk_builder.git_exclude(options.flag_gitignore);
    if options.flag_gitignore {
        walk_builder.add_custom_ignore_filename(".gitignore");
    }

    if let Some(limit) = filesize_limit {
        walk_builder.max_filesize(Some(limit));
    }

    if let Some(overrides) = overrides {
        walk_builder.overrides(overrides);
    }

    let mut matches_count: u32 = 0;
    let mut items: Vec<IFileMatch> = Vec::new();

    for entry in walk_builder.build() {
        if is_cancelled(cancelled) {
            return SearchInFilesOutcome::Cancelled;
        }

        if reached_match_limit(matches_count, max_matches) {
            break;
        }

        let entry = match entry {
            Ok(entry) => entry,
            Err(_) if is_cancelled(cancelled) => return SearchInFilesOutcome::Cancelled,
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

        if is_cancelled(cancelled) {
            return SearchInFilesOutcome::Cancelled;
        }

        let file = match File::open(&path) {
            Ok(file) => file,
            Err(_) if is_cancelled(cancelled) => return SearchInFilesOutcome::Cancelled,
            Err(error) => {
                let display = display_path(&path, &base_dir);
                return SearchInFilesOutcome::Failed(ISearchFailedResult {
                    elapsed_time: start.elapsed().as_millis() as u64,
                    error: format!("Failed to search '{}': {}", display, error),
                });
            }
        };

        let mut lines: Vec<LineMatch> = Vec::new();
        let mut sink = FileMatchSink {
            matcher: &matcher,
            lines: &mut lines,
            matches_count: &mut matches_count,
            max_matches,
            cancelled,
        };

        let reader = CancellableReader::new(file, cancelled);
        if let Err(error) = searcher.search_reader(&matcher, reader, &mut sink) {
            if is_cancelled(cancelled) {
                return SearchInFilesOutcome::Cancelled;
            }
            let display = display_path(&path, &base_dir);
            return SearchInFilesOutcome::Failed(ISearchFailedResult {
                elapsed_time: start.elapsed().as_millis() as u64,
                error: format!("Failed to search '{}': {}", display, error),
            });
        }

        if is_cancelled(cancelled) {
            return SearchInFilesOutcome::Cancelled;
        }

        if lines.is_empty() {
            continue;
        }

        let matches = flatten_line_matches(lines);
        if matches.is_empty() {
            continue;
        }

        items.push(IFileMatch {
            p: display_path(&path, &base_dir),
            matches,
        });
    }

    if is_cancelled(cancelled) {
        return SearchInFilesOutcome::Cancelled;
    }

    SearchInFilesOutcome::Completed(ISearchFileResult {
        elapsed_time: start.elapsed().as_millis() as u64,
        items,
        limit_reached: reached_match_limit(matches_count, max_matches),
    })
}

#[cfg(test)]
mod tests {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../__test__/rust/yoz/search/search_in_files_test.rs"
    ));
}
