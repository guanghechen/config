use super::super::memory::Charge;
use super::super::model::{Error, NodeId, Result};
use super::map::Map;
use super::sequence::{Contents, Iter, Sequence};
use std::collections::{HashMap, HashSet};

pub(crate) trait IndexedValue: Clone {
    fn ids(&self) -> &[NodeId];
}

impl IndexedValue for NodeId {
    fn ids(&self) -> &[NodeId] {
        std::slice::from_ref(self)
    }
}

#[derive(Clone, Copy)]
struct Location {
    block: u64,
    offset: usize,
}

/** A bitset ranks occupied IDs into a packed array; each affected page holds at most 64 locations. */
struct LocationPage {
    mask: u64,
    values: Box<[Location]>,
    _memory: Charge,
}

impl LocationPage {
    fn new(mask: u64, values: Vec<Location>) -> Self {
        debug_assert_eq!(mask.count_ones() as usize, values.len());
        Self {
            mask,
            _memory: Charge::new(values.len() * std::mem::size_of::<Location>()),
            values: values.into_boxed_slice(),
        }
    }
}

/** Persistent inverse index with packed 64-ID pages. */
#[derive(Clone, Default)]
struct Locations(Map<u64, LocationPage>);

impl Locations {
    fn from_sorted(values: Vec<(NodeId, Location)>) -> Self {
        let pages = values
            .chunk_by(|left, right| left.0.0 >> 6 == right.0.0 >> 6)
            .map(|chunk| {
                let mask = chunk
                    .iter()
                    .fold(0, |mask, (id, _)| mask | (1 << (id.0 & 63)));
                let values = chunk.iter().map(|(_, location)| *location).collect();
                (chunk[0].0.0 >> 6, LocationPage::new(mask, values))
            })
            .collect();
        Self(Map::from_sorted(pages))
    }

    fn get(&self, id: &NodeId) -> Option<&Location> {
        let page = self.0.get(&(id.0 >> 6))?;
        let bit = 1 << (id.0 & 63);
        (page.mask & bit != 0).then(|| &page.values[(page.mask & (bit - 1)).count_ones() as usize])
    }

    fn remove(&mut self, id: &NodeId) {
        let key = id.0 >> 6;
        let Some(page) = self.0.get(&key) else {
            return;
        };
        let bit = 1 << (id.0 & 63);
        if page.mask & bit == 0 {
            return;
        }
        if page.mask == bit {
            self.0.remove(&key);
        } else {
            let mask = page.mask ^ bit;
            let mut values = page.values.to_vec();
            values.remove((page.mask & (bit - 1)).count_ones() as usize);
            self.0.insert(key, LocationPage::new(mask, values));
        }
    }

    fn extend_sorted(&mut self, values: Vec<(NodeId, Location)>) -> Result<()> {
        let _input = Charge::new(values.capacity() * std::mem::size_of::<(NodeId, Location)>());
        super::super::memory::check()?;
        let mut pages = Vec::new();
        for chunk in values.chunk_by(|left, right| left.0.0 >> 6 == right.0.0 >> 6) {
            let key = chunk[0].0.0 >> 6;
            let previous = self.0.get(&key);
            let mut mask = previous.map_or(0, |page| page.mask);
            let mut values = previous.map_or_else(Vec::new, |page| page.values.to_vec());
            for &(id, location) in chunk {
                let bit = 1 << (id.0 & 63);
                let at = (mask & (bit - 1)).count_ones() as usize;
                if mask & bit == 0 {
                    values.insert(at, location);
                    mask |= bit;
                } else {
                    values[at] = location;
                }
            }
            pages.push((key, LocationPage::new(mask, values)));
        }
        self.0.extend_sorted(pages)
    }
}

#[derive(Clone, Copy, Eq, PartialEq)]
struct Parent {
    parent: Option<u64>,
    offset: usize,
}

#[derive(Clone, Copy, Debug, Default)]
pub(crate) struct IndexWork {
    pub blocks: usize,
    pub locations: usize,
}

#[derive(Clone)]
pub(crate) struct IndexedSequence<T: IndexedValue> {
    sequence: Sequence<T>,
    locations: Locations,
    parents: Map<u64, Parent>,
}

impl<T: IndexedValue> Default for IndexedSequence<T> {
    fn default() -> Self {
        Self {
            sequence: Sequence::default(),
            locations: Locations::default(),
            parents: Map::default(),
        }
    }
}

impl<T: IndexedValue> IndexedSequence<T> {
    pub fn from_vec(values: Vec<T>) -> Result<Self> {
        let sequence = Sequence::from_vec(values)?;
        let mut locations = Vec::new();
        let mut parents = Vec::new();
        let mut pending: Vec<_> = sequence
            .root
            .as_deref()
            .map(|root| {
                (
                    root,
                    Parent {
                        parent: None,
                        offset: 0,
                    },
                )
            })
            .into_iter()
            .collect();
        while let Some((block, parent)) = pending.pop() {
            parents.push((block.id, parent));
            match &block.contents {
                Contents::Leaf(values) => {
                    for (offset, value) in values.iter().enumerate() {
                        for id in value.ids() {
                            locations.push((
                                *id,
                                Location {
                                    block: block.id,
                                    offset,
                                },
                            ));
                        }
                    }
                }
                Contents::Branch(left, right) => {
                    pending.push((
                        right,
                        Parent {
                            parent: Some(block.id),
                            offset: left.len,
                        },
                    ));
                    pending.push((
                        left,
                        Parent {
                            parent: Some(block.id),
                            offset: 0,
                        },
                    ));
                }
            }
        }
        locations.sort_unstable_by_key(|(id, _)| *id);
        if locations.windows(2).any(|pair| pair[0].0 == pair[1].0) {
            return Err(Error::invalid("duplicate identity in projected sequence"));
        }
        parents.sort_unstable_by_key(|(id, _)| *id);
        Ok(Self {
            sequence,
            locations: Locations::from_sorted(locations),
            parents: Map::from_sorted(parents),
        })
    }

    pub fn len(&self) -> usize {
        self.sequence.len()
    }
    pub fn is_empty(&self) -> bool {
        self.sequence.is_empty()
    }
    pub fn get(&self, index: usize) -> Option<&T> {
        self.sequence.get(index)
    }
    pub fn iter(&self) -> Iter<'_, T> {
        self.sequence.iter()
    }
    pub fn iter_from(&self, index: usize) -> Iter<'_, T> {
        self.sequence.iter_from(index)
    }
    pub fn same_version(&self, other: &Self) -> bool {
        self.sequence.same_version(&other.sequence)
    }

    pub fn position(&self, id: &NodeId) -> Option<usize> {
        let location = self.locations.get(id)?;
        let mut offset = location.offset;
        let mut current = location.block;
        loop {
            let link = self.parents.get(&current)?;
            offset = offset.checked_add(link.offset)?;
            let Some(parent) = link.parent else {
                return Some(offset);
            };
            current = parent;
        }
    }

    pub fn lookup(&self, id: NodeId) -> Option<&T> {
        self.get(self.position(&id)?)
    }

    /** Cache block offsets only across lookups in the same immutable sequence versions. */
    pub fn position_cached(&self, id: &NodeId, offsets: &mut HashMap<u64, usize>) -> Option<usize> {
        let location = self.locations.get(id)?;
        let mut current = location.block;
        let mut pending = Vec::new();
        let mut start = loop {
            if let Some(offset) = offsets.get(&current) {
                break *offset;
            }
            let link = self.parents.get(&current)?;
            pending.push((current, link.offset));
            let Some(parent) = link.parent else {
                break 0;
            };
            current = parent;
        };
        for (block, offset) in pending.into_iter().rev() {
            start = start.checked_add(offset)?;
            offsets.insert(block, start);
        }
        start.checked_add(location.offset)
    }

    pub fn shared_spans(&self, target: &Self) -> Vec<(usize, usize, usize)> {
        if self.same_version(target) {
            return vec![(0, 0, self.len())];
        }
        let mut spans = Vec::new();
        let mut pending: Vec<_> = target
            .sequence
            .root
            .as_deref()
            .map(|root| (root, 0usize))
            .into_iter()
            .collect();
        while let Some((block, at)) = pending.pop() {
            if self.parents.get(&block.id).is_some() {
                let mut current = block.id;
                let mut old_at = 0;
                loop {
                    let link = self.parents.get(&current).expect("shared block ancestry");
                    old_at += link.offset;
                    let Some(parent) = link.parent else { break };
                    current = parent;
                }
                spans.push((old_at, at, block.len));
            } else if let Contents::Branch(left, right) = &block.contents {
                pending.push((right, at + left.len));
                pending.push((left, at));
            }
        }
        spans
    }

    pub fn same_content(&self, target: &Self) -> bool
    where
        T: PartialEq,
    {
        self.same_content_by(target, |left, right| left == right)
    }

    pub fn same_content_by(&self, target: &Self, equal: impl Fn(&T, &T) -> bool) -> bool {
        if self.len() != target.len() {
            return false;
        }
        let mut at = 0;
        for (old, new, len) in self
            .shared_spans(target)
            .into_iter()
            .filter(|(old, new, _)| old == new)
            .chain(std::iter::once((self.len(), self.len(), 0)))
        {
            if !self
                .iter_from(at)
                .zip(target.iter_from(at))
                .take(old - at)
                .all(|(a, b)| equal(a, b))
            {
                return false;
            }
            at = new + len;
        }
        true
    }

    pub fn reconcile(&self, values: Vec<T>) -> Result<(Self, usize)>
    where
        T: PartialEq,
    {
        let mut first = 0;
        for (a, b) in self.iter().zip(&values) {
            if a != b {
                break;
            }
            first += 1;
        }
        if first == self.len() && first == values.len() {
            return Ok((self.clone(), 0));
        }
        let mut last = 0;
        while last < self.len() - first
            && last < values.len() - first
            && self.get(self.len() - last - 1) == values.get(values.len() - last - 1)
        {
            last += 1;
        }
        let old_end = self.len() - last;
        let new_end = values.len() - last;
        let positions: HashMap<_, _> = self
            .iter_from(first)
            .take(old_end - first)
            .enumerate()
            .map(|(offset, row)| {
                (
                    *row.ids().last().expect("row identity"),
                    (first + offset, row),
                )
            })
            .collect();
        let mut points = Vec::new();
        for (offset, row) in values[first..new_end].iter().enumerate() {
            if let Some((at, old)) = positions.get(row.ids().last().expect("row identity"))
                && *old == row
            {
                points.push((*at, first + offset));
            }
        }
        let mut tails = Vec::<usize>::new();
        let mut links = vec![None; points.len()];
        for (index, (at, _)) in points.iter().enumerate() {
            let position = tails.partition_point(|tail| points[*tail].0 < *at);
            links[index] = position.checked_sub(1).map(|position| tails[position]);
            if position == tails.len() {
                tails.push(index);
            } else {
                tails[position] = index;
            }
        }
        let retained = first + last + tails.len();
        let replaced = values.len() - retained;
        if self.len() + values.len() > 2048
            && (self.len() + values.len() - 2 * retained) * 3 > self.len() + values.len()
        {
            return Self::from_vec(values).map(|sequence| (sequence, replaced));
        }
        let mut anchors = Vec::new();
        let mut current = tails.last().copied();
        while let Some(index) = current {
            anchors.push(points[index]);
            current = links[index];
        }
        anchors.reverse();
        anchors.push((old_end, new_end));
        let mut spans = Vec::new();
        let (mut old, mut new) = (first, first);
        for (a, b) in anchors {
            if old != a || new != b {
                spans.push((old, a, new, b));
            }
            old = a + 1;
            new = b + 1;
        }
        /* Each span is a persistent splice of its own, which costs far more than a rebuild once changes
         * scatter; a render plan resets past 512 edits anyway, so no shared block would be used. */
        if spans.len() > 512 {
            return Self::from_vec(values).map(|sequence| (sequence, replaced));
        }
        let mut result = self.clone();
        for &(a, b, _, _) in spans.iter().rev() {
            if a != b {
                result.splice(a, b, Vec::new())?;
            }
        }
        for &(_, _, a, b) in &spans {
            if a != b {
                result.splice(a, a, values[a..b].to_vec())?;
            }
        }
        Ok((result, replaced))
    }

    pub fn splice(&mut self, start: usize, end: usize, values: Vec<T>) -> Result<IndexWork> {
        self.splice_many(vec![(start, end, values)])
    }

    /** Disjoint edits use base coordinates and repair the final index once. */
    pub fn splice_many(&mut self, edits: Vec<(usize, usize, Vec<T>)>) -> Result<IndexWork> {
        if edits
            .iter()
            .any(|(start, end, _)| start > end || *end > self.len())
            || edits.windows(2).any(|pair| pair[0].1 > pair[1].0)
        {
            return Err(Error::invalid("splices overlap or are outside their base"));
        }
        let mut incoming = HashSet::new();
        for (_, _, values) in &edits {
            for value in values {
                for id in value.ids() {
                    if !incoming.insert(*id) {
                        return Err(Error::invalid("duplicate identity in splice"));
                    }
                    if let Some(position) = self.position(id) {
                        let range = edits.partition_point(|(_, end, _)| *end <= position);
                        if edits
                            .get(range)
                            .is_none_or(|(start, end, _)| position < *start || position >= *end)
                        {
                            return Err(Error::invalid(
                                "splice would duplicate an existing identity",
                            ));
                        }
                    }
                }
            }
        }
        let mut candidate = self.clone();
        if edits.len() > 1 && edits.iter().all(|(start, end, _)| start == end) {
            let edit = candidate.sequence.insert_many(
                edits
                    .into_iter()
                    .map(|(at, _, values)| (at, values))
                    .collect(),
            )?;
            for id in edit.retired {
                candidate.parents.remove(&id);
            }
        } else {
            for (start, end, values) in edits.into_iter().rev() {
                let edit = candidate.sequence.splice(start, end, values)?;
                for value in edit.removed.iter() {
                    for id in value.ids() {
                        candidate.locations.remove(id);
                    }
                }
                for id in edit.retired {
                    candidate.parents.remove(&id);
                }
                for block in edit.removed.blocks() {
                    candidate.parents.remove(&block.id);
                }
            }
        }
        let mut work = IndexWork::default();
        let mut locations = Vec::new();
        let mut parents = Vec::new();
        let mut pending: Vec<_> = candidate
            .sequence
            .root
            .as_deref()
            .map(|root| {
                (
                    root,
                    Parent {
                        parent: None,
                        offset: 0,
                    },
                )
            })
            .into_iter()
            .collect();
        while let Some((block, parent)) = pending.pop() {
            if let Some(previous) = candidate.parents.get(&block.id).copied() {
                if previous != parent {
                    parents.push((block.id, parent));
                }
                continue;
            }
            parents.push((block.id, parent));
            work.blocks += 1;
            match &block.contents {
                Contents::Leaf(values) => {
                    for (offset, value) in values.iter().enumerate() {
                        for id in value.ids() {
                            locations.push((
                                *id,
                                Location {
                                    block: block.id,
                                    offset,
                                },
                            ));
                            work.locations += 1;
                        }
                    }
                }
                Contents::Branch(left, right) => {
                    pending.push((
                        right,
                        Parent {
                            parent: Some(block.id),
                            offset: left.len,
                        },
                    ));
                    pending.push((
                        left,
                        Parent {
                            parent: Some(block.id),
                            offset: 0,
                        },
                    ));
                }
            }
        }
        locations.sort_unstable_by_key(|(id, _)| *id);
        candidate.locations.extend_sorted(locations)?;
        parents.sort_unstable_by_key(|(id, _)| *id);
        candidate.parents.extend_sorted(parents)?;
        *self = candidate;
        Ok(work)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_reconcile_keeps_content_whether_it_splices_or_rebuilds() {
        let budget = super::super::super::memory::Budget::new(usize::MAX);
        let _guard = budget.enter();
        let all: Vec<NodeId> = (1..=4_000).map(NodeId).collect();
        /* Ten single-row spans splice; a thousand rebuild without reaching the one-third rebuild. */
        for (label, every) in [("few spans", 400), ("scattered spans", 4)] {
            let kept: Vec<NodeId> = all.iter().copied().filter(|id| id.0 % every != 0).collect();
            let removed = all.len() - kept.len();
            for (from, to, replaced) in [(&all, &kept, 0), (&kept, &all, removed)] {
                let base = IndexedSequence::from_vec(from.clone()).unwrap();
                let (sequence, count) = base.reconcile(to.clone()).unwrap();
                assert_eq!(sequence.iter().copied().collect::<Vec<_>>(), *to, "{label}");
                assert_eq!(count, replaced, "{label}");
                assert!(
                    to.iter()
                        .enumerate()
                        .all(|(index, id)| sequence.position(id) == Some(index)),
                    "{label}: positions"
                );
            }
        }
    }

    #[test]
    fn t_dense_locations_share_pages_and_release_their_budget() {
        let budget = super::super::super::memory::Budget::new(usize::MAX);
        let _guard = budget.enter();
        let original = IndexedSequence::from_vec((1..=50_000).map(NodeId).collect()).unwrap();
        let before = budget.used();
        assert!(
            before < 3 * 1024 * 1024,
            "dense inverse index uses {before} bytes"
        );
        let mut updated = original.clone();
        assert_eq!(before, budget.used());
        updated.splice(63, 66, vec![NodeId(60_000)]).unwrap();
        assert_eq!(original.position(&NodeId(64)), Some(63));
        assert_eq!(updated.position(&NodeId(64)), None);
        assert_eq!(updated.position(&NodeId(60_000)), Some(63));
        drop(updated);
        assert_eq!(before, budget.used());
        drop(original);
        assert_eq!(0, budget.used());
    }

    #[test]
    fn t_sparse_locations_cover_page_edges_and_preserve_old_frames() {
        let ids = [1, 63, 64, 127, 1 << 40, u64::MAX - 1, u64::MAX];
        let original = IndexedSequence::from_vec(ids.into_iter().map(NodeId).collect()).unwrap();
        let mut updated = original.clone();
        updated.splice(1, 3, vec![NodeId(62), NodeId(65)]).unwrap();
        let expected = [1, 62, 65, 127, 1 << 40, u64::MAX - 1, u64::MAX];
        for (at, id) in ids.into_iter().enumerate() {
            assert_eq!(original.position(&NodeId(id)), Some(at));
        }
        for (at, id) in expected.into_iter().enumerate() {
            assert_eq!(updated.position(&NodeId(id)), Some(at));
        }
        assert_eq!(updated.position(&NodeId(63)), None);
        assert_eq!(updated.position(&NodeId(64)), None);
    }

    #[test]
    fn t_location_page_budget_failure_keeps_the_previous_index() {
        let budget = super::super::super::memory::Budget::new(4000);
        let _guard = budget.enter();
        let location = Location {
            block: 1,
            offset: 0,
        };
        let mut locations = Locations::from_sorted(vec![(NodeId(1), location)]);
        let previous = locations.clone();
        let before = budget.used();
        let additions = (1..=32).map(|id| (NodeId(id * 64), location)).collect();
        assert!(locations.extend_sorted(additions).is_err());
        assert!(locations.0.same_version(&previous.0));
        assert_eq!(before, budget.used());
    }

    #[test]
    fn t_disjoint_edits_and_moves_preserve_base_coordinates_and_old_versions() {
        let mut expected: Vec<_> = (1..=200).map(NodeId).collect();
        let mut actual = IndexedSequence::from_vec(expected.clone()).unwrap();
        let original = actual.clone();
        let mut next_id = 201;
        for round in 0..80 {
            let old = actual.clone();
            let previous = expected.clone();
            let width = expected.len() / 4;
            let mut edits = Vec::new();
            for group in 0..3 {
                let start = group * width + round % width;
                let end = (start + round % 3).min((group + 1) * width);
                let values: Vec<_> = (0..(round + group) % 5)
                    .map(|_| {
                        let id = NodeId(next_id);
                        next_id += 1;
                        id
                    })
                    .collect();
                edits.push((start, end, values));
            }
            for (start, end, values) in edits.iter().rev() {
                expected.splice(*start..*end, values.iter().copied());
            }
            actual.splice_many(edits).unwrap();
            assert_eq!(actual.iter().copied().collect::<Vec<_>>(), expected);
            assert_eq!(old.iter().copied().collect::<Vec<_>>(), previous);
            for (at, id) in expected.iter().enumerate() {
                assert_eq!(actual.position(id), Some(at));
            }
        }
        assert_eq!(
            original.iter().copied().collect::<Vec<_>>(),
            (1..=200).map(NodeId).collect::<Vec<_>>()
        );
        let moved = expected[2];
        actual
            .splice_many(vec![(2, 3, vec![]), (12, 12, vec![moved])])
            .unwrap();
        expected.insert(12, moved);
        expected.remove(2);
        assert_eq!(actual.iter().copied().collect::<Vec<_>>(), expected);
        assert_eq!(actual.position(&moved), Some(11));
        let before = actual.clone();
        assert!(actual.splice_many(vec![(0, 0, vec![moved])]).is_err());
        assert!(actual.same_version(&before));
    }

    #[test]
    fn t_row_locations_survive_splices_without_rewriting_suffixes() {
        let old = IndexedSequence::from_vec((1..=50_000).map(NodeId).collect()).unwrap();
        let mut next = old.clone();
        let work = next.splice(0, 0, vec![NodeId(60_000)]).unwrap();
        assert!(work.blocks < 40);
        assert!(
            work.locations <= 65,
            "only the insertion boundary may relocate: {}",
            work.locations
        );
        for id in [1, 25_000, 50_000] {
            assert_eq!(old.position(&NodeId(id)), Some(id as usize - 1));
            assert_eq!(next.position(&NodeId(id)), Some(id as usize));
        }
        next.splice(10, 100, vec![NodeId(70_000)]).unwrap();
        assert!(next.position(&NodeId(10)).is_none());
        assert_eq!(next.position(&NodeId(100)), Some(11));
        assert_eq!(next.position(&NodeId(70_000)), Some(10));
    }

    #[test]
    fn t_bulk_insertions_cross_blocks_and_share_base_positions() {
        for size in [0, 4096] {
            let mut expected: Vec<_> = (1..=size).map(NodeId).collect();
            let mut actual = IndexedSequence::from_vec(expected.clone()).unwrap();
            let old = actual.clone();
            let mut next = 10_000;
            let edits: Vec<_> = [
                (0, 130),
                (size / 4, 1),
                (size / 4, 2),
                (size / 2, 1024),
                (size, 200),
            ]
            .into_iter()
            .map(|(at, count)| {
                let rows = (0..count)
                    .map(|_| {
                        next += 1;
                        NodeId(next)
                    })
                    .collect::<Vec<_>>();
                (at as usize, at as usize, rows)
            })
            .collect();
            for (start, end, rows) in edits.iter().rev() {
                expected.splice(*start..*end, rows.iter().copied());
            }
            actual.splice_many(edits).unwrap();
            assert_eq!(actual.iter().copied().collect::<Vec<_>>(), expected);
            assert_eq!(
                old.iter().copied().collect::<Vec<_>>(),
                (1..=size).map(NodeId).collect::<Vec<_>>()
            );
            for (index, id) in expected.iter().enumerate() {
                assert_eq!(actual.position(id), Some(index));
            }
        }
    }

    #[test]
    fn t_random_changes_preserve_exact_inverse_mapping() {
        let mut values: Vec<_> = (1..=300).map(NodeId).collect();
        let mut actual = IndexedSequence::from_vec(values.clone()).unwrap();
        let mut seed = 73u64;
        let mut identity = 301;
        for _ in 0..500 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let start = (seed >> 32) as usize % (values.len() + 1);
            let end = (start + (seed as usize % 7)).min(values.len());
            let insert: Vec<_> = (0..seed as usize % 5)
                .map(|_| {
                    identity += 1;
                    NodeId(identity)
                })
                .collect();
            actual.splice(start, end, insert.clone()).unwrap();
            values.splice(start..end, insert);
            assert_eq!(actual.iter().copied().collect::<Vec<_>>(), values);
            let mut offsets = HashMap::new();
            for (index, id) in values.iter().enumerate() {
                assert_eq!(actual.position(id), Some(index));
                assert_eq!(actual.position_cached(id, &mut offsets), Some(index));
                assert_eq!(actual.lookup(*id), Some(id));
            }
        }
        let previous = actual.clone();
        if let Some(&id) = values.first() {
            assert!(actual.splice(actual.len(), actual.len(), vec![id]).is_err());
            assert!(actual.same_version(&previous));
        }
    }
}
