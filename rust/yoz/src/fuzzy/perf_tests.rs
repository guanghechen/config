//! Release-mode probes for the fuzzy benchmark suite (level L1, no FFI).
//!
//! `script/benchmark/fuzzy.mjs --level rust` runs them; by hand:
//! `YOZ_FUZZY_BENCH_CORPUS=<dir> cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib
//! fuzzy::perf_tests -- --ignored --nocapture --test-threads=1`
//! where `<dir>` was written by `script/benchmark/fuzzy-corpus.mjs`.
//!
//! Environment:
//! - `YOZ_FUZZY_BENCH_CORPORA`: comma-separated corpus names (default: every corpus below 1M items).
//! - `YOZ_FUZZY_BENCH_PROBES`: comma-separated probe names (default: all but the `sweep_t*` thread sweep).
//! - `YOZ_FUZZY_BENCH_SAMPLES`: timed passes over every query (default: 5).
//! - `YOZ_FUZZY_BENCH_SEQUENCES`: keep every n-th typing sequence, for the largest corpora (default: 1).
//! - `YOZ_FUZZY_BENCH_OUT`: JSON Lines output file (default: stdout lines prefixed `FUZZY_BENCH_JSON `).

use super::corpus::default_threads;
use super::{CaseMode, Corpus as FuzzyCorpus, Query as FuzzyQuery, Scheme};
use crate::completion::fuzzy::Matcher as CompletionMatcher;
use crate::search::search_in_lines;
use crate::ux::treeview::DisplayOptions;
use crate::ux::treeview::matching::Matcher as TreeviewMatcher;
use std::collections::HashSet;
use std::fmt::Write as _;
use std::fs::{self, OpenOptions};
use std::hint::black_box;
use std::io::Write as _;
use std::path::{Path, PathBuf};
use std::time::Instant;

const SCHEMA: &str = "fuzzy-l1/1";
/** Highlight ranges a viewport needs per query; ranges beyond it are never drawn. */
const VISIBLE_ROWS: usize = 50;

struct Query {
    sequence: u32,
    kind: String,
    /** Zero-based index of the item the typing sequence aims at; `u32::MAX` for no-match sequences. */
    target: u32,
    step: u32,
    text: String,
}

struct Corpus {
    name: String,
    kind: String,
    scheme: String,
    sha256: String,
    items: Vec<String>,
    lower: Vec<String>,
    queries: Vec<Query>,
}

fn env(name: &str) -> Option<String> {
    std::env::var(name).ok().filter(|value| !value.is_empty())
}

fn load(directory: &Path, name: &str, every: u32) -> Corpus {
    let manifest = fs::read_to_string(directory.join("manifest.tsv")).expect("corpus manifest.tsv");
    let entry: Vec<&str> = manifest
        .lines()
        .map(|line| line.split('\t').collect::<Vec<_>>())
        .find(|fields| fields[0] == name)
        .unwrap_or_else(|| panic!("corpus {name} is not in the manifest"));
    let items: Vec<String> = fs::read_to_string(directory.join(format!("{name}.txt")))
        .expect("corpus items")
        .lines()
        .map(str::to_owned)
        .collect();
    let queries = fs::read_to_string(directory.join("queries").join(format!("{name}.tsv")))
        .expect("corpus queries")
        .lines()
        .filter_map(|line| {
            let fields: Vec<&str> = line.split('\t').collect();
            let sequence: u32 = fields[0].parse().ok()?;
            (sequence - 1).is_multiple_of(every).then(|| Query {
                sequence,
                kind: fields[1].to_owned(),
                target: u32::try_from(fields[2].parse::<i64>().expect("query target"))
                    .unwrap_or(u32::MAX),
                step: fields[3].parse().expect("query step"),
                text: fields[4].to_owned(),
            })
        })
        .collect();
    Corpus {
        name: name.to_owned(),
        kind: entry[1].to_owned(),
        scheme: entry[2].to_owned(),
        sha256: entry[4].to_owned(),
        lower: items.iter().map(|item| item.to_lowercase()).collect(),
        items,
        queries,
    }
}

/// One matcher under test; `run` returns how many items matched.
trait Probe {
    fn name(&self) -> &'static str;
    fn threads(&self) -> usize {
        1
    }
    fn prepare(&mut self, corpus: &Corpus) -> f64;
    fn run(&mut self, corpus: &Corpus, query: &Query) -> usize;
}

/// The list composer's path: lowercased lines, `search_in_lines` with fuzzy fallback, unique lines.
struct SearchLines;

impl Probe for SearchLines {
    fn name(&self) -> &'static str {
        "search_in_lines"
    }

    fn prepare(&mut self, _corpus: &Corpus) -> f64 {
        0.0
    }

    fn run(&mut self, corpus: &Corpus, query: &Query) -> usize {
        let pattern = query.text.to_lowercase();
        match search_in_lines(&pattern, &corpus.lower, true, false, false) {
            Ok(result) => result
                .lines
                .iter()
                .map(|line| line.lnum)
                .collect::<HashSet<_>>()
                .len(),
            Err(_) => 0,
        }
    }
}

/// Explorer's native display filter: escaped or fuzzy regex per query, ranges for visible rows.
struct TreeviewRegex;

impl Probe for TreeviewRegex {
    fn name(&self) -> &'static str {
        "treeview_regex"
    }

    fn prepare(&mut self, _corpus: &Corpus) -> f64 {
        0.0
    }

    fn run(&mut self, corpus: &Corpus, query: &Query) -> usize {
        let display = DisplayOptions {
            pattern: query.text.as_str().into(),
            fuzzy: true,
            ..DisplayOptions::default()
        };
        let Ok(matcher) = TreeviewMatcher::new(&display) else {
            return 0;
        };
        let mut matched = 0;
        for item in &corpus.items {
            if matcher.is_match(item) {
                if matched < VISIBLE_ROWS {
                    black_box(matcher.ranges(item, 8192));
                }
                matched += 1;
            }
        }
        matched
    }
}

/// The completion matcher over a persistent candidate set.
#[derive(Default)]
struct Completion {
    matcher: Option<CompletionMatcher>,
}

impl Probe for Completion {
    fn name(&self) -> &'static str {
        "completion"
    }

    fn prepare(&mut self, corpus: &Corpus) -> f64 {
        let started = Instant::now();
        self.matcher = Some(CompletionMatcher::new(&corpus.items));
        started.elapsed().as_secs_f64() * 1000.0
    }

    fn run(&mut self, _corpus: &Corpus, query: &Query) -> usize {
        self.matcher
            .as_ref()
            .expect("prepared completion matcher")
            .query(&query.text)
            .0
            .len()
    }
}

/// The fzf-style corpus: a query per keystroke, then highlight ranges for the visible rows.
struct Fuzzy {
    name: &'static str,
    rank: bool,
    /** Keep results across a typing sequence, so each keystroke narrows the previous matches. */
    narrow: bool,
    threads: usize,
    corpus: Option<FuzzyCorpus>,
}

impl Fuzzy {
    fn new(name: &'static str, rank: bool, narrow: bool, threads: usize) -> Self {
        Self {
            name,
            rank,
            narrow,
            threads,
            corpus: None,
        }
    }
}

impl Probe for Fuzzy {
    fn name(&self) -> &'static str {
        self.name
    }

    fn threads(&self) -> usize {
        if self.threads == 0 {
            default_threads()
        } else {
            self.threads
        }
    }

    fn prepare(&mut self, corpus: &Corpus) -> f64 {
        let started = Instant::now();
        let mut fuzzy = FuzzyCorpus::new(if corpus.scheme == "path" {
            Scheme::Path
        } else {
            Scheme::Default
        });
        fuzzy.append(&corpus.items).unwrap();
        self.corpus = Some(fuzzy);
        started.elapsed().as_secs_f64() * 1000.0
    }

    fn run(&mut self, _corpus: &Corpus, query: &Query) -> usize {
        let fuzzy = self.corpus.as_mut().expect("prepared fuzzy corpus");
        if !self.narrow || query.step == 1 {
            fuzzy.clear_cache();
        }
        let request = FuzzyQuery {
            pattern: &query.text,
            fuzzy: true,
            case: CaseMode::Smart,
            rank: self.rank,
            weight: 0,
            threads: self.threads,
        };
        let ranked = fuzzy.query(&request);
        for &index in ranked.indices.iter().take(VISIBLE_ROWS) {
            black_box(fuzzy.positions(index as usize, &ranked));
        }
        ranked.indices.len()
    }
}

fn probes(selected: Option<&str>) -> Vec<Box<dyn Probe>> {
    let all: Vec<Box<dyn Probe>> = vec![
        Box::new(SearchLines),
        Box::new(TreeviewRegex),
        Box::new(Completion::default()),
        Box::new(Fuzzy::new("fuzzy_rank", true, false, 0)),
        Box::new(Fuzzy::new("fuzzy_typed", true, true, 0)),
        Box::new(Fuzzy::new("fuzzy_filter", false, false, 0)),
        Box::new(Fuzzy::new("sweep_t1", true, false, 1)),
        Box::new(Fuzzy::new("sweep_t2", true, false, 2)),
        Box::new(Fuzzy::new("sweep_t4", true, false, 4)),
        Box::new(Fuzzy::new("sweep_t6", true, false, 6)),
        Box::new(Fuzzy::new("sweep_t8", true, false, 8)),
        Box::new(Fuzzy::new("sweep_t12", true, false, 12)),
        Box::new(Fuzzy::new("sweep_t16", true, false, 16)),
    ];
    match selected {
        None => all
            .into_iter()
            .filter(|probe| !probe.name().starts_with("sweep_"))
            .collect(),
        Some(names) => {
            let names: Vec<&str> = names.split(',').collect();
            all.into_iter()
                .filter(|probe| names.contains(&probe.name()))
                .collect()
        }
    }
}

fn escape(text: &str) -> String {
    let mut out = String::with_capacity(text.len() + 2);
    out.push('"');
    for ch in text.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            ch if (ch as u32) < 0x20 => {
                let _ = write!(out, "\\u{:04x}", ch as u32);
            }
            ch => out.push(ch),
        }
    }
    out.push('"');
    out
}

fn median(values: &mut [u64]) -> u64 {
    values.sort_unstable();
    let middle = values.len() / 2;
    if values.len() % 2 == 1 {
        values[middle]
    } else {
        (values[middle - 1] + values[middle]) / 2
    }
}

/// Asks macOS for performance cores; a default-QoS process can land on efficiency cores and run slower.
fn prefer_performance_cores() -> bool {
    #[cfg(target_os = "macos")]
    {
        // SAFETY: sets the QoS class of the calling thread only.
        unsafe {
            libc::pthread_set_qos_class_self_np(libc::qos_class_t::QOS_CLASS_USER_INTERACTIVE, 0)
                == 0
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        false
    }
}

/// A fixed integer loop whose time tracks the speed of the core running this process.
fn calibrate() -> f64 {
    let mut best = f64::MAX;
    for _ in 0..3 {
        let started = Instant::now();
        let mut value: u64 = 0;
        for index in 0..50_000_000u64 {
            value = black_box((value + index * 7) % 1_000_003);
        }
        black_box(value);
        best = best.min(started.elapsed().as_secs_f64() * 1000.0);
    }
    best
}

fn percentile(sorted: &[u64], fraction: f64) -> u64 {
    sorted[((sorted.len() as f64 * fraction).ceil() as usize).clamp(1, sorted.len()) - 1]
}

#[test]
#[ignore = "explicit release-mode fuzzy benchmark; see the module documentation"]
fn fuzzy_l1() {
    let Some(directory) = env("YOZ_FUZZY_BENCH_CORPUS").map(PathBuf::from) else {
        eprintln!("fuzzy_l1: YOZ_FUZZY_BENCH_CORPUS is not set; skipped");
        return;
    };
    let corpora = env("YOZ_FUZZY_BENCH_CORPORA").unwrap_or_else(|| {
        "repo,runtime,plugins,synthetic-10k,synthetic-100k,labels,labels-100k,unicode".into()
    });
    let samples: usize =
        env("YOZ_FUZZY_BENCH_SAMPLES").map_or(5, |value| value.parse().expect("samples"));
    let every: u32 =
        env("YOZ_FUZZY_BENCH_SEQUENCES").map_or(1, |value| value.parse().expect("sequences"));
    let mut output: Box<dyn std::io::Write> = match env("YOZ_FUZZY_BENCH_OUT") {
        Some(path) => Box::new(
            OpenOptions::new()
                .create(true)
                .append(true)
                .open(path)
                .expect("output file"),
        ),
        None => Box::new(std::io::stdout()),
    };
    let prefix = if env("YOZ_FUZZY_BENCH_OUT").is_some() {
        ""
    } else {
        "FUZZY_BENCH_JSON "
    };
    let qos = prefer_performance_cores();
    let calibration_ms = calibrate();
    for name in corpora.split(',') {
        let corpus = load(&directory, name, every);
        let mut probes = probes(env("YOZ_FUZZY_BENCH_PROBES").as_deref());
        let build_ms: Vec<f64> = probes
            .iter_mut()
            .map(|probe| probe.prepare(&corpus))
            .collect();
        // Warm caches and code paths with one untimed pass per probe.
        for probe in probes.iter_mut() {
            for query in &corpus.queries {
                black_box(probe.run(&corpus, query));
            }
        }
        let mut timings =
            vec![vec![Vec::with_capacity(samples); corpus.queries.len()]; probes.len()];
        let mut matched = vec![vec![0usize; corpus.queries.len()]; probes.len()];
        for sample in 0..samples {
            // Rotate the probe order so drift does not favour one probe.
            for step in 0..probes.len() {
                let index = (step + sample) % probes.len();
                for (at, query) in corpus.queries.iter().enumerate() {
                    let started = Instant::now();
                    let count = black_box(probes[index].run(&corpus, query));
                    timings[index][at].push(started.elapsed().as_nanos() as u64);
                    matched[index][at] = count;
                }
            }
        }
        for (index, probe) in probes.iter().enumerate() {
            let mut medians = Vec::with_capacity(corpus.queries.len());
            let mut rows = String::new();
            for (at, query) in corpus.queries.iter().enumerate() {
                let value = median(&mut timings[index][at]);
                medians.push(value);
                if !rows.is_empty() {
                    rows.push(',');
                }
                let _ = write!(
                    rows,
                    "[{},{},{},{},{},{}]",
                    query.sequence,
                    query.step,
                    query.text.chars().count(),
                    escape(&query.kind),
                    value,
                    matched[index][at]
                );
            }
            medians.sort_unstable();
            let ms = |ns: u64| ns as f64 / 1e6;
            let line = format!(
                "{{\"schema\":\"{SCHEMA}\",\"level\":\"rust\",\"corpus\":{},\"corpus_sha256\":{},\"kind\":{},\"scheme\":{},\"items\":{},\"probe\":{},\"threads\":{},\"samples\":{},\"sequence_stride\":{},\"build_ms\":{:.3},\"qos\":{qos},\"calibration_ms\":{calibration_ms:.3},\"queries\":[{}]}}",
                escape(&corpus.name),
                escape(&corpus.sha256),
                escape(&corpus.kind),
                escape(&corpus.scheme),
                corpus.items.len(),
                escape(probe.name()),
                probe.threads(),
                samples,
                every,
                build_ms[index],
                rows
            );
            writeln!(output, "{prefix}{line}").expect("write benchmark record");
            eprintln!(
                "{:<16} {:<16} n={:<4} p50={:>9.3}ms p95={:>9.3}ms max={:>9.3}ms",
                corpus.name,
                probe.name(),
                medians.len(),
                ms(percentile(&medians, 0.5)),
                ms(percentile(&medians, 0.95)),
                ms(*medians.last().unwrap_or(&0))
            );
        }
    }
}

/// Result order against fzf itself: `fzf --filter QUERY --literal --scheme=<corpus scheme>` on every query
/// of each corpus, without weights. Needs `fzf` on `PATH`; by hand:
/// `YOZ_FUZZY_BENCH_CORPUS=<dir> cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib
/// fuzzy::perf_tests::fzf_parity -- --ignored --nocapture`.
/// `YOZ_FUZZY_PARITY_CORPORA` picks corpora (default: the ASCII ones below 100k items);
/// `YOZ_FUZZY_PARITY_EXACT=1` compares exact matching with `fzf --exact`.
#[test]
#[ignore = "explicit comparison with an installed fzf; see the function documentation"]
fn fzf_parity() {
    use std::process::{Command, Stdio};

    let Some(directory) = env("YOZ_FUZZY_BENCH_CORPUS").map(PathBuf::from) else {
        eprintln!("fzf_parity: YOZ_FUZZY_BENCH_CORPUS is not set; skipped");
        return;
    };
    let corpora = env("YOZ_FUZZY_PARITY_CORPORA")
        .unwrap_or_else(|| "repo,runtime,plugins,synthetic-10k,labels".into());
    let exact = env("YOZ_FUZZY_PARITY_EXACT").is_some_and(|value| value == "1");
    let mut failures = 0;
    for name in corpora.split(',') {
        let corpus = load(&directory, name, 1);
        let scheme = if corpus.scheme == "path" {
            Scheme::Path
        } else {
            Scheme::Default
        };
        let mut fuzzy = FuzzyCorpus::new(scheme);
        fuzzy.append(&corpus.items).unwrap();
        let input = corpus.items.join("\n");
        let (mut same, mut order, mut membership) = (0, 0, 0);
        let mut seen = HashSet::new();
        // The typing sequences rarely produce these forms.
        let extra = [
            "'core",
            "'lua'",
            "'init' lua",
            "^lua/ .lua$",
            "!test core",
            "!'spec co",
            "core | yoz",
            "^README$",
            "a\\ b",
            "init\\ ",
            "$",
            "|",
            "| core",
            "core |",
            "'",
            "^",
            "!",
            "!^lua",
            "!.lua$ src",
            "^.git",
            "Co Re",
            "LUA",
        ];
        let queries = corpus
            .queries
            .iter()
            .map(|query| query.text.as_str())
            .chain(extra);
        for text in queries {
            let query = Query {
                sequence: 0,
                kind: String::new(),
                target: 0,
                step: 0,
                text: text.to_owned(),
            };
            if !seen.insert(query.text.clone()) {
                continue;
            }
            let mut child = Command::new("fzf")
                .args([
                    "--filter",
                    &query.text,
                    "--literal",
                    "--scheme",
                    &corpus.scheme,
                ])
                .args(exact.then_some("--exact"))
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .spawn()
                .expect("fzf on PATH");
            child
                .stdin
                .take()
                .unwrap()
                .write_all(input.as_bytes())
                .expect("fzf input");
            let output = child.wait_with_output().expect("fzf output");
            let expected: Vec<&str> = std::str::from_utf8(&output.stdout)
                .expect("fzf UTF-8")
                .lines()
                .collect();
            let ranked = fuzzy.query(&FuzzyQuery {
                pattern: &query.text,
                fuzzy: !exact,
                case: CaseMode::Smart,
                rank: true,
                weight: 0,
                threads: 0,
            });
            let actual: Vec<&str> = ranked
                .indices
                .iter()
                .map(|&index| fuzzy.text(index as usize))
                .collect();
            if actual == expected {
                same += 1;
                continue;
            }
            let mut sorted_actual = actual.clone();
            let mut sorted_expected = expected.clone();
            sorted_actual.sort_unstable();
            sorted_expected.sort_unstable();
            if sorted_actual == sorted_expected {
                order += 1;
            } else {
                membership += 1;
            }
            if order + membership <= 3 {
                let at = actual
                    .iter()
                    .zip(&expected)
                    .position(|(left, right)| left != right)
                    .unwrap_or(0);
                eprintln!(
                    "  {name} {:?}: {} vs fzf {} matches; first difference at {at}: {:?} vs fzf {:?}",
                    query.text,
                    actual.len(),
                    expected.len(),
                    actual.get(at),
                    expected.get(at)
                );
            }
        }
        eprintln!("{name:<16} identical={same} order_differs={order} matches_differ={membership}");
        failures += order + membership;
    }
    assert_eq!(failures, 0, "queries whose results differ from fzf");
}

/// Ranking quality of the frecency weight: per typing sequence, where its target ranks after each
/// keystroke. About 2% of items get a frecency of 10..=100, as the L3 runs seed them; the target is
/// frecent (60) in one scenario and plain while distractors may be frecent in the other. By hand:
/// `YOZ_FUZZY_BENCH_CORPUS=<dir> cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib
/// fuzzy::perf_tests::fuzzy_quality -- --ignored --nocapture`.
#[test]
#[ignore = "explicit ranking-quality measurement; see the function documentation"]
fn fuzzy_quality() {
    let Some(directory) = env("YOZ_FUZZY_BENCH_CORPUS").map(PathBuf::from) else {
        eprintln!("fuzzy_quality: YOZ_FUZZY_BENCH_CORPUS is not set; skipped");
        return;
    };
    let corpora = env("YOZ_FUZZY_BENCH_CORPORA")
        .unwrap_or_else(|| "repo,runtime,plugins,synthetic-10k".into());
    for name in corpora.split(',') {
        let corpus = load(&directory, name, 1);
        let mut fuzzy = FuzzyCorpus::new(if corpus.scheme == "path" {
            Scheme::Path
        } else {
            Scheme::Default
        });
        fuzzy.append(&corpus.items).unwrap();
        let mut state: u64 = 0x5eed1234;
        let mut random = |bound: u64| {
            state = state
                .wrapping_mul(6364136223846793005)
                .wrapping_add(1442695040888963407);
            (state >> 33) % bound
        };
        let base: Vec<u8> = (0..corpus.items.len())
            .map(|_| {
                if random(50) == 0 {
                    10 + random(91) as u8
                } else {
                    0
                }
            })
            .collect();
        let mut sequences: Vec<Vec<&Query>> = Vec::new();
        for query in corpus
            .queries
            .iter()
            .filter(|query| !matches!(query.kind.as_str(), "nomatch" | "extended"))
        {
            match sequences.last_mut() {
                Some(sequence) if sequence[0].sequence == query.sequence => sequence.push(query),
                _ => sequences.push(vec![query]),
            }
        }
        eprintln!("{name}: {} sequences", sequences.len());
        eprintln!("  weight  target   mrr    keys-to-top  top1-at-end");
        for weight in [0, 8, 16, 32, 64, 128] {
            for (label, target_weight) in [("frecent", 60u8), ("plain", 0u8)] {
                let (mut reciprocal, mut steps, mut keys, mut top) =
                    (0.0f64, 0usize, 0usize, 0usize);
                for sequence in &sequences {
                    let target = sequence[0].target;
                    let mut weights = base.clone();
                    weights[target as usize] = target_weight;
                    fuzzy.set_weights(&weights).unwrap();
                    let mut first_top = sequence.len() + 1;
                    let mut last_rank = None;
                    for (at, query) in sequence.iter().enumerate() {
                        let ranked = fuzzy.query(&FuzzyQuery {
                            pattern: &query.text,
                            fuzzy: true,
                            case: CaseMode::Smart,
                            rank: true,
                            weight,
                            threads: 0,
                        });
                        let rank = ranked
                            .indices
                            .iter()
                            .position(|&index| index == target)
                            .map(|rank| rank + 1);
                        reciprocal += rank.map_or(0.0, |rank| 1.0 / rank as f64);
                        steps += 1;
                        if rank == Some(1) && first_top > sequence.len() {
                            first_top = at + 1;
                        }
                        last_rank = rank;
                    }
                    keys += first_top;
                    top += usize::from(last_rank == Some(1));
                }
                eprintln!(
                    "  {weight:>6}  {label:<7}  {:.3}  {:>11.2}  {:>10.1}%",
                    reciprocal / steps as f64,
                    keys as f64 / sequences.len() as f64,
                    100.0 * top as f64 / sequences.len() as f64
                );
            }
        }
    }
}
