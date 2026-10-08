use super::super::model::{Error, Result, identity};
use std::sync::Arc;

const CAPACITY: usize = 64;

pub(super) enum Contents<T> {
    Leaf(Arc<[T]>),
    Branch(Arc<Block<T>>, Arc<Block<T>>),
}

pub(super) struct Block<T> {
    _memory: super::super::memory::Charge,
    pub id: u64,
    pub len: usize,
    pub height: u8,
    pub contents: Contents<T>,
}

pub(crate) struct Sequence<T> {
    pub(super) root: Option<Arc<Block<T>>>,
}

impl<T> Clone for Sequence<T> {
    fn clone(&self) -> Self {
        Self {
            root: self.root.clone(),
        }
    }
}

impl<T> Default for Sequence<T> {
    fn default() -> Self {
        Self { root: None }
    }
}

pub(crate) struct SequenceEdit<T> {
    pub retired: Vec<u64>,
    pub removed: Sequence<T>,
}

fn leaf<T>(values: Vec<T>) -> Result<Arc<Block<T>>> {
    Ok(Arc::new(Block {
        _memory: super::super::memory::Charge::new(
            std::mem::size_of::<Block<T>>() + 32 + values.len() * std::mem::size_of::<T>(),
        ),
        id: identity()?,
        len: values.len(),
        height: 1,
        contents: Contents::Leaf(values.into()),
    }))
}

fn branch<T>(left: Arc<Block<T>>, right: Arc<Block<T>>) -> Result<Arc<Block<T>>> {
    Ok(Arc::new(Block {
        _memory: super::super::memory::Charge::new(std::mem::size_of::<Block<T>>() + 16),
        id: identity()?,
        len: left
            .len
            .checked_add(right.len)
            .ok_or_else(|| Error::limit("row count overflow"))?,
        height: left.height.max(right.height) + 1,
        contents: Contents::Branch(left, right),
    }))
}

fn balance<T>(
    left: Arc<Block<T>>,
    right: Arc<Block<T>>,
    retired: &mut Vec<u64>,
) -> Result<Arc<Block<T>>> {
    if left.height > right.height + 1 {
        let Contents::Branch(a, b) = &left.contents else {
            unreachable!("left-heavy block")
        };
        retired.push(left.id);
        if a.height >= b.height {
            return branch(a.clone(), branch(b.clone(), right)?);
        }
        let Contents::Branch(c, d) = &b.contents else {
            unreachable!("left-right block")
        };
        retired.push(b.id);
        return branch(branch(a.clone(), c.clone())?, branch(d.clone(), right)?);
    }
    if right.height > left.height + 1 {
        let Contents::Branch(a, b) = &right.contents else {
            unreachable!("right-heavy block")
        };
        retired.push(right.id);
        if b.height >= a.height {
            return branch(branch(left, a.clone())?, b.clone());
        }
        let Contents::Branch(c, d) = &a.contents else {
            unreachable!("right-left block")
        };
        retired.push(a.id);
        return branch(branch(left, c.clone())?, branch(d.clone(), b.clone())?);
    }
    branch(left, right)
}

fn concat<T: Clone>(
    left: Option<Arc<Block<T>>>,
    right: Option<Arc<Block<T>>>,
    retired: &mut Vec<u64>,
) -> Result<Option<Arc<Block<T>>>> {
    let (left, right) = match (left, right) {
        (None, other) | (other, None) => return Ok(other),
        (Some(left), Some(right)) => (left, right),
    };
    if let (Contents::Leaf(a), Contents::Leaf(b)) = (&left.contents, &right.contents)
        && a.len() + b.len() <= CAPACITY
    {
        retired.extend([left.id, right.id]);
        return leaf(a.iter().chain(b.iter()).cloned().collect()).map(Some);
    }
    if left.height > right.height + 1 {
        let Contents::Branch(a, b) = &left.contents else {
            unreachable!("left branch")
        };
        retired.push(left.id);
        let joined =
            concat(Some(b.clone()), Some(right), retired)?.expect("nonempty concatenation");
        return balance(a.clone(), joined, retired).map(Some);
    }
    if right.height > left.height + 1 {
        let Contents::Branch(a, b) = &right.contents else {
            unreachable!("right branch")
        };
        retired.push(right.id);
        let joined = concat(Some(left), Some(a.clone()), retired)?.expect("nonempty concatenation");
        return balance(joined, b.clone(), retired).map(Some);
    }
    branch(left, right).map(Some)
}

type Split<T> = (Option<Arc<Block<T>>>, Option<Arc<Block<T>>>);

fn split<T: Clone>(
    root: Option<Arc<Block<T>>>,
    at: usize,
    retired: &mut Vec<u64>,
) -> Result<Split<T>> {
    let Some(root) = root else {
        return Ok((None, None));
    };
    if at == 0 {
        return Ok((None, Some(root)));
    }
    if at == root.len {
        return Ok((Some(root), None));
    }
    retired.push(root.id);
    match &root.contents {
        Contents::Leaf(values) => Ok((
            Some(leaf(values[..at].to_vec())?),
            Some(leaf(values[at..].to_vec())?),
        )),
        Contents::Branch(left, right) => {
            if at < left.len {
                let (a, b) = split(Some(left.clone()), at, retired)?;
                Ok((a, concat(b, Some(right.clone()), retired)?))
            } else if at > left.len {
                let (a, b) = split(Some(right.clone()), at - left.len, retired)?;
                Ok((concat(Some(left.clone()), a, retired)?, b))
            } else {
                Ok((Some(left.clone()), Some(right.clone())))
            }
        }
    }
}

impl<T: Clone> Sequence<T> {
    pub fn from_vec(values: Vec<T>) -> Result<Self> {
        fn build<T>(
            blocks: &mut impl Iterator<Item = Arc<Block<T>>>,
            count: usize,
        ) -> Result<Arc<Block<T>>> {
            if count == 1 {
                return Ok(blocks.next().expect("sized block input"));
            }
            let left = build(blocks, count / 2)?;
            let right = build(blocks, count - count / 2)?;
            branch(left, right)
        }
        let mut values = values.into_iter();
        let mut blocks = Vec::new();
        loop {
            let part: Vec<_> = values.by_ref().take(CAPACITY).collect();
            if part.is_empty() {
                break;
            }
            blocks.push(leaf(part)?);
        }
        let count = blocks.len();
        Ok(Self {
            root: if count == 0 {
                None
            } else {
                Some(build(&mut blocks.into_iter(), count)?)
            },
        })
    }

    pub fn len(&self) -> usize {
        self.root.as_ref().map_or(0, |block| block.len)
    }

    pub fn is_empty(&self) -> bool {
        self.root.is_none()
    }

    pub fn get(&self, mut index: usize) -> Option<&T> {
        let mut current = self.root.as_deref()?;
        if index >= current.len {
            return None;
        }
        loop {
            match &current.contents {
                Contents::Leaf(values) => return values.get(index),
                Contents::Branch(left, right) if index < left.len => current = left,
                Contents::Branch(left, right) => {
                    index -= left.len;
                    current = right;
                }
            }
        }
    }

    pub fn iter(&self) -> Iter<'_, T> {
        self.iter_from(0)
    }

    pub fn iter_from(&self, mut index: usize) -> Iter<'_, T> {
        let mut iterator = Iter {
            pending: Vec::new(),
            leaf: &[],
            offset: 0,
        };
        let Some(mut current) = self.root.as_deref() else {
            return iterator;
        };
        if index >= current.len {
            return iterator;
        }
        loop {
            match &current.contents {
                Contents::Leaf(values) => {
                    iterator.leaf = values;
                    iterator.offset = index;
                    return iterator;
                }
                Contents::Branch(left, right) if index < left.len => {
                    iterator.pending.push(right);
                    current = left;
                }
                Contents::Branch(left, right) => {
                    index -= left.len;
                    current = right;
                }
            }
        }
    }

    pub fn splice(&mut self, start: usize, end: usize, values: Vec<T>) -> Result<SequenceEdit<T>> {
        if start > end || end > self.len() {
            return Err(Error::invalid("sequence splice is outside its base"));
        }
        self.len()
            .checked_sub(end - start)
            .and_then(|len| len.checked_add(values.len()))
            .ok_or_else(|| Error::limit("sequence length overflow"))?;
        let mut retired = Vec::new();
        let (left, rest) = split(self.root.clone(), start, &mut retired)?;
        let (removed, right) = split(rest, end - start, &mut retired)?;
        let inserted = Self::from_vec(values)?;
        let joined = concat(left, inserted.root, &mut retired)?;
        let root = concat(joined, right, &mut retired)?;
        self.root = root;
        Ok(SequenceEdit {
            retired,
            removed: Self { root: removed },
        })
    }

    /** Visit each affected block once for sorted insertions in base coordinates. */
    pub(super) fn insert_many(&mut self, edits: Vec<(usize, Vec<T>)>) -> Result<SequenceEdit<T>> {
        if edits.iter().any(|(at, _)| *at > self.len())
            || edits.windows(2).any(|pair| pair[0].0 > pair[1].0)
        {
            return Err(Error::invalid("insertions are outside their ordered base"));
        }
        let mut edits = edits
            .into_iter()
            .filter(|(_, values)| !values.is_empty())
            .peekable();
        let mut retired = Vec::new();
        fn apply<T: Clone>(
            root: &Arc<Block<T>>,
            base: usize,
            edits: &mut std::iter::Peekable<impl Iterator<Item = (usize, Vec<T>)>>,
            retired: &mut Vec<u64>,
        ) -> Result<Arc<Block<T>>> {
            if edits.peek().is_none_or(|(at, _)| *at > base + root.len) {
                return Ok(root.clone());
            }
            match &root.contents {
                Contents::Leaf(values) => {
                    let mut combined = Vec::new();
                    let mut cursor = 0;
                    while edits.peek().is_some_and(|(at, _)| *at <= base + root.len) {
                        let (at, inserted) = edits.next().expect("pending insertion");
                        combined.extend_from_slice(&values[cursor..at - base]);
                        combined.extend(inserted);
                        cursor = at - base;
                    }
                    combined.extend_from_slice(&values[cursor..]);
                    retired.push(root.id);
                    Ok(Sequence::from_vec(combined)?
                        .root
                        .expect("nonempty insertion"))
                }
                Contents::Branch(left, right) => {
                    let a = apply(left, base, edits, retired)?;
                    let b = apply(right, base + left.len, edits, retired)?;
                    if Arc::ptr_eq(left, &a) && Arc::ptr_eq(right, &b) {
                        return Ok(root.clone());
                    }
                    retired.push(root.id);
                    Ok(concat(Some(a), Some(b), retired)?.expect("nonempty insertion"))
                }
            }
        }
        let root = match &self.root {
            Some(root) => Some(apply(root, 0, &mut edits, &mut retired)?),
            None => Self::from_vec(edits.flat_map(|(_, values)| values).collect())?.root,
        };
        self.root = root;
        Ok(SequenceEdit {
            retired,
            removed: Self::default(),
        })
    }

    pub fn same_version(&self, other: &Self) -> bool {
        match (&self.root, &other.root) {
            (None, None) => true,
            (Some(left), Some(right)) => Arc::ptr_eq(left, right),
            _ => false,
        }
    }

    pub(super) fn blocks(&self) -> Blocks<'_, T> {
        Blocks {
            pending: self.root.as_deref().into_iter().collect(),
        }
    }
}

pub(crate) struct Iter<'a, T> {
    pending: Vec<&'a Block<T>>,
    leaf: &'a [T],
    offset: usize,
}

impl<'a, T> Iterator for Iter<'a, T> {
    type Item = &'a T;

    fn next(&mut self) -> Option<Self::Item> {
        loop {
            if let Some(value) = self.leaf.get(self.offset) {
                self.offset += 1;
                return Some(value);
            }
            let mut next = self.pending.pop()?;
            loop {
                match &next.contents {
                    Contents::Leaf(values) => {
                        self.leaf = values;
                        self.offset = 0;
                        break;
                    }
                    Contents::Branch(left, right) => {
                        self.pending.push(right);
                        next = left;
                    }
                }
            }
        }
    }
}

pub(super) struct Blocks<'a, T> {
    pending: Vec<&'a Block<T>>,
}

impl<'a, T> Iterator for Blocks<'a, T> {
    type Item = &'a Block<T>;

    fn next(&mut self) -> Option<Self::Item> {
        let block = self.pending.pop()?;
        if let Contents::Branch(left, right) = &block.contents {
            self.pending.push(right);
            self.pending.push(left);
        }
        Some(block)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_repeated_middle_replacements_keep_blocks_occupied() {
        let mut rows = Sequence::from_vec((0..4096).collect::<Vec<u64>>()).unwrap();
        let mut seed = 19u64;
        for index in 0..5000 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let at = ((seed >> 32) as usize) % rows.len();
            rows.splice(at, at + 1, vec![10_000 + index]).unwrap();
        }
        let leaves = rows
            .blocks()
            .filter(|block| matches!(block.contents, Contents::Leaf(_)))
            .count();
        assert!(
            leaves <= rows.len() / 16 + 4,
            "{leaves} leaf blocks for {} rows",
            rows.len()
        );
    }
    use std::collections::HashSet;

    fn check<T>(root: &Arc<Block<T>>) -> (usize, u8) {
        let (size, height) = match &root.contents {
            Contents::Leaf(values) => {
                assert!(!values.is_empty() && values.len() <= CAPACITY);
                (values.len(), 1)
            }
            Contents::Branch(left, right) => {
                let (a, b) = (check(left), check(right));
                assert!(a.1.abs_diff(b.1) <= 1);
                (a.0 + b.0, a.1.max(b.1) + 1)
            }
        };
        assert_eq!(root.len, size);
        assert_eq!(root.height, height);
        (size, height)
    }

    #[test]
    fn t_splices_match_vec_and_retained_versions_remain_readable() {
        let mut expected: Vec<u64> = (0..400).collect();
        let mut actual = Sequence::from_vec(expected.clone()).unwrap();
        let mut seed = 19u64;
        for step in 0..2000 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let start = (seed >> 32) as usize % (expected.len() + 1);
            let end = (start + (seed as usize % 8)).min(expected.len());
            let values: Vec<_> = (0..(seed as usize % 11))
                .map(|offset| step * 100 + offset as u64)
                .collect();
            let old = actual.clone();
            let previous = expected.clone();
            let edit = actual.splice(start, end, values.clone()).unwrap();
            assert_eq!(
                edit.removed.iter().copied().collect::<Vec<_>>(),
                expected[start..end]
            );
            expected.splice(start..end, values);
            assert_eq!(actual.iter().copied().collect::<Vec<_>>(), expected);
            assert_eq!(old.iter().copied().collect::<Vec<_>>(), previous);
            assert_eq!(actual.len(), expected.len());
            let live: HashSet<_> = actual.blocks().map(|block| block.id).collect();
            assert!(edit.retired.iter().all(|id| !live.contains(id)));
            for index in [0, expected.len() / 2, expected.len()] {
                assert_eq!(actual.get(index), expected.get(index));
                assert_eq!(
                    actual.iter_from(index).copied().collect::<Vec<_>>(),
                    expected[index..]
                );
            }
            if let Some(root) = &actual.root {
                check(root);
            }
        }
    }

    #[test]
    fn t_head_insertion_keeps_distant_blocks_shared() {
        let old = Sequence::from_vec((0..50_000).collect::<Vec<_>>()).unwrap();
        let before: HashSet<_> = old.blocks().map(|block| block.id).collect();
        let mut next = old.clone();
        assert!(old.same_version(&next));
        next.splice(0, 0, vec![99]).unwrap();
        let copied = next
            .blocks()
            .filter(|block| !before.contains(&block.id))
            .count();
        assert!(
            copied < 40,
            "only boundary blocks and balanced paths may change: {copied}"
        );
        assert_eq!(old.len(), 50_000);
        assert_eq!(next.len(), 50_001);
        assert!(next.splice(4, 3, vec![]).is_err());
        assert!(next.splice(0, 50_002, vec![]).is_err());
    }
}
