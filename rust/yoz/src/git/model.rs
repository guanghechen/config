use std::collections::BTreeMap;
use std::collections::HashMap;

pub const CODES: &[(u8, u16, &str)] = &[
    (b'U', 1, "conflict"),
    (b'?', 2, "untracked"),
    (b'M', 4, "modified"),
    (b'D', 8, "deleted"),
    (b'A', 16, "added"),
    (b'R', 32, "renamed"),
    (b'C', 64, "copied"),
    (b'T', 128, "type_changed"),
    (b'!', 256, "ignored"),
];

pub fn code_bit(code: u8) -> Result<u16, String> {
    CODES
        .iter()
        .find(|entry| entry.0 == code)
        .map(|entry| entry.1)
        .ok_or_else(|| format!("Unsupported Git status code: {}", char::from(code)))
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Stage {
    Staged,
    Unstaged,
    Mixed,
}

impl Stage {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Staged => "staged",
            Self::Unstaged => "unstaged",
            Self::Mixed => "mixed",
        }
    }

    fn combine(self, other: Self) -> Self {
        if self == other { self } else { Self::Mixed }
    }
}

fn display(bits: u16) -> String {
    CODES
        .iter()
        .filter(|entry| bits & entry.1 != 0)
        .map(|entry| {
            if entry.0 == b'?' {
                'U'
            } else {
                char::from(entry.0)
            }
        })
        .collect()
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct Info {
    pub codes: u16,
    pub stage: Option<Stage>,
    pub display: String,
    pub staged_display: String,
    pub summary: Option<u8>,
}

impl Info {
    pub fn categories(&self) -> impl Iterator<Item = &'static str> + '_ {
        CODES
            .iter()
            .filter(|entry| self.codes & entry.1 != 0)
            .map(|entry| entry.2)
            .chain(matches!(self.stage, Some(Stage::Staged | Stage::Mixed)).then_some("staged"))
            .chain(matches!(self.stage, Some(Stage::Unstaged | Stage::Mixed)).then_some("unstaged"))
    }

    fn merge(&mut self, entry: &Entry) {
        self.codes |= entry.staged | entry.unstaged;
        self.stage = match (self.stage, entry.stage()) {
            (Some(left), Some(right)) => Some(left.combine(right)),
            (left, right) => left.or(right),
        };
    }

    fn finish(&mut self) {
        self.display = display(self.codes);
        self.summary = CODES
            .iter()
            .find(|entry| self.codes & entry.1 != 0)
            .map(|entry| entry.0);
    }
}

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct Entry {
    pub relative: Vec<u8>,
    pub staged: u16,
    pub unstaged: u16,
    pub staged_previous: Option<Vec<u8>>,
    pub unstaged_previous: Option<Vec<u8>>,
    pub staged_old: Option<Vec<u8>>,
    pub staged_new: Option<Vec<u8>>,
    pub unstaged_old: Option<Vec<u8>>,
    pub unstaged_new: Option<Vec<u8>>,
}

impl Entry {
    pub fn stage(&self) -> Option<Stage> {
        // Untracked and ignored entries have no staged/unstaged tracked state.
        const NON_TRACKED: u16 = 2 | 256;
        match (
            self.staged & !NON_TRACKED != 0,
            self.unstaged & !NON_TRACKED != 0,
        ) {
            (true, true) => Some(Stage::Mixed),
            (true, false) => Some(Stage::Staged),
            (false, true) => Some(Stage::Unstaged),
            _ => None,
        }
    }

    pub fn info(&self) -> Info {
        let mut result = Info::default();
        result.merge(self);
        result.finish();
        result.staged_display = display(self.staged);
        result.display = result.staged_display.clone() + &display(self.unstaged);
        result
    }

    pub fn unstaged_display(&self) -> String {
        display(self.unstaged)
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Numstat {
    pub insertions: u64,
    pub deletions: u64,
}

#[derive(Debug, Default, Eq, PartialEq)]
pub struct Numstats {
    pub staged: BTreeMap<Vec<u8>, Numstat>,
    pub unstaged: BTreeMap<Vec<u8>, Numstat>,
}

/// An immutable query result. Directory indexes are built in the worker, never during a UI lookup.
#[derive(Debug, Default)]
pub struct Snapshot {
    pub(crate) entries: BTreeMap<Vec<u8>, Entry>,
    pub(crate) numstats: Option<Numstats>,
    pub(crate) commands: usize,
    pub(crate) elapsed_ms: f64,
    directories: HashMap<Vec<u8>, Info>,
    retained_bytes: usize,
}

pub fn parent(path: &[u8]) -> Option<&[u8]> {
    if path == b"/" {
        return None;
    }
    let index = path.iter().rposition(|byte| *byte == b'/')?;
    Some(if index == 0 { b"/" } else { &path[..index] })
}

impl Snapshot {
    pub fn new(entries: BTreeMap<Vec<u8>, Entry>, numstats: Option<Numstats>) -> Self {
        let mut directories = HashMap::<Vec<u8>, Info>::new();
        for (path, entry) in &entries {
            let mut current = parent(path);
            while let Some(directory) = current {
                directories
                    .entry(directory.to_vec())
                    .or_default()
                    .merge(entry);
                current = parent(directory);
            }
        }
        for (path, info) in &mut directories {
            if let Some(entry) = entries.get(path) {
                info.merge(entry);
                info.staged_display = display(entry.staged);
            }
            info.finish();
        }
        let mut result = Self {
            entries,
            numstats,
            directories,
            commands: 0,
            elapsed_ms: 0.0,
            retained_bytes: 0,
        };
        result.retained_bytes = result.measure_bytes();
        result
    }

    pub fn same_status(&self, other: &Self) -> bool {
        self.entries == other.entries
    }

    pub fn entries(&self) -> &BTreeMap<Vec<u8>, Entry> {
        &self.entries
    }

    pub fn numstats(&self) -> Option<&Numstats> {
        self.numstats.as_ref()
    }

    pub fn stats(&self) -> (usize, f64) {
        (self.commands, self.elapsed_ms)
    }

    pub(crate) fn retained_bytes(&self) -> usize {
        self.retained_bytes.max(std::mem::size_of::<Self>())
    }

    fn measure_bytes(&self) -> usize {
        let entries: usize = self
            .entries
            .iter()
            .map(|(path, entry)| {
                path.capacity()
                    + entry.relative.capacity()
                    + 192
                    + [
                        &entry.staged_previous,
                        &entry.unstaged_previous,
                        &entry.staged_old,
                        &entry.staged_new,
                        &entry.unstaged_old,
                        &entry.unstaged_new,
                    ]
                    .iter()
                    .map(|value| value.as_ref().map_or(0, Vec::capacity))
                    .sum::<usize>()
            })
            .sum();
        let directories: usize = self
            .directories
            .iter()
            .map(|(path, info)| {
                path.capacity() + info.display.capacity() + info.staged_display.capacity() + 128
            })
            .sum();
        let numstats = self.numstats.as_ref().map_or(0, |stats| {
            stats
                .staged
                .keys()
                .chain(stats.unstaged.keys())
                .map(|path| path.capacity() + 96)
                .sum()
        });
        entries + directories + numstats + std::mem::size_of::<Self>()
    }

    fn untracked_ancestor(&self, path: &[u8]) -> Option<&Entry> {
        let mut current = parent(path);
        while let Some(path) = current {
            if let Some(entry) = self.entries.get(path)
                && (entry.staged | entry.unstaged) & 2 != 0
            {
                return Some(entry);
            }
            current = parent(path);
        }
        None
    }

    pub fn lookup(&self, path: &[u8], directory: bool) -> Option<Info> {
        if directory && let Some(info) = self.directories.get(path) {
            return Some(info.clone());
        }
        if !directory {
            if let Some(entry) = self.entries.get(path) {
                return Some(entry.info());
            }
            self.untracked_ancestor(path)?;
            return Some(Info {
                codes: 2,
                display: "U".into(),
                summary: Some(b'?'),
                ..Info::default()
            });
        }
        let own = self.entries.get(path);
        let entry = own.or_else(|| self.untracked_ancestor(path))?;
        let mut info = Info::default();
        info.merge(entry);
        info.finish();
        if let Some(own) = own {
            info.staged_display = display(own.staged);
        }
        Some(info)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(code: u8, staged: bool) -> Entry {
        let mut entry = Entry::default();
        if staged {
            entry.staged = code_bit(code).unwrap();
        } else {
            entry.unstaged = code_bit(code).unwrap();
        }
        entry
    }

    #[test]
    fn t_directory_union_preserves_stage_and_code_priority() {
        let entries = BTreeMap::from([
            (b"/repo/dir/first".to_vec(), item(b'A', true)),
            (b"/repo/dir/second".to_vec(), item(b'M', false)),
            (b"/repo/dir/link".to_vec(), item(b'?', false)),
        ]);
        let snapshot = Snapshot::new(entries, None);
        let info = snapshot.lookup(b"/repo/dir", true).unwrap();
        assert_eq!(info.display, "UMA");
        assert_eq!(info.summary, Some(b'?'));
        assert_eq!(info.stage, Some(Stage::Mixed));
        assert_eq!(snapshot.lookup(b"/", true).unwrap().display, "UMA");
        assert!(snapshot.lookup(b"/repo/directory", true).is_none());
    }

    #[test]
    fn t_untracked_symlink_own_entry_and_descendants() {
        let snapshot = Snapshot::new(
            BTreeMap::from([(b"/repo/link".to_vec(), item(b'?', false))]),
            None,
        );
        for directory in [false, true] {
            assert_eq!(
                snapshot
                    .lookup(b"/repo/link/sub/file", directory)
                    .unwrap()
                    .display,
                "U"
            );
        }
        assert_eq!(snapshot.lookup(b"/repo/link", true).unwrap().stage, None);
        assert!(snapshot.lookup(b"/repo/link-other", true).is_none());
    }

    #[test]
    fn t_own_directory_entry_merges_without_leaking_parent_status() {
        let snapshot = Snapshot::new(
            BTreeMap::from([
                (b"/repo/link".to_vec(), item(b'?', false)),
                (b"/repo/link/sub/file".to_vec(), item(b'M', false)),
            ]),
            None,
        );
        assert_eq!(snapshot.lookup(b"/repo/link", true).unwrap().display, "UM");
        assert_eq!(
            snapshot.lookup(b"/repo/link/sub", true).unwrap().display,
            "M"
        );
    }

    #[test]
    fn t_paths_preserve_bytes_and_canonical_windows_keys() {
        let snapshot = Snapshot::new(
            BTreeMap::from([
                (b"C:/repo/dir/file".to_vec(), item(b'M', false)),
                (b"/repo/back\\slash/\xff".to_vec(), item(b'A', true)),
            ]),
            None,
        );
        assert_eq!(snapshot.lookup(b"C:/repo/dir", true).unwrap().display, "M");
        assert_eq!(
            snapshot.lookup(b"/repo/back\\slash", true).unwrap().display,
            "A"
        );
        assert!(snapshot.lookup(b"/repo/back/slash", true).is_none());
    }

    #[test]
    fn t_status_equality_excludes_query_timing() {
        let mut left = Snapshot::new(
            BTreeMap::from([(b"/repo/file".to_vec(), item(b'M', false))]),
            None,
        );
        let right = Snapshot::new(left.entries.clone(), None);
        left.elapsed_ms = 100.0;
        left.commands = 3;
        assert!(left.same_status(&right));
        left.entries
            .get_mut(b"/repo/file".as_slice())
            .unwrap()
            .unstaged = 8;
        assert!(!left.same_status(&right));
    }

    #[test]
    fn t_untracked_descendant_files_do_not_inherit_parent_staged_deletions() {
        let mut entry = item(b'?', false);
        entry.staged = 8;
        let snapshot = Snapshot::new(BTreeMap::from([(b"/repo/link".to_vec(), entry)]), None);
        assert_eq!(
            snapshot.lookup(b"/repo/link/file", false).unwrap().display,
            "U"
        );
        assert_eq!(
            snapshot.lookup(b"/repo/link/dir", true).unwrap().display,
            "UD"
        );
        assert_eq!(
            snapshot.lookup(b"/repo/link", true).unwrap().staged_display,
            "D"
        );
    }

    #[test]
    fn t_directory_own_staged_status_preserves_the_staged_segment() {
        let snapshot = Snapshot::new(
            BTreeMap::from([
                (b"/repo/module".to_vec(), item(b'M', true)),
                (b"/repo/module/file".to_vec(), item(b'?', false)),
            ]),
            None,
        );
        assert_eq!(
            snapshot
                .lookup(b"/repo/module", true)
                .unwrap()
                .staged_display,
            "M"
        );
    }
}
