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
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

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

/// Tells whether the bytes read through it are UTF-8 text, as replacement reads a file: the raw bytes, before the
/// searcher leaves out a byte order mark or transcodes UTF-16.
struct Utf8Reader<R> {
    inner: R,
    valid: bool,
    /// The bytes of a character that a read cut, completed by the next.
    cut: [u8; 4],
    cut_len: usize,
    eof: bool,
}

impl<R> Utf8Reader<R> {
    fn new(inner: R) -> Self {
        Self {
            inner,
            valid: true,
            cut: [0; 4],
            cut_len: 0,
            eof: false,
        }
    }

    /// Whether the bytes read so far are UTF-8 text; the whole file once read to the end.
    fn utf8(&self) -> bool {
        self.valid && self.cut_len == 0
    }

    fn check(&mut self, mut bytes: &[u8]) {
        if !self.valid {
            return;
        }
        if self.cut_len > 0 {
            /* The lead byte of a cut character is valid, so it gives the width. */
            let width = match self.cut[0] {
                0xC0..=0xDF => 2,
                0xE0..=0xEF => 3,
                _ => 4,
            };
            let take = (width - self.cut_len).min(bytes.len());
            self.cut[self.cut_len..self.cut_len + take].copy_from_slice(&bytes[..take]);
            self.cut_len += take;
            bytes = &bytes[take..];
            if self.cut_len < width {
                return;
            }
            self.cut_len = 0;
            if std::str::from_utf8(&self.cut[..width]).is_err() {
                self.valid = false;
                return;
            }
        }
        if let Err(error) = std::str::from_utf8(bytes) {
            if error.error_len().is_some() {
                self.valid = false;
                return;
            }
            let rest = &bytes[error.valid_up_to()..];
            self.cut[..rest.len()].copy_from_slice(rest);
            self.cut_len = rest.len();
        }
    }
}

impl<R: Read> Read for Utf8Reader<R> {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let read = self.inner.read(buffer)?;
        self.eof = read == 0 && !buffer.is_empty();
        self.check(&buffer[..read]);
        Ok(read)
    }
}

/// Seconds and nanoseconds since the Unix epoch, as `stat` gives them: the nanoseconds count up from the second, before
/// the epoch too.
fn unix_time(time: SystemTime) -> (i64, u32) {
    match time.duration_since(UNIX_EPOCH) {
        Ok(after) => (after.as_secs() as i64, after.subsec_nanos()),
        Err(error) => {
            let before = error.duration();
            match before.subsec_nanos() {
                0 => (-(before.as_secs() as i64), 0),
                nanos => (-(before.as_secs() as i64) - 1, 1_000_000_000 - nanos),
            }
        }
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

pub(crate) fn build_overrides(
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
    /* `$` matches before `\r\n` as the replace matcher does; without a line terminator, patterns may span lines. */
    builder.crlf(true).line_terminator(None);
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
        let block = mat.bytes_range_in_buffer();

        let mut match_ranges: Vec<MatchRange> = Vec::new();
        let mut continue_search = true;

        /* The block holds the lines of its matches, which start and end in it. Matching the block alone would take its
         * end for the end of the text, where `$` holds and `\s*$` takes the line break; the buffer around it gives each
         * match the text after it, as replacement sees it. */
        let result = self
            .matcher
            .find_iter_at(mat.buffer(), block.start, |range| {
                if range.start() >= block.end {
                    return false;
                }
                if is_cancelled(self.cancelled) {
                    continue_search = false;
                    return false;
                }

                if reached_match_limit(*self.matches_count, self.max_matches) {
                    continue_search = false;
                    return false;
                }

                match_ranges.push(MatchRange {
                    start: range.start() - block.start,
                    end: range.end() - block.start,
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
            /* A file the search cannot open, as one without read permission or removed since the walk listed it, is
            left out like the entries the walk fails on, so the other files still return their matches. */
            Err(_) => continue,
        };

        /* Taken from the file opened, before reading it: a change during the search shows as one after it. */
        let (size, (mtime_sec, mtime_nsec)) = match file.metadata() {
            Ok(metadata) => (
                metadata.len(),
                metadata.modified().map_or((0, 0), unix_time),
            ),
            Err(_) => (0, (0, 0)),
        };

        let matches_before = matches_count;
        let mut lines: Vec<LineMatch> = Vec::new();
        let mut sink = FileMatchSink {
            matcher: &matcher,
            lines: &mut lines,
            matches_count: &mut matches_count,
            max_matches,
            cancelled,
        };

        let mut reader = Utf8Reader::new(CancellableReader::new(file, cancelled));
        let mut searched = searcher.search_reader(&matcher, &mut reader, &mut sink);
        /* A search that stops early, as at the match limit, leaves the rest of the file to tell whether it is UTF-8. */
        if searched.is_ok() && !lines.is_empty() && !reader.eof {
            searched = io::copy(&mut reader, &mut io::sink()).map(drop);
        }
        if searched.is_err() {
            if is_cancelled(cancelled) {
                return SearchInFilesOutcome::Cancelled;
            }
            /* A read that fails part way leaves the file out, with the matches it had already counted. */
            matches_count = matches_before;
            continue;
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
            utf8: reader.utf8(),
            size,
            mtime_sec,
            mtime_nsec,
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
    use super::*;
    use crate::test_support::TempDir;
    use std::collections::HashSet;
    use std::fs;
    use std::path::PathBuf;

    fn fixtures_dir() -> String {
        let manifest_dir =
            std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not defined");
        let path = std::path::Path::new(&manifest_dir).join("../../__test__/fixtures/yoz");
        path.to_string_lossy().to_string()
    }

    fn setup_gitignore_workspace() -> TempDir {
        let workspace = TempDir::new();
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

    fn setup_nested_gitignore_workspace() -> (TempDir, PathBuf) {
        let workspace = TempDir::new();
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

    fn setup_pattern_workspace() -> TempDir {
        let workspace = TempDir::new();
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
    fn t_search_in_files_end_anchor_matches_lf_and_crlf_lines() {
        let options = ISearchInFilesOptions {
            cwd: Some(fixtures_dir()),
            flag_case_sensitive: true,
            flag_gitignore: true,
            flag_regex: true,
            max_filesize: Some("1M".to_string()),
            max_matches: Some(300),
            search_pattern: r#"Hello, (world|世界)!$"#.to_string(),
            search_paths: ".".to_string(),
            include_patterns: "*.txt".to_string(),
            exclude_patterns: "c.txt".to_string(),
            specified_filepath: None,
        };

        let filenames: HashSet<_> = search_in_files(&options)
            .expect("expected successful search")
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

        assert!(filenames.contains("a.txt"), "LF lines end at `$`");
        assert!(filenames.contains("b.txt"), "CRLF lines end at `$`");
    }

    #[test]
    fn t_search_in_files_matches_with_the_text_after_the_lines_of_a_match() {
        let dir = TempDir::new();
        fs::write(dir.path().join("a.txt"), "foo  \nbar\nfoo \n\nbaz\n").unwrap();
        let options = ISearchInFilesOptions {
            cwd: Some(dir.path().to_string_lossy().to_string()),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: true,
            max_filesize: Some("1M".to_string()),
            max_matches: None,
            search_pattern: r"foo\s*$".to_string(),
            search_paths: ".".to_string(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
            specified_filepath: None,
        };

        let result = search_in_files(&options).expect("expected successful search");
        let ranges: Vec<_> = result.items[0]
            .matches
            .iter()
            .map(|m| (m.ox, m.oy))
            .collect();
        /* As replacement matches: the spaces alone, then the spaces and the break before the empty line. */
        assert_eq!(ranges, [(0, 4), (10, 14)]);
        let expected = crate::replace::replace_text_preview(
            "foo  \nbar\nfoo \n\nbaz\n",
            r"foo\s*$",
            "#",
            false,
            true,
            true,
        )
        .unwrap();
        assert_eq!(expected, "#\nbar\n#\nbaz\n");
    }

    #[test]
    fn t_search_in_files_tells_which_files_are_utf8_text() {
        let dir = TempDir::new();
        let far = "x\n".repeat(100_000);
        fs::write(dir.path().join("a.txt"), "café foo\n").unwrap();
        fs::write(dir.path().join("b.txt"), b"\xEF\xBB\xBFcaf\xC3\xA9 foo\n").unwrap();
        fs::write(dir.path().join("c.txt"), b"caf\xE9 foo\n").unwrap();
        fs::write(
            dir.path().join("d.txt"),
            [b"foo\n", far.as_bytes(), b"\xE9"].concat(),
        )
        .unwrap();
        let utf16: Vec<u8> = "café foo\n"
            .encode_utf16()
            .flat_map(u16::to_le_bytes)
            .collect();
        fs::write(
            dir.path().join("e.txt"),
            [&[0xFF, 0xFE], &utf16[..]].concat(),
        )
        .unwrap();
        let options = ISearchInFilesOptions {
            cwd: Some(dir.path().to_string_lossy().to_string()),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: false,
            max_filesize: Some("1M".to_string()),
            max_matches: None,
            search_pattern: "foo".to_string(),
            search_paths: ".".to_string(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
            specified_filepath: None,
        };

        let result = search_in_files(&options).expect("expected successful search");
        let flags: Vec<_> = result
            .items
            .iter()
            .map(|item| (item.p.as_str(), item.utf8))
            .collect();
        /* A byte order mark aside; a byte outside UTF-8 far after the match; UTF-16, which search transcodes. */
        assert_eq!(
            flags,
            [
                ("a.txt", true),
                ("b.txt", true),
                ("c.txt", false),
                ("d.txt", false),
                ("e.txt", false)
            ]
        );

        /* The search stops in d.txt at the limit; the rest of the file still tells. */
        let options = ISearchInFilesOptions {
            max_matches: Some(4),
            ..options
        };
        let result = search_in_files(&options).expect("expected successful search");
        assert!(result.limit_reached);
        let last = result.items.last().unwrap();
        assert_eq!((last.p.as_str(), last.utf8), ("d.txt", false));
    }

    #[test]
    fn t_search_in_files_records_the_size_and_modification_time_of_each_file() {
        let dir = TempDir::new();
        let path = dir.path().join("a.txt");
        fs::write(&path, "foo\n").unwrap();
        let options = ISearchInFilesOptions {
            cwd: Some(dir.path().to_string_lossy().to_string()),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: false,
            max_filesize: Some("1M".to_string()),
            max_matches: None,
            search_pattern: "foo".to_string(),
            search_paths: ".".to_string(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
            specified_filepath: None,
        };

        let result = search_in_files(&options).expect("expected successful search");
        let item = &result.items[0];
        let (mtime_sec, mtime_nsec) = unix_time(fs::metadata(&path).unwrap().modified().unwrap());
        assert_eq!(
            (item.size, item.mtime_sec, item.mtime_nsec),
            (4, mtime_sec, mtime_nsec)
        );
    }

    #[cfg(unix)]
    #[test]
    fn t_search_in_files_leaves_out_a_file_it_cannot_open() {
        use std::os::unix::fs::PermissionsExt;

        let dir = TempDir::new();
        fs::write(dir.path().join("a.txt"), "foo\n").unwrap();
        let locked = dir.path().join("b.txt");
        fs::write(&locked, "foo\n").unwrap();
        fs::set_permissions(&locked, fs::Permissions::from_mode(0o000)).unwrap();
        if File::open(&locked).is_ok() {
            /* Permissions do not bind a privileged user, who has no file the search cannot open. */
            return;
        }
        let options = ISearchInFilesOptions {
            cwd: Some(dir.path().to_string_lossy().to_string()),
            flag_case_sensitive: true,
            flag_gitignore: false,
            flag_regex: false,
            max_filesize: None,
            max_matches: None,
            search_pattern: "foo".to_string(),
            search_paths: ".".to_string(),
            include_patterns: String::new(),
            exclude_patterns: String::new(),
            specified_filepath: None,
        };

        let result = search_in_files(&options).expect("expected successful search");
        let paths: Vec<&str> = result.items.iter().map(|item| item.p.as_str()).collect();
        assert_eq!(paths, vec!["a.txt"]);
    }

    #[test]
    fn t_unix_time_counts_the_nanoseconds_up_from_the_second() {
        use std::time::Duration;
        assert_eq!(unix_time(UNIX_EPOCH + Duration::new(5, 250)), (5, 250));
        assert_eq!(unix_time(UNIX_EPOCH - Duration::new(5, 0)), (-5, 0));
        /* 5.00000025 s before the epoch is 999999750 ns after the start of second -6. */
        assert_eq!(
            unix_time(UNIX_EPOCH - Duration::new(5, 250)),
            (-6, 999_999_750)
        );
    }

    #[test]
    fn t_utf8_reader_completes_characters_cut_by_reads() {
        /* One byte a read cuts every character that takes more. */
        struct ByteReader<'bytes>(&'bytes [u8]);

        impl Read for ByteReader<'_> {
            fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
                let Some((&byte, rest)) = self.0.split_first() else {
                    return Ok(0);
                };
                buffer[0] = byte;
                self.0 = rest;
                Ok(1)
            }
        }

        let utf8 = |bytes: &[u8]| {
            let mut reader = Utf8Reader::new(ByteReader(bytes));
            io::copy(&mut reader, &mut io::sink()).unwrap();
            reader.utf8()
        };
        assert!(utf8("aé中😀b".as_bytes()));
        assert!(utf8(b"\xEF\xBB\xBFbom"));
        assert!(!utf8(b"caf\xE9"), "Latin-1");
        assert!(!utf8(b"\xE2ab"), "a lead byte without its continuation");
        assert!(!utf8(b"\xED\xA0\x80"), "a surrogate");
        assert!(!utf8(b"a\xF0\x9F\x98"), "a character cut by the end");
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

        let files =
            collect_result_paths(search_in_files(&options).expect("expected search success"));
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

        let files =
            collect_result_paths(search_in_files(&options).expect("expected search success"));
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

        let files =
            collect_result_paths(search_in_files(&options).expect("expected search success"));
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

        let files =
            collect_result_paths(search_in_files(&options).expect("expected search success"));
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

        let files =
            collect_result_paths(search_in_files(&options).expect("expected search success"));
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

        let files =
            collect_result_paths(search_in_files(&options).expect("expected search success"));
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

        let outcome =
            search_in_files_cancellable(&options, workspace.path().to_path_buf(), &cancelled);
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
}
