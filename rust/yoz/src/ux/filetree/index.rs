use super::resource;
use crate::ux::treeview::memory::Charge;
use crate::ux::treeview::storage::Map;
use crate::ux::treeview::{NodeId, Operation, Result, Source};
use std::ffi::OsStr;
use std::sync::Arc;

type Name = (Option<NodeId>, Arc<OsStr>);
struct Item {
    name: Name,
    _charge: Charge,
}

/** A lookup index for the owner's current source; paths remain parent chains in Source. */
#[derive(Clone, Default)]
pub(crate) struct Index {
    pub moving: Option<NodeId>,
    pub directories: Map<NodeId, super::FileIdentity>,
    pub links: Map<NodeId, ()>,
    names: Map<Name, NodeId>,
    nodes: Map<NodeId, Arc<Item>>,
}
impl Index {
    pub fn move_blocks(&self, source: &Source, node: NodeId) -> bool {
        self.moving
            .is_some_and(|root| source.within(root, node) || source.within(node, root))
    }
    pub fn same_watch_version(&self, other: &Self) -> bool {
        self.names.same_version(&other.names)
            && self.directories.same_version(&other.directories)
            && self.links.same_version(&other.links)
    }
    pub fn child(&self, parent: Option<NodeId>, name: &OsStr) -> Option<NodeId> {
        self.names.get(&(parent, Arc::from(name))).copied()
    }
    pub fn insert(&mut self, source: &Source, id: NodeId) -> Result<()> {
        let node = source.node(id).expect("indexed resource");
        let entry = resource::entry(source, id)?;
        if entry.kind == super::Kind::Link {
            if self.links.get(&id).is_none() {
                self.links.insert(id, ());
            }
        } else {
            self.links.remove(&id);
        }
        if entry.directory() {
            let identity = entry.target_identity().expect("directory identity");
            if self.directories.get(&id) != Some(&identity) {
                self.directories.insert(id, identity);
            }
        } else {
            self.directories.remove(&id);
        }
        if let Some(old) = self.nodes.get(&id) {
            if old.name.0 == node.parent && old.name.1.as_ref() == entry.name {
                return Ok(());
            }
            if self.names.get(&old.name) == Some(&id) {
                self.names.remove(&old.name.clone());
            }
        }
        let name = (node.parent, Arc::<OsStr>::from(entry.name));
        let item = Arc::new(Item {
            _charge: Charge::new(name.1.len() + std::mem::size_of::<Item>() + 16),
            name: name.clone(),
        });
        self.names.insert(name, id);
        self.nodes.insert(id, item);
        Ok(())
    }
    pub fn update(
        &mut self,
        before: &Source,
        after: &Source,
        operations: &[Operation],
    ) -> Result<()> {
        for operation in operations {
            let node = match operation {
                Operation::Insert { key, .. } => after.id(key),
                Operation::Update { node, .. } | Operation::Reparent { node, .. } => {
                    after.resolve(node).ok()
                }
                Operation::Remove { node } => {
                    let mut pending: Vec<_> = before.resolve(node).ok().into_iter().collect();
                    while let Some(id) = pending.pop() {
                        if let Some(node) = before.node(id) {
                            pending.extend(node.children());
                        }
                        if after.contains(id) {
                            self.insert(after, id)?;
                        } else if let Some(item) = self.nodes.get(&id).cloned() {
                            if self.names.get(&item.name) == Some(&id) {
                                self.names.remove(&item.name);
                            }
                            self.nodes.remove(&id);
                            self.directories.remove(&id);
                            self.links.remove(&id);
                        }
                    }
                    None
                }
                Operation::Reorder { .. } => None,
            };
            if let Some(id) = node {
                self.insert(after, id)?;
            }
        }
        Ok(())
    }
}
