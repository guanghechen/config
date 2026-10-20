//! A candidate set kept on the native side: uploaded once, then queried per keystroke.

use super::algo::{Scratch, Text};
use super::class::{Scheme, classes};
use super::matcher::{self, Options};
use super::pattern::{self, CaseMode, Pattern};
use super::text;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{Duration, Instant};

/** Time a query runs on the calling thread alone before workers join. */
const SPAWN_AFTER: Duration = Duration::from_micros(100);
/** Candidates per unit of work: small enough that a chunk left to an efficiency core does not delay the
query, and that the calling thread notices `SPAWN_AFTER` soon. */
const CHUNK: usize = 256;
const CACHE_ENTRIES: usize = 16;

#[derive(Clone, Copy)]
struct Span {
    offset: u32,
    len: u32,
    /** Offset into `chars` for items that are not ASCII, `u32::MAX` otherwise. */
    chars: u32,
    /** Number of characters. */
    count: u32,
    /** fzf's TrimLength, the length tiebreak. */
    trim_len: u16,
    /** Character index of the last `/` or `\`, plus one; zero when there is none. */
    delimiter: u16,
    /** Case-folded ASCII characters present; all bits for text that is not ASCII. */
    mask: u128,
}

struct Cached {
    key: String,
    fuzzy: bool,
    case: CaseMode,
    matched: Vec<u32>,
}

#[derive(Clone, Copy, Debug)]
pub struct Query<'a> {
    pub pattern: &'a str,
    pub fuzzy: bool,
    pub case: CaseMode,
    /** Score and sort matches; otherwise only decide membership, in item order. */
    pub rank: bool,
    /** Points added at weight 100; weights are 0..=100 per item. */
    pub weight: i32,
    /** Worker threads; zero picks a default. */
    pub threads: usize,
}

#[derive(Debug, Default)]
pub struct Ranked {
    /** Zero-based item indices, best first when ranked. */
    pub indices: Vec<u32>,
    /** Final scores, weights included; empty when not ranked. */
    pub scores: Vec<i32>,
    /** Candidates examined after narrowing. */
    pub examined: usize,
    /** The parsed query, for highlighting results. */
    pattern: Option<Pattern>,
}

/** Bits of the item index in a packed match. */
const INDEX_BITS: u32 = 24;
/** Items a corpus holds at most. */
pub const MAX_ITEMS: usize = 1 << INDEX_BITS;
/** Key bytes above the index: score, pathname and length. */
const KEY_BYTES: usize = 5;

type Counts = [[u32; 256]; KEY_BYTES];

/// A ranked match packed so that ascending order is fzf's order: score descending, saturated to 16 bits,
/// then pathname, saturated to 8 bits as basenames rarely exceed 255 characters, then length and index.
#[inline]
fn pack(score: i32, pathname: u16, length: u16, index: u32) -> u64 {
    let descending = u16::MAX - score.clamp(0, u16::MAX as i32) as u16;
    (descending as u64) << 48
        | (pathname.min(255) as u64) << 40
        | (length as u64) << INDEX_BITS
        | index as u64
}

#[inline]
fn unpack(hit: u64) -> (i32, u32) {
    (
        (u16::MAX - (hit >> 48) as u16) as i32,
        (hit & (MAX_ITEMS as u64 - 1)) as u32,
    )
}

#[inline]
fn count(counts: &mut Counts, hit: u64) {
    let key = hit >> INDEX_BITS;
    for (byte, count) in counts.iter_mut().enumerate() {
        count[(key >> (byte * 8)) as u8 as usize] += 1;
    }
}

/// Sorts packed matches that arrive in index order: a stable LSD radix sort over the key bytes, skipping
/// bytes that every match shares; `counts` are the byte histograms. Comparison sorts cost several times
/// more at 100k matches.
fn radix_sort(hits: &mut Vec<u64>, counts: &Counts) {
    let mut buffer: Vec<u64> = Vec::new();
    for (byte, count) in counts.iter().enumerate() {
        if count.iter().any(|&count| count as usize == hits.len()) {
            continue;
        }
        let mut offsets = [0usize; 256];
        let mut sum = 0;
        for (offset, &count) in offsets.iter_mut().zip(count) {
            *offset = sum;
            sum += count as usize;
        }
        buffer.resize(hits.len(), 0);
        let shift = INDEX_BITS as usize + byte * 8;
        for &hit in hits.iter() {
            let digit = (hit >> shift) as u8 as usize;
            buffer[offsets[digit]] = hit;
            offsets[digit] += 1;
        }
        std::mem::swap(hits, &mut buffer);
    }
}

pub struct Corpus {
    scheme: Scheme,
    bytes: Vec<u8>,
    chars: Vec<char>,
    spans: Vec<Span>,
    weights: Vec<u8>,
    cache: Vec<Cached>,
}

fn clamp16(value: usize) -> u16 {
    value.min(u16::MAX as usize) as u16
}

/// Worker threads for a query that does not choose: matching scales to every core of an M-series Pro.
pub(crate) fn default_threads() -> usize {
    std::thread::available_parallelism()
        .map_or(1, |count| count.get())
        .min(16)
}

/// Workers serve a keystroke; without this macOS may keep them on efficiency cores.
fn prefer_performance_cores() {
    #[cfg(target_os = "macos")]
    // SAFETY: sets the QoS class of the calling thread only.
    unsafe {
        libc::pthread_set_qos_class_self_np(libc::qos_class_t::QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

impl Corpus {
    pub fn new(scheme: Scheme) -> Self {
        Self {
            scheme,
            bytes: Vec::new(),
            chars: Vec::new(),
            spans: Vec::new(),
            weights: Vec::new(),
            cache: Vec::new(),
        }
    }

    pub fn len(&self) -> usize {
        self.spans.len()
    }

    pub fn is_empty(&self) -> bool {
        self.spans.is_empty()
    }

    /// Forgets earlier results, so the next query scans every item.
    #[cfg(test)]
    pub(crate) fn clear_cache(&mut self) {
        self.cache.clear();
    }

    pub fn append<S: AsRef<str>>(&mut self, items: &[S]) -> Result<(), String> {
        if self.spans.len() + items.len() > MAX_ITEMS {
            return Err(format!("a corpus holds at most {MAX_ITEMS} items"));
        }
        self.cache.clear();
        for item in items {
            let item = item.as_ref();
            let offset = self.bytes.len() as u32;
            self.bytes.extend_from_slice(item.as_bytes());
            let ascii = item.is_ascii();
            let chars = if ascii {
                u32::MAX
            } else {
                let start = self.chars.len() as u32;
                self.chars.extend(item.chars());
                start
            };
            let count = if ascii {
                item.len()
            } else {
                item.chars().count()
            } as u32;
            let mut span = Span {
                offset,
                len: item.len() as u32,
                chars,
                count,
                trim_len: 0,
                delimiter: 0,
                mask: u128::MAX,
            };
            let text = self.text_of(&span);
            span.trim_len = clamp16(text.trim_len());
            span.delimiter = clamp16(
                (0..text.len())
                    .rev()
                    .find(|&index| matches!(text.get(index), '/' | '\\'))
                    .map_or(0, |at| at + 1),
            );
            if ascii {
                span.mask = item.bytes().fold(0u128, |mask, byte| {
                    mask | 1 << (byte.to_ascii_lowercase() as u32)
                });
            }
            self.spans.push(span);
            self.weights.push(0);
        }
        Ok(())
    }

    /// Weights 0..=100 per item, such as frecency.
    pub fn set_weights(&mut self, weights: &[u8]) -> Result<(), String> {
        if weights.len() != self.spans.len() {
            return Err(format!(
                "expected {} weights, got {}",
                self.spans.len(),
                weights.len()
            ));
        }
        self.weights.clear();
        self.weights
            .extend(weights.iter().map(|&weight| weight.min(100)));
        Ok(())
    }

    pub fn text(&self, index: usize) -> &str {
        let span = &self.spans[index];
        // SAFETY: spans cover whole strings appended as `&str`.
        unsafe {
            std::str::from_utf8_unchecked(
                &self.bytes[span.offset as usize..(span.offset + span.len) as usize],
            )
        }
    }

    fn text_of(&self, span: &Span) -> Text<'_> {
        if span.chars == u32::MAX {
            Text::Bytes(&self.bytes[span.offset as usize..(span.offset + span.len) as usize])
        } else {
            let start = span.chars as usize;
            Text::Chars(&self.chars[start..start + span.count as usize])
        }
    }

    fn bonus(&self, query: &Query, index: u32) -> i32 {
        (query.weight * self.weights[index as usize] as i32 + 50) / 100
    }

    fn options(&self, with_pos: bool) -> Options {
        Options {
            forward: self.scheme != Scheme::Path,
            with_pos,
            fallback: true,
        }
    }

    /// Smallest cached result that contains every match of `pattern`: as in fzf, results for a prefix or
    /// suffix of the pattern's key, since typing more only removes matches.
    fn narrowed(&self, pattern: &Pattern, query: &Query) -> Option<&[u32]> {
        if pattern.key.is_empty() {
            return None;
        }
        self.cache
            .iter()
            .filter(|cached| {
                cached.fuzzy == query.fuzzy
                    && cached.case == query.case
                    && (pattern.key.starts_with(&cached.key) || pattern.key.ends_with(&cached.key))
            })
            .min_by_key(|cached| cached.matched.len())
            .map(|cached| cached.matched.as_slice())
    }

    pub fn query(&mut self, query: &Query) -> Ranked {
        let started = Instant::now();
        let pattern = pattern::parse(query.pattern, query.fuzzy, query.case);
        if pattern.sets.is_empty() {
            let mut ranked = Ranked {
                examined: self.spans.len(),
                ..Ranked::default()
            };
            ranked.indices = (0..self.spans.len() as u32).collect();
            if query.rank && query.weight > 0 {
                ranked
                    .indices
                    .sort_by_key(|&index| std::cmp::Reverse(self.weights[index as usize]));
                ranked.scores = ranked
                    .indices
                    .iter()
                    .map(|&index| self.bonus(query, index))
                    .collect();
            }
            return ranked;
        }

        let candidates: Option<Vec<u32>> = self.narrowed(&pattern, query).map(<[u32]>::to_vec);
        let examined = candidates.as_ref().map_or(self.spans.len(), Vec::len);
        // An item lacking a character that a single-term set needs cannot match.
        let required = pattern
            .sets
            .iter()
            .filter(|set| set.len() == 1 && !set[0].inverse)
            .filter_map(|set| set[0].ascii_mask())
            .fold(0u128, |mask, term| mask | term);
        let rank = query.rank && pattern.sortable;
        // The pathname tiebreak needs exact starts.
        let with_pos = rank && self.scheme == Scheme::Path;
        let threads = match query.threads {
            0 => default_threads(),
            count => count,
        };

        // Matches of `from..to` in index order, packed and counted when ranking.
        let scan = |from: usize,
                    to: usize,
                    scratch: &mut Scratch,
                    hits: &mut Vec<u64>,
                    counts: &mut Counts| {
            let classes = classes(self.scheme);
            let options = self.options(with_pos);
            for at in from..to {
                let index = candidates
                    .as_ref()
                    .map_or(at as u32, |candidates| candidates[at]);
                let span = &self.spans[index as usize];
                if span.mask & required != required {
                    continue;
                }
                let text = self.text_of(span);
                if !rank {
                    if matcher::is_match(classes, &pattern, text, &options, scratch) {
                        hits.push(index as u64);
                    }
                    continue;
                }
                let Some(found) =
                    matcher::match_item(classes, &pattern, text, &options, scratch, None)
                else {
                    continue;
                };
                let pathname = match found.begin {
                    Some(begin)
                        if self.scheme == Scheme::Path && span.delimiter as usize <= begin + 1 =>
                    {
                        clamp16(begin + 1 - span.delimiter as usize)
                    }
                    _ => u16::MAX,
                };
                let hit = pack(
                    found.score + self.bonus(query, index),
                    pathname,
                    span.trim_len,
                    index,
                );
                count(counts, hit);
                hits.push(hit);
            }
        };

        // The calling thread starts alone; workers join only when the query outlasts `SPAWN_AFTER`, so
        // cheap queries never pay for threads.
        let mut hits: Vec<u64> = Vec::new();
        let mut counts: Counts = [[0; 256]; KEY_BYTES];
        let mut scratch = Scratch::default();
        let cursor = AtomicUsize::new(0);
        let chunks = examined.div_ceil(CHUNK);
        let deadline = (threads > 1).then(|| started + SPAWN_AFTER);
        let mut finished = true;
        loop {
            if deadline.is_some_and(|deadline| Instant::now() >= deadline) {
                finished = false;
                break;
            }
            let chunk = cursor.fetch_add(1, Ordering::Relaxed);
            if chunk >= chunks {
                break;
            }
            let from = chunk * CHUNK;
            scan(
                from,
                (from + CHUNK).min(examined),
                &mut scratch,
                &mut hits,
                &mut counts,
            );
        }
        if !finished {
            let worker = |scratch: &mut Scratch, counts: &mut Counts| {
                let mut parts = Vec::new();
                loop {
                    let chunk = cursor.fetch_add(1, Ordering::Relaxed);
                    if chunk >= chunks {
                        break parts;
                    }
                    let from = chunk * CHUNK;
                    let mut part = Vec::new();
                    scan(
                        from,
                        (from + CHUNK).min(examined),
                        scratch,
                        &mut part,
                        counts,
                    );
                    parts.push((chunk, part));
                }
            };
            let remaining = chunks.saturating_sub(cursor.load(Ordering::Relaxed));
            let mut parts = std::thread::scope(|scope| {
                let workers: Vec<_> = (1..threads.min(remaining))
                    .map(|_| {
                        scope.spawn(|| {
                            prefer_performance_cores();
                            let mut counts: Counts = [[0; 256]; KEY_BYTES];
                            (worker(&mut Scratch::default(), &mut counts), counts)
                        })
                    })
                    .collect();
                let mut parts = worker(&mut scratch, &mut counts);
                for handle in workers {
                    let (part, worker_counts) = handle.join().expect("fuzzy worker");
                    parts.extend(part);
                    for (total, add) in counts
                        .iter_mut()
                        .flatten()
                        .zip(worker_counts.iter().flatten())
                    {
                        *total += add;
                    }
                }
                parts
            });
            parts.sort_unstable_by_key(|&(chunk, _)| chunk);
            hits.reserve(parts.iter().map(|(_, part)| part.len()).sum());
            for (_, part) in parts {
                hits.extend(part);
            }
        }

        // Before sorting, matches are in index order, as the cache keeps them.
        let matched: Option<Vec<u32>> = pattern
            .cacheable
            .then(|| hits.iter().map(|&hit| unpack(hit).1).collect());
        if rank {
            radix_sort(&mut hits, &counts);
        }
        let (mut indices, scores): (Vec<u32>, Vec<i32>) = if rank {
            hits.iter()
                .map(|&hit| (unpack(hit).1, unpack(hit).0))
                .unzip()
        } else {
            (hits.iter().map(|&hit| hit as u32).collect(), Vec::new())
        };
        if let Some(matched) = matched {
            self.cache.retain(|cached| {
                cached.key != pattern.key
                    || cached.fuzzy != query.fuzzy
                    || cached.case != query.case
            });
            if self.cache.len() == CACHE_ENTRIES {
                self.cache.remove(0);
            }
            self.cache.push(Cached {
                key: pattern.key.clone(),
                fuzzy: query.fuzzy,
                case: query.case,
                matched,
            });
        }
        let scores = if !rank && query.rank && query.weight > 0 {
            // Only inverse terms: fzf keeps item order; weights still order the matches.
            indices.sort_by_key(|&index| std::cmp::Reverse(self.weights[index as usize]));
            indices
                .iter()
                .map(|&index| self.bonus(query, index))
                .collect()
        } else {
            scores
        };
        Ranked {
            indices,
            scores,
            examined,
            pattern: Some(pattern),
        }
    }

    /// Byte ranges of item `index` that `ranked`'s query matches, merged into runs, for highlighting one row.
    pub fn positions(&self, index: usize, ranked: &Ranked) -> Vec<(usize, usize)> {
        let Some(pattern) = ranked.pattern.as_ref() else {
            return Vec::new();
        };
        let span = &self.spans[index];
        let mut scratch = Scratch::default();
        let mut positions = Vec::new();
        let options = self.options(true);
        let text = self.text_of(span);
        if matcher::match_item(
            classes(self.scheme),
            pattern,
            text,
            &options,
            &mut scratch,
            Some(&mut positions),
        )
        .is_none()
        {
            return Vec::new();
        }
        text::byte_ranges(self.text(index), positions)
    }
}
