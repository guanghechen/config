use super::super::memory::Charge;
use std::cmp::Ordering;
use std::sync::Arc;

pub(crate) struct Stored<V> {
    value: V,
    memory: Charge,
}
impl<V> std::ops::Deref for Stored<V> {
    type Target = V;
    fn deref(&self) -> &V {
        &self.value
    }
}
impl<V> Stored<V> {
    fn new(value: V) -> Arc<Self> {
        Arc::new(Self {
            value,
            memory: Charge::new(std::mem::size_of::<Self>() + 16),
        })
    }
}

type Link<K, V> = Option<Arc<Entry<K, V>>>;

struct Entry<K, V> {
    key: K,
    value: Arc<Stored<V>>,
    left: Link<K, V>,
    right: Link<K, V>,
    height: u8,
    len: usize,
}

impl<K, V> Drop for Entry<K, V> {
    fn drop(&mut self) {
        if let Some(budget) = &self.value.memory.budget {
            budget.remove(std::mem::size_of::<Self>() + 16);
        }
    }
}

/** Persistent AVL index. A version owns one root; values and untouched paths are shared. */
pub(crate) struct Map<K, V> {
    root: Link<K, V>,
}

impl<K, V> Clone for Map<K, V> {
    fn clone(&self) -> Self {
        Self {
            root: self.root.clone(),
        }
    }
}

impl<K, V> Default for Map<K, V> {
    fn default() -> Self {
        Self { root: None }
    }
}

fn height<K, V>(root: &Link<K, V>) -> u8 {
    root.as_ref().map_or(0, |entry| entry.height)
}

fn len<K, V>(root: &Link<K, V>) -> usize {
    root.as_ref().map_or(0, |entry| entry.len)
}

fn entry<K, V>(
    key: K,
    value: Arc<Stored<V>>,
    left: Link<K, V>,
    right: Link<K, V>,
) -> Arc<Entry<K, V>> {
    if let Some(budget) = &value.memory.budget {
        budget.add(std::mem::size_of::<Entry<K, V>>() + 16);
    }
    Arc::new(Entry {
        key,
        value,
        height: height(&left).max(height(&right)) + 1,
        len: len(&left) + len(&right) + 1,
        left,
        right,
    })
}

fn balance<K: Clone, V>(root: Arc<Entry<K, V>>) -> Arc<Entry<K, V>> {
    let difference = i16::from(height(&root.left)) - i16::from(height(&root.right));
    if difference > 1 {
        let left = root.left.as_ref().expect("left-heavy AVL node");
        if height(&left.left) >= height(&left.right) {
            let right = entry(
                root.key.clone(),
                root.value.clone(),
                left.right.clone(),
                root.right.clone(),
            );
            return entry(
                left.key.clone(),
                left.value.clone(),
                left.left.clone(),
                Some(right),
            );
        }
        let middle = left.right.as_ref().expect("left-right AVL node");
        let a = entry(
            left.key.clone(),
            left.value.clone(),
            left.left.clone(),
            middle.left.clone(),
        );
        let b = entry(
            root.key.clone(),
            root.value.clone(),
            middle.right.clone(),
            root.right.clone(),
        );
        return entry(middle.key.clone(), middle.value.clone(), Some(a), Some(b));
    }
    if difference < -1 {
        let right = root.right.as_ref().expect("right-heavy AVL node");
        if height(&right.right) >= height(&right.left) {
            let left = entry(
                root.key.clone(),
                root.value.clone(),
                root.left.clone(),
                right.left.clone(),
            );
            return entry(
                right.key.clone(),
                right.value.clone(),
                Some(left),
                right.right.clone(),
            );
        }
        let middle = right.left.as_ref().expect("right-left AVL node");
        let a = entry(
            root.key.clone(),
            root.value.clone(),
            root.left.clone(),
            middle.left.clone(),
        );
        let b = entry(
            right.key.clone(),
            right.value.clone(),
            middle.right.clone(),
            right.right.clone(),
        );
        return entry(middle.key.clone(), middle.value.clone(), Some(a), Some(b));
    }
    root
}

impl<K: Ord + Clone, V> Map<K, V> {
    pub fn len(&self) -> usize {
        len(&self.root)
    }

    pub fn is_empty(&self) -> bool {
        self.root.is_none()
    }

    pub fn get(&self, key: &K) -> Option<&V> {
        self.find(key).map(|entry| &entry.value.value)
    }

    #[cfg(test)]
    pub fn get_arc(&self, key: &K) -> Option<Arc<Stored<V>>> {
        self.find(key).map(|entry| entry.value.clone())
    }

    fn find(&self, key: &K) -> Option<&Entry<K, V>> {
        let mut current = self.root.as_deref();
        while let Some(entry) = current {
            current = match key.cmp(&entry.key) {
                Ordering::Less => entry.left.as_deref(),
                Ordering::Greater => entry.right.as_deref(),
                Ordering::Equal => return Some(entry),
            };
        }
        None
    }

    pub fn changed_keys(&self, other: &Self) -> Vec<K> {
        if self.same_version(other) {
            return Vec::new();
        }
        fn walk<K: Ord + Clone, V>(
            from: &Map<K, V>,
            into: &Map<K, V>,
            additions: bool,
            keys: &mut Vec<K>,
        ) {
            let mut stack: Vec<_> = from.root.as_deref().into_iter().collect();
            while let Some(entry) = stack.pop() {
                let peer = into.find(&entry.key);
                if peer.is_some_and(|peer| std::ptr::eq(entry, peer)) {
                    continue;
                }
                if peer.is_none()
                    || (!additions
                        && peer.is_some_and(|peer| !Arc::ptr_eq(&entry.value, &peer.value)))
                {
                    keys.push(entry.key.clone());
                }
                stack.extend(entry.right.as_deref());
                stack.extend(entry.left.as_deref());
            }
        }
        let mut keys = Vec::new();
        walk(self, other, false, &mut keys);
        walk(other, self, true, &mut keys);
        keys
    }

    pub fn insert(&mut self, key: K, value: V) {
        self.insert_arc(key, Stored::new(value));
    }

    pub fn insert_arc(&mut self, key: K, value: Arc<Stored<V>>) {
        fn put<K: Ord + Clone, V>(
            root: Link<K, V>,
            key: K,
            value: Arc<Stored<V>>,
        ) -> Arc<Entry<K, V>> {
            let Some(mut node) = root else {
                return entry(key, value, None, None);
            };
            let order = key.cmp(&node.key);
            if order == Ordering::Equal {
                return entry(key, value, node.left.clone(), node.right.clone());
            }
            /* A batch's private index paths need no new allocation until shared again.
             * Snapshot roots and every shared descendant still use copy-on-write. */
            if Arc::get_mut(&mut node).is_none() {
                node = entry(
                    node.key.clone(),
                    node.value.clone(),
                    node.left.clone(),
                    node.right.clone(),
                );
            }
            let mutable = Arc::get_mut(&mut node).expect("private index path");
            if order == Ordering::Less {
                mutable.left = Some(put(mutable.left.take(), key, value));
            } else {
                mutable.right = Some(put(mutable.right.take(), key, value));
            }
            mutable.height = height(&mutable.left).max(height(&mutable.right)) + 1;
            mutable.len = len(&mutable.left) + len(&mutable.right) + 1;
            balance(node)
        }
        self.root = Some(put(self.root.take(), key, value));
    }

    /** A sorted batch visits shared index paths once, including replacements and new keys. */
    pub fn extend_sorted(&mut self, values: Vec<(K, V)>) -> super::super::model::Result<()> {
        fn join<K: Clone, V>(
            key: K,
            value: Arc<Stored<V>>,
            left: Link<K, V>,
            right: Link<K, V>,
        ) -> Arc<Entry<K, V>> {
            if height(&left) > height(&right) + 1 {
                let node = left.expect("left branch");
                let joined = join(key, value, node.right.clone(), right);
                return balance(entry(
                    node.key.clone(),
                    node.value.clone(),
                    node.left.clone(),
                    Some(joined),
                ));
            }
            if height(&right) > height(&left) + 1 {
                let node = right.expect("right branch");
                let joined = join(key, value, left, node.left.clone());
                return balance(entry(
                    node.key.clone(),
                    node.value.clone(),
                    Some(joined),
                    node.right.clone(),
                ));
            }
            entry(key, value, left, right)
        }
        fn merge<K: Ord + Clone, V>(
            root: Link<K, V>,
            values: &mut std::vec::IntoIter<(K, V)>,
            size: usize,
        ) -> Link<K, V> {
            if size == 0 {
                return root;
            }
            let Some(node) = root else {
                let middle = size / 2;
                let left = merge(None, values, middle);
                let (key, value) = values.next().expect("sized sorted batch");
                let right = merge(None, values, size - middle - 1);
                return Some(entry(key, Stored::new(value), left, right));
            };
            let split = values.as_slice()[..size].partition_point(|(key, _)| *key < node.key);
            let equal = split < size && values.as_slice()[split].0 == node.key;
            let left = merge(node.left.clone(), values, split);
            let (key, value) = if equal {
                let (key, value) = values.next().expect("matching batch key");
                (key, Stored::new(value))
            } else {
                (node.key.clone(), node.value.clone())
            };
            let right = merge(
                node.right.clone(),
                values,
                size - split - usize::from(equal),
            );
            Some(join(key, value, left, right))
        }
        debug_assert!(values.windows(2).all(|pair| pair[0].0 < pair[1].0));
        let _input = Charge::new(values.capacity() * std::mem::size_of::<(K, V)>());
        super::super::memory::check()?;
        let size = values.len();
        let root = merge(self.root.clone(), &mut values.into_iter(), size);
        super::super::memory::check()?;
        self.root = root;
        Ok(())
    }

    pub fn remove(&mut self, key: &K) -> bool {
        fn take<K: Ord + Clone, V>(root: Link<K, V>, key: &K) -> (Link<K, V>, bool) {
            let Some(mut node) = root else {
                return (None, false);
            };
            let order = key.cmp(&node.key);
            if order == Ordering::Equal {
                if node.left.is_none() {
                    return (node.right.clone(), true);
                }
                let Some(mut next) = node.right.as_deref() else {
                    return (node.left.clone(), true);
                };
                while let Some(left) = next.left.as_deref() {
                    next = left;
                }
                let key = next.key.clone();
                let value = next.value.clone();
                let (right, _) = take(node.right.clone(), &key);
                return (
                    Some(balance(entry(key, value, node.left.clone(), right))),
                    true,
                );
            }
            if Arc::get_mut(&mut node).is_none() {
                node = entry(
                    node.key.clone(),
                    node.value.clone(),
                    node.left.clone(),
                    node.right.clone(),
                );
            }
            let mutable = Arc::get_mut(&mut node).expect("private index path");
            let branch = if order == Ordering::Less {
                &mut mutable.left
            } else {
                &mut mutable.right
            };
            let (updated, found) = take(branch.take(), key);
            *branch = updated;
            mutable.height = height(&mutable.left).max(height(&mutable.right)) + 1;
            mutable.len = len(&mutable.left) + len(&mutable.right) + 1;
            (Some(balance(node)), found)
        }
        /* Preserve version identity for a no-op removal, as before. */
        if self.get(key).is_none() {
            return false;
        }
        let (root, removed) = take(self.root.take(), key);
        self.root = root;
        removed
    }

    pub fn iter(&self) -> Iter<'_, K, V> {
        let mut iterator = Iter { stack: Vec::new() };
        iterator.push_left(self.root.as_deref());
        iterator
    }

    pub fn last(&self) -> Option<(&K, &V)> {
        let mut current = self.root.as_deref()?;
        while let Some(right) = current.right.as_deref() {
            current = right;
        }
        Some((&current.key, &current.value))
    }

    pub fn from_sorted(values: Vec<(K, V)>) -> Self {
        fn build<K, V>(values: &mut impl Iterator<Item = (K, V)>, size: usize) -> Link<K, V> {
            if size == 0 {
                return None;
            }
            let left = build(values, size / 2);
            let (key, value) = values.next().expect("sized sorted input");
            let right = build(values, size - size / 2 - 1);
            Some(entry(key, Stored::new(value), left, right))
        }
        debug_assert!(values.windows(2).all(|pair| pair[0].0 < pair[1].0));
        let size = values.len();
        Self {
            root: build(&mut values.into_iter(), size),
        }
    }

    pub fn same_version(&self, other: &Self) -> bool {
        match (&self.root, &other.root) {
            (None, None) => true,
            (Some(left), Some(right)) => Arc::ptr_eq(left, right),
            _ => false,
        }
    }
}

pub(crate) struct Iter<'a, K, V> {
    stack: Vec<&'a Entry<K, V>>,
}

impl<'a, K, V> Iter<'a, K, V> {
    fn push_left(&mut self, mut root: Option<&'a Entry<K, V>>) {
        while let Some(entry) = root {
            self.stack.push(entry);
            root = entry.left.as_deref();
        }
    }
}

impl<'a, K, V> Iterator for Iter<'a, K, V> {
    type Item = (&'a K, &'a V);

    fn next(&mut self) -> Option<Self::Item> {
        let entry = self.stack.pop()?;
        self.push_left(entry.right.as_deref());
        Some((&entry.key, &entry.value))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    fn check<K: Ord, V>(root: &Link<K, V>) -> (usize, u8) {
        let Some(node) = root else { return (0, 0) };
        let (left_len, left_height) = check(&node.left);
        let (right_len, right_height) = check(&node.right);
        assert!(left_height.abs_diff(right_height) <= 1);
        assert_eq!(node.len, left_len + right_len + 1);
        assert_eq!(node.height, left_height.max(right_height) + 1);
        (node.len, node.height)
    }

    #[test]
    fn t_updates_match_ordered_map_and_keep_old_versions() {
        let mut actual = Map::default();
        let mut expected = BTreeMap::new();
        let mut seed = 91u64;
        for step in 0..4000 {
            let previous = actual.clone();
            let old_values: Vec<_> = previous.iter().map(|(key, value)| (*key, *value)).collect();
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            let key = (seed >> 32) % 301;
            if seed & 3 == 0 {
                assert_eq!(actual.remove(&key), expected.remove(&key).is_some());
            } else {
                actual.insert(key, step);
                expected.insert(key, step);
            }
            assert_eq!(actual.len(), expected.len());
            assert_eq!(
                actual
                    .iter()
                    .map(|(key, value)| (*key, *value))
                    .collect::<Vec<_>>(),
                expected
                    .iter()
                    .map(|(key, value)| (*key, *value))
                    .collect::<Vec<_>>()
            );
            assert_eq!(
                previous
                    .iter()
                    .map(|(key, value)| (*key, *value))
                    .collect::<Vec<_>>(),
                old_values
            );
            check(&actual.root);
        }
    }

    #[test]
    fn t_private_batches_preserve_pinned_versions_and_release_budget() {
        let budget = super::super::super::memory::Budget::new(16 * 1024 * 1024);
        let _guard = budget.enter();
        {
            let mut actual = Map::default();
            let mut expected = BTreeMap::new();
            let mut pinned = Vec::new();
            let mut seed = 718_u64;
            for batch in 0..128 {
                pinned.push((actual.clone(), expected.clone()));
                if pinned.len() > 8 {
                    pinned.remove(1);
                }
                for step in 0..64 {
                    seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
                    let key = (seed >> 32) % 501;
                    if seed & 3 == 0 {
                        assert_eq!(actual.remove(&key), expected.remove(&key).is_some());
                    } else {
                        actual.insert(key, batch * 64 + step);
                        expected.insert(key, batch * 64 + step);
                    }
                }
                check(&actual.root);
                assert_eq!(
                    actual
                        .iter()
                        .map(|(key, value)| (*key, *value))
                        .collect::<BTreeMap<_, _>>(),
                    expected
                );
                for (old, values) in &pinned {
                    check(&old.root);
                    assert_eq!(
                        old.iter()
                            .map(|(key, value)| (*key, *value))
                            .collect::<BTreeMap<_, _>>(),
                        *values
                    );
                }
            }
            budget.check().unwrap();
        }
        assert_eq!(budget.used(), 0);
    }

    #[test]
    fn t_sorted_batches_balance_and_preserve_pinned_versions() {
        let budget = super::super::super::memory::Budget::new(64 * 1024 * 1024);
        let _guard = budget.enter();
        {
            let mut actual = Map::default();
            let mut expected = BTreeMap::new();
            let mut seed = 714u64;
            for round in 0..96 {
                let old = actual.clone();
                let previous = expected.clone();
                let mut changes = BTreeMap::new();
                for step in 0..[1, 64, 512, 2048][round % 4] {
                    seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
                    let key = (seed >> 32) % (256 + round as u64 * 32);
                    changes.insert(key, step);
                }
                actual
                    .extend_sorted(changes.iter().map(|(k, v)| (*k, *v)).collect())
                    .unwrap();
                expected.extend(changes);
                check(&actual.root);
                assert_eq!(
                    actual
                        .iter()
                        .map(|(k, v)| (*k, *v))
                        .collect::<BTreeMap<_, _>>(),
                    expected
                );
                assert_eq!(
                    old.iter()
                        .map(|(k, v)| (*k, *v))
                        .collect::<BTreeMap<_, _>>(),
                    previous
                );
            }
            let old = actual.clone();
            actual.extend_sorted(Vec::new()).unwrap();
            assert!(actual.same_version(&old));
            budget.check().unwrap();
        }
        assert_eq!(budget.used(), 0);
    }

    #[test]
    fn t_bulk_build_and_local_update_share_unmodified_values() {
        let original = Map::from_sorted((0..50_000).map(|key| (key, key * 2)).collect());
        let mut next = original.clone();
        assert!(original.same_version(&next));
        next.insert(7, 99);
        assert_eq!(original.get(&7), Some(&14));
        assert_eq!(next.get(&7), Some(&99));
        assert!(Arc::ptr_eq(
            &original.get_arc(&49_999).unwrap(),
            &next.get_arc(&49_999).unwrap()
        ));
        assert!(check(&next.root).1 < 25);
    }
}
