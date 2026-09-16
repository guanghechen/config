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
            root: &Link<K, V>,
            key: K,
            value: Arc<Stored<V>>,
        ) -> Arc<Entry<K, V>> {
            let Some(node) = root else {
                return entry(key, value, None, None);
            };
            let updated = match key.cmp(&node.key) {
                Ordering::Less => entry(
                    node.key.clone(),
                    node.value.clone(),
                    Some(put(&node.left, key, value)),
                    node.right.clone(),
                ),
                Ordering::Greater => entry(
                    node.key.clone(),
                    node.value.clone(),
                    node.left.clone(),
                    Some(put(&node.right, key, value)),
                ),
                Ordering::Equal => entry(key, value, node.left.clone(), node.right.clone()),
            };
            balance(updated)
        }
        self.root = Some(put(&self.root, key, value));
    }

    pub fn remove(&mut self, key: &K) -> bool {
        fn take<K: Ord + Clone, V>(root: &Link<K, V>, key: &K) -> (Link<K, V>, bool) {
            let Some(node) = root else {
                return (None, false);
            };
            let updated = match key.cmp(&node.key) {
                Ordering::Less => {
                    let (left, found) = take(&node.left, key);
                    if !found {
                        return (root.clone(), false);
                    }
                    entry(
                        node.key.clone(),
                        node.value.clone(),
                        left,
                        node.right.clone(),
                    )
                }
                Ordering::Greater => {
                    let (right, found) = take(&node.right, key);
                    if !found {
                        return (root.clone(), false);
                    }
                    entry(
                        node.key.clone(),
                        node.value.clone(),
                        node.left.clone(),
                        right,
                    )
                }
                Ordering::Equal => {
                    if node.left.is_none() {
                        return (node.right.clone(), true);
                    }
                    let Some(mut next) = node.right.as_deref() else {
                        return (node.left.clone(), true);
                    };
                    while let Some(left) = next.left.as_deref() {
                        next = left;
                    }
                    let (right, _) = take(&node.right, &next.key);
                    entry(
                        next.key.clone(),
                        next.value.clone(),
                        node.left.clone(),
                        right,
                    )
                }
            };
            (Some(balance(updated)), true)
        }
        let (root, removed) = take(&self.root, key);
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
