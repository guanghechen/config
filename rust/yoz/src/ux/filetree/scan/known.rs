use super::Reservation;
use crate::ux::filetree::{Entry, FileIdentity, resource};
use crate::ux::treeview::{Error, NodeId, Result, Source};
use std::collections::BTreeSet;
use std::ffi::OsStr;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

struct Identity {
    value: FileIdentity,
    original: Option<u32>,
    observed: u8,
}

/** All ordinals, names and identities belong to this single immutable alignment snapshot. */
pub(super) struct Known {
    pub source: Arc<Source>,
    children: Vec<NodeId>,
    identities: Vec<Identity>,
    flags: Vec<u8>,
    active: Vec<u64>,
    nonempty: BTreeSet<usize>,
}

impl Known {
    pub fn new(
        source: Arc<Source>,
        parent: NodeId,
        reservation: &mut Reservation,
        cancelled: &AtomicBool,
    ) -> Result<Self> {
        let node = source.node(parent).ok_or_else(|| Error::missing(parent))?;
        let count = node.child_count();
        u32::try_from(count).map_err(|_| Error::limit("scan child ordinal capacity exceeded"))?;
        let groups = count.div_ceil(64);
        let bytes = count
            .checked_mul(std::mem::size_of::<NodeId>() + std::mem::size_of::<Identity>() + 1)
            .and_then(|bytes| bytes.checked_add(groups * (8 + 64)))
            .ok_or_else(|| Error::limit("scan index capacity exceeded"))?;
        reservation.add(bytes)?;
        let mut children = Vec::with_capacity(count);
        let mut identities = Vec::with_capacity(count);
        for (ordinal, id) in node.children().enumerate() {
            if cancelled.load(Ordering::Acquire) {
                return Err(Error::stale("directory scan cancelled"));
            }
            identities.push(Identity {
                value: resource::entry(&source, id)?.identity,
                original: Some(ordinal as u32),
                observed: 0,
            });
            children.push(id);
        }
        identities.sort_unstable_by_key(|item| (item.value.volume, item.value.file));
        identities.dedup_by(|next, previous| {
            if next.value == previous.value {
                previous.original = None;
                true
            } else {
                false
            }
        });
        if cancelled.load(Ordering::Acquire) {
            return Err(Error::stale("directory scan cancelled"));
        }
        let mut active = vec![u64::MAX; groups];
        if count % 64 != 0 {
            *active.last_mut().expect("partial group") = (1 << (count % 64)) - 1;
        }
        Ok(Self {
            source,
            children,
            identities,
            flags: vec![0; count],
            active,
            nonempty: (0..groups).collect(),
        })
    }

    pub fn entry(&self, ordinal: usize) -> Result<Entry> {
        resource::entry(&self.source, self.children[ordinal])
    }

    pub fn node(&self, ordinal: usize) -> NodeId {
        self.children[ordinal]
    }

    pub fn lower_bound(&self, directory: bool, name: &OsStr) -> Result<usize> {
        let (mut first, mut last) = (0, self.children.len());
        while first < last {
            let middle = first + (last - first) / 2;
            if self.entry(middle)?.sort_name_cmp(directory, name).is_lt() {
                first = middle + 1;
            } else {
                last = middle;
            }
        }
        Ok(first)
    }

    pub fn named(&self, entry: &Entry) -> Result<Option<usize>> {
        /* Most refresh observations retain a unique identity and name; avoid decoding a name search path. */
        if let Some(index) = self.identity(entry.identity)
            && let Some(ordinal) = self.identities[index].original
            && self.entry(ordinal as usize)?.name == entry.name
        {
            return Ok(Some(ordinal as usize));
        }
        for directory in [entry.directory(), !entry.directory()] {
            let ordinal = self.lower_bound(directory, &entry.name)?;
            if ordinal < self.children.len() && self.entry(ordinal)?.name == entry.name {
                return Ok(Some(ordinal));
            }
        }
        Ok(None)
    }

    pub fn observe_name(&mut self, ordinal: usize) -> bool {
        let fresh = self.flags[ordinal] & 1 == 0;
        self.flags[ordinal] |= 1;
        fresh
    }

    fn identity(&self, value: FileIdentity) -> Option<usize> {
        self.identities
            .binary_search_by_key(&(value.volume, value.file), |item| {
                (item.value.volume, item.value.file)
            })
            .ok()
    }

    pub fn observe_identity(&mut self, value: FileIdentity) -> bool {
        let Some(index) = self.identity(value) else {
            return false;
        };
        self.identities[index].observed = (self.identities[index].observed + 1).min(2);
        true
    }

    pub fn unique(&self, value: FileIdentity) -> Option<usize> {
        self.identity(value).and_then(|index| {
            let item = &self.identities[index];
            (item.observed == 1)
                .then_some(item.original)
                .flatten()
                .map(|value| value as usize)
        })
    }

    pub fn renamed(&self, entry: &Entry) -> Result<bool> {
        self.unique(entry.identity).map_or(Ok(false), |ordinal| {
            Ok(self.entry(ordinal)?.name != entry.name)
        })
    }

    pub fn take(&mut self, ordinal: usize) -> Option<usize> {
        let fresh = self.flags[ordinal] & 2 == 0;
        self.flags[ordinal] |= 2;
        fresh.then_some(ordinal)
    }

    pub fn retire(&mut self, ordinal: usize) {
        let group = ordinal / 64;
        self.active[group] &= !(1 << (ordinal % 64));
        if self.active[group] == 0 {
            self.nonempty.remove(&group);
        }
    }

    pub fn next(&self, ordinal: usize) -> Option<usize> {
        if ordinal >= self.children.len() {
            return None;
        }
        let group = ordinal / 64;
        let word = self.active[group] & (u64::MAX << (ordinal % 64));
        if word != 0 {
            return Some(group * 64 + word.trailing_zeros() as usize);
        }
        self.nonempty
            .range((std::ops::Bound::Excluded(group), std::ops::Bound::Unbounded))
            .next()
            .map(|&group| group * 64 + self.active[group].trailing_zeros() as usize)
    }
}
