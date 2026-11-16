//! Release-mode probes of the pairs engine (no FFI) over this checkout's sources, up to the 3 MB a buffer may hold
//! before the configuration treats it as a big file:
//! `cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib pairs::perf_tests -- --ignored --nocapture
//! --test-threads=1`

use super::document::Document;
use super::language::{self, Kind};
use crate::test_support::percentile;
use std::fs;
use std::hint::black_box;
use std::path::{Path, PathBuf};
use std::time::Instant;

/** The largest buffer pairs parse, as the editor's 3 MiB big-file limit with a margin. */
const MAX_BYTES: usize = 3_000_000;

fn files(directory: &Path, extension: &str, out: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(directory) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            if path
                .file_name()
                .is_some_and(|name| name != "dict" && name != "target")
            {
                files(&path, extension, out);
            }
        } else if path.extension().is_some_and(|value| value == extension) {
            out.push(path);
        }
    }
}

/// Lines of the checkout's files under `directory` with `extension`, by path, repeated up to `limit` bytes.
fn corpus(directory: &str, extension: &str, limit: usize) -> Vec<Box<[u8]>> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../..")
        .join(directory);
    let mut paths = Vec::new();
    files(&root, extension, &mut paths);
    paths.sort();
    assert!(
        !paths.is_empty(),
        "no {extension} files under {}",
        root.display()
    );
    let mut lines: Vec<Box<[u8]>> = Vec::new();
    let mut bytes = 0;
    loop {
        for path in &paths {
            for line in fs::read(path)
                .expect("readable source")
                .split(|&byte| byte == b'\n')
            {
                bytes += line.len() + 1;
                if bytes > limit {
                    return lines;
                }
                lines.push(Box::from(line));
            }
        }
    }
}

/// Times `run` `count` times after `count / 10` warm-ups and prints the median and p95 in milliseconds.
fn probe(name: &str, count: usize, mut run: impl FnMut(usize)) {
    for index in 0..count / 10 {
        run(index);
    }
    let mut samples: Vec<f64> = (0..count)
        .map(|index| {
            let started = Instant::now();
            run(index);
            started.elapsed().as_secs_f64() * 1e3
        })
        .collect();
    samples.sort_by(f64::total_cmp);
    let (median, p95) = (percentile(&samples, 0.5), percentile(&samples, 0.95));
    println!("  {name:<34} median {median:>9.4} ms   p95 {p95:>9.4} ms");
}

fn text(line: &[u8]) -> String {
    String::from_utf8_lossy(line).into_owned()
}

/// The first row at or after `from` that `predicate` accepts.
fn row_after(lines: &[Box<[u8]>], from: usize, predicate: impl Fn(&str) -> bool) -> usize {
    (from..lines.len())
        .find(|&row| predicate(&text(&lines[row])))
        .expect("a matching row")
}

#[test]
#[ignore]
fn t_pairs_engine() {
    for (name, directory, extension) in [("lua", "lua", "lua"), ("rust", "rust", "rs")] {
        let lines = corpus(directory, extension, MAX_BYTES);
        let language = language::language(name).expect("language");
        let bytes: usize = lines.iter().map(|line| line.len() + 1).sum();
        println!("{name}: {} lines, {bytes} bytes", lines.len());

        probe("full parse", 20, |_| {
            let mut document = Document::new(language, 4);
            black_box(document.edit(0, 0, lines.clone()));
            document.settle();
        });

        let mut document = Document::new(language, 4);
        document.edit(0, 0, lines.clone());
        document.settle();
        // A new tab width keeps the tokens and pairs them all again.
        probe("pair all", 20, |index| {
            document.set_tab_width(if index % 2 == 0 { 8 } else { 4 });
            document.settle();
        });
        document.set_tab_width(4);
        document.settle();
        let middle = lines.len() / 2;
        // A line with code to type into, an indented line inside brackets, and one outside any.
        let typed = row_after(&lines, middle, |line| {
            line.trim_start().len() > 8 && !line.contains("--") && !line.contains("//")
        });
        let original = lines[typed].clone();
        let at = original
            .iter()
            .position(|&byte| byte != b' ' && byte != b'\t')
            .unwrap_or(0);
        let with = |insert: &str| {
            let mut line = original.to_vec();
            line.splice(at..at, insert.bytes());
            vec![line.into_boxed_slice()]
        };
        for (probe_name, insert) in [
            ("edit letter", "x"),
            ("edit balanced pair", "()"),
            ("edit open bracket", "("),
        ] {
            let edited = with(insert);
            probe(probe_name, 200, |index| {
                if index % 2 == 0 {
                    document.edit(typed, typed + 1, edited.clone());
                } else {
                    document.edit(typed, typed + 1, vec![original.clone()]);
                }
                document.settle();
            });
            document.edit(typed, typed + 1, vec![original.clone()]);
            document.settle();
        }
        let opener = row_after(&lines, middle, |line| {
            line.trim_end().ends_with('{') || line.trim_end().ends_with('(')
        });
        let removed = lines[opener].clone();
        probe("delete an opening line", 200, |index| {
            if index % 2 == 0 {
                document.edit(opener, opener + 1, Vec::new());
            } else {
                document.edit(opener, opener, vec![removed.clone()]);
            }
            document.settle();
        });
        document.edit(0, document.line_count(), lines.clone());
        document.settle();

        let top = row_after(&lines, middle, |line| {
            !line.is_empty()
                && !line.starts_with(' ')
                && !line.starts_with('\t')
                && line.chars().next().is_some_and(char::is_alphabetic)
                && !line.contains(['(', '[', '{', ')', ']', '}'])
        });
        let deep = row_after(&lines, middle, |line| {
            line.starts_with("            ")
                && line
                    .trim_start()
                    .chars()
                    .next()
                    .is_some_and(char::is_alphabetic)
        });
        for (place, row) in [("top level", top), ("nested", deep)] {
            let col = lines[row]
                .iter()
                .position(|&byte| byte != b' ' && byte != b'\t')
                .unwrap_or(0);
            probe(&format!("surrounding pair, {place}"), 2000, |_| {
                black_box(document.surrounding_pair(row, col));
            });
            let end = lines[row].len();
            probe(&format!("unmatched closing after, {place}"), 2000, |_| {
                black_box(document.unmatched("(", ")", row, end, Kind::Closing));
            });
            probe(&format!("unmatched opening before, {place}"), 2000, |_| {
                black_box(document.unmatched("(", ")", row, end, Kind::Opening));
            });
        }
        probe("highlights of 50 rows", 2000, |_| {
            black_box(document.highlights((middle, 0), (middle + 50, 0)).count());
        });
    }
}
