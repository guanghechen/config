use std::collections::HashMap;
use std::ffi::OsString;
use std::path::Path;

#[derive(Default)]
struct Node {
    children: HashMap<OsString, usize>,
    value: Option<u64>,
}

/** Component paths share prefixes without making sibling names match each other. */
pub(super) struct Routes {
    nodes: Vec<Node>,
}

impl Default for Routes {
    fn default() -> Self {
        Self {
            nodes: vec![Node::default()],
        }
    }
}

impl Routes {
    pub fn insert(&mut self, path: &Path, value: u64) {
        let mut at = 0;
        for component in path.components() {
            at = match self.nodes[at].children.get(component.as_os_str()).copied() {
                Some(next) => next,
                None => {
                    let next = self.nodes.len();
                    self.nodes.push(Node::default());
                    self.nodes[at]
                        .children
                        .insert(component.as_os_str().to_owned(), next);
                    next
                }
            };
        }
        self.nodes[at].value = Some(value);
    }

    fn node(&self, path: &Path) -> Option<usize> {
        let mut at = 0;
        for component in path.components() {
            at = *self.nodes[at].children.get(component.as_os_str())?;
        }
        Some(at)
    }

    pub fn get(&self, path: &Path) -> Option<u64> {
        self.nodes[self.node(path)?].value
    }

    pub fn descendants(&self, path: &Path, mut visit: impl FnMut(u64)) {
        let Some(root) = self.node(path) else { return };
        let mut pending = vec![root];
        while let Some(at) = pending.pop() {
            let node = &self.nodes[at];
            if let Some(value) = node.value {
                visit(value);
            }
            pending.extend(node.children.values().copied());
        }
    }

    pub fn roots(&self) -> Vec<u64> {
        let mut roots = Vec::new();
        let mut pending = vec![0];
        while let Some(at) = pending.pop() {
            let node = &self.nodes[at];
            if let Some(value) = node.value {
                roots.push(value);
            } else {
                pending.extend(node.children.values().copied());
            }
        }
        roots
    }

    pub fn bytes(&self) -> usize {
        self.nodes.capacity() * std::mem::size_of::<Node>()
            + self
                .nodes
                .iter()
                .map(|node| {
                    node.children.capacity() * (std::mem::size_of::<(OsString, usize)>() + 8)
                        + node.children.keys().map(|part| part.len()).sum::<usize>()
                })
                .sum::<usize>()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    #[test]
    fn t_component_routes_separate_exact_interest_and_subtree_invalidation() {
        let mut routes = Routes::default();
        for (path, id) in [
            ("/work", 1),
            ("/work/src", 2),
            ("/work/src/deep", 3),
            ("/work/src-other", 4),
            ("/outside/lib", 5),
        ] {
            routes.insert(Path::new(path), id);
        }
        assert_eq!(routes.get(Path::new("/work/src/file")), None);
        assert_eq!(routes.get(Path::new("/work/src")), Some(2));
        let mut affected = HashSet::new();
        routes.descendants(Path::new("/work/src"), |id| {
            affected.insert(id);
        });
        assert_eq!(affected, HashSet::from([2, 3]));
        assert_eq!(
            routes.roots().into_iter().collect::<HashSet<_>>(),
            HashSet::from([1, 5])
        );
    }

    #[test]
    fn t_component_routes_are_iterative_for_deep_paths_and_preserve_bytes() {
        use std::os::unix::ffi::OsStringExt;
        let mut path = std::path::PathBuf::from("/work");
        for _ in 0..10000 {
            path.push("nested");
        }
        path.push(OsString::from_vec(vec![0xff, b'x']));
        let mut routes = Routes::default();
        routes.insert(&path, 7);
        assert_eq!(routes.get(&path), Some(7));
        let mut values = HashSet::new();
        routes.descendants(Path::new("/work"), |id| {
            values.insert(id);
        });
        assert_eq!(values, HashSet::from([7]));
        assert_eq!(routes.roots(), vec![7]);
        assert!(routes.bytes() >= path.as_os_str().len());
    }
}
