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
    locations: Map<NodeId, Location>,
    parents: Map<u64, Parent>,
}

impl<T: IndexedValue> Default for IndexedSequence<T> {
    fn default() -> Self {
        Self {
            sequence: Sequence::default(),
            locations: Map::default(),
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
            locations: Map::from_sorted(locations),
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
        if start > end || end > self.len() {
            return Err(Error::invalid("splice is outside its base"));
        }
        let mut incoming = HashSet::new();
        for value in &values {
            for id in value.ids() {
                if !incoming.insert(*id) {
                    return Err(Error::invalid("duplicate identity in splice"));
                }
                if self
                    .position(id)
                    .is_some_and(|position| position < start || position >= end)
                {
                    return Err(Error::invalid(
                        "splice would duplicate an existing identity",
                    ));
                }
            }
        }
        let mut candidate = self.clone();
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
        let mut work = IndexWork::default();
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
                    candidate.parents.insert(block.id, parent);
                }
                continue;
            }
            candidate.parents.insert(block.id, parent);
            work.blocks += 1;
            match &block.contents {
                Contents::Leaf(values) => {
                    for (offset, value) in values.iter().enumerate() {
                        for id in value.ids() {
                            candidate.locations.insert(
                                *id,
                                Location {
                                    block: block.id,
                                    offset,
                                },
                            );
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
        *self = candidate;
        Ok(work)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
            for (index, id) in values.iter().enumerate() {
                assert_eq!(actual.position(id), Some(index));
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
