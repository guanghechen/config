use super::{Filetree, Kind, Request, resource, work};
use crate::git;
use crate::ux::treeview::memory::{Charge, Payload};
use crate::ux::treeview::storage::Map;
use crate::ux::treeview::*;
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::Arc;

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct Annotation {
    pub diagnostics: [u64; 4],
    pub git: u16,
    pub staged: bool,
    pub unstaged: bool,
}

struct GitPayload {
    value: Arc<git::Snapshot>,
    _memory: Arc<Payload>,
}
struct IgnorePayload {
    value: Arc<git::IgnoreSnapshot>,
    _memory: Arc<Payload>,
}
struct GitInput {
    revision: u64,
    root: Arc<Path>,
    physical: PathBuf,
    status: Option<Arc<GitPayload>>,
    ignored: Option<Arc<IgnorePayload>>,
    _memory: Charge,
}
struct DiagnosticInput {
    revision: u64,
    path: Option<Arc<Path>>,
    counts: [u32; 4],
    _memory: Charge,
}
#[derive(Clone)]
struct Counts {
    path: Arc<Path>,
    own: [u64; 4],
    subtree: [u64; 4],
    _memory: Arc<Charge>,
}

/** Separate sparse inputs; no filesystem nodes are created for unloaded status paths. */
#[derive(Clone, Default)]
pub(super) struct Annotations {
    pub revision: u64,
    git: Map<Arc<Path>, GitInput>,
    diagnostics: Map<(u32, u32), DiagnosticInput>,
    counts: Map<Arc<Path>, Counts>,
}

impl Annotations {
    fn has_git(&self) -> bool {
        self.git.iter().any(|(_, input)| {
            input
                .status
                .as_ref()
                .is_some_and(|status| !status.value.entries().is_empty())
        })
    }

    fn is_empty(&self) -> bool {
        self.counts.is_empty()
            && !self.has_git()
            && !self.git.iter().any(|(_, input)| {
                input
                    .ignored
                    .as_ref()
                    .is_some_and(|ignored| ignored.value.has_ignored())
            })
    }

    fn adjust(&mut self, path: &Path, counts: [u32; 4], add: bool) -> Result<()> {
        if counts == [0; 4] {
            return Ok(());
        }
        let mut current = Some(path);
        while let Some(parent) = current {
            let key: Arc<Path> = Arc::from(parent);
            let mut value = self.counts.get(&key).cloned().unwrap_or_else(|| Counts {
                path: key,
                own: [0; 4],
                subtree: [0; 4],
                _memory: Arc::new(Charge::new(parent.as_os_str().len() * 2 + 64)),
            });
            for (index, count) in counts.into_iter().enumerate() {
                let update = |previous: u64| {
                    if add {
                        previous.checked_add(u64::from(count))
                    } else {
                        previous.checked_sub(u64::from(count))
                    }
                    .ok_or_else(|| Error::limit("diagnostic aggregate capacity exceeded"))
                };
                value.subtree[index] = update(value.subtree[index])?;
                if parent == path {
                    value.own[index] = update(value.own[index])?;
                }
            }
            if value.subtree == [0; 4] {
                self.counts.remove(&value.path);
            } else {
                self.counts.insert(value.path.clone(), value);
            }
            current = parent.parent();
        }
        Ok(())
    }

    fn lookup(&self, path: &Path, directory: bool) -> Annotation {
        let key = Arc::from(path);
        let mut result = Annotation::default();
        if let Some(counts) = self.counts.get(&key) {
            result.diagnostics = if directory {
                counts.subtree
            } else {
                counts.own
            };
        }
        for (_, input) in self.git.iter() {
            let mapped = if let Ok(relative) = path.strip_prefix(&input.physical) {
                input.root.join(relative)
            } else if directory && input.physical.starts_with(path) {
                input.root.to_path_buf()
            } else {
                continue;
            };
            let Some(bytes) = git_path(&mapped) else {
                continue;
            };
            if let Some(info) = input
                .status
                .as_ref()
                .and_then(|status| status.value.lookup(&bytes, directory))
            {
                result.git |= info.codes;
                result.staged |= matches!(info.stage, Some(git::Stage::Staged | git::Stage::Mixed));
                result.unstaged |=
                    matches!(info.stage, Some(git::Stage::Unstaged | git::Stage::Mixed));
            }
            if input
                .ignored
                .as_ref()
                .is_some_and(|cache| cache.value.lookup(&bytes))
            {
                result.git |= 256;
            }
        }
        result
    }
}

fn git_path(path: &Path) -> Option<Vec<u8>> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        Some(path.as_os_str().as_bytes().to_vec())
    }
    #[cfg(not(unix))]
    {
        Some(crate::canonical_path::normalize(path.to_str()?, false).into_bytes())
    }
}

fn git_basename(path: &[u8]) -> Option<String> {
    let name = path.rsplit(|byte| *byte == b'/').next()?;
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        Some(super::display_name(std::ffi::OsStr::from_bytes(name)))
    }
    #[cfg(not(unix))]
    {
        Some(super::display_name(std::ffi::OsStr::new(
            std::str::from_utf8(name).ok()?,
        )))
    }
}

/** Missing paths retain their unresolved suffix while existing aliases are resolved by the worker. */
fn canonical_prefix(path: &Path) -> PathBuf {
    let mut prefix = path;
    let mut suffix = Vec::new();
    loop {
        match std::fs::canonicalize(prefix) {
            Ok(mut resolved) => {
                for name in suffix.into_iter().rev() {
                    resolved.push(name);
                }
                return resolved;
            }
            Err(error)
                if matches!(
                    error.kind(),
                    std::io::ErrorKind::NotFound | std::io::ErrorKind::NotADirectory
                ) => {}
            Err(_) => return path.to_path_buf(),
        }
        let Some((parent, name)) = prefix.parent().zip(prefix.file_name()) else {
            return path.to_path_buf();
        };
        suffix.push(name);
        prefix = parent;
    }
}

fn diagnostic_path(path: PathBuf) -> Result<PathBuf> {
    if !path.is_absolute() {
        return Err(Error::invalid("diagnostic path must be absolute"));
    }
    Ok(canonical_prefix(&path))
}

struct SetGit {
    tree: Filetree,
    input: GitInput,
}
impl NativeAction for SetGit {
    fn bytes(&self) -> usize {
        128
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let mut current = self
            .tree
            .annotations
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        if current
            .git
            .get(&self.input.root)
            .is_some_and(|old| old.revision >= self.input.revision)
        {
            return Err(Error::stale("Git input revision is not newer"));
        }
        if current.git.get(&self.input.root).is_none() && current.git.len() >= engine.limits.nodes {
            return Err(Error::limit("Git source capacity exceeded"));
        }
        let input = self.input;
        let mut next = current.clone();
        next.revision = next
            .revision
            .checked_add(1)
            .ok_or_else(|| Error::limit("annotation revision exhausted"))?;
        next.git.insert(input.root.clone(), input);
        engine.memory.check()?;
        *current = next;
        Ok(Reply::NoChange)
    }
}

struct SetDiagnostics {
    tree: Filetree,
    namespace: u32,
    bufnr: u32,
    input: DiagnosticInput,
}
impl NativeAction for SetDiagnostics {
    fn bytes(&self) -> usize {
        128
    }
    fn apply(self: Box<Self>, engine: &mut Engine) -> Result<Reply> {
        let mut current = self
            .tree
            .annotations
            .lock()
            .unwrap_or_else(|error| error.into_inner());
        let key = (self.namespace, self.bufnr);
        if current
            .diagnostics
            .get(&key)
            .is_some_and(|old| old.revision >= self.input.revision)
        {
            return Err(Error::stale("diagnostic input revision is not newer"));
        }
        if current.diagnostics.get(&key).is_none()
            && current.diagnostics.len() >= engine.limits.nodes
        {
            return Err(Error::limit("diagnostic source capacity exceeded"));
        }
        let mut next = current.clone();
        next.revision = next
            .revision
            .checked_add(1)
            .ok_or_else(|| Error::limit("annotation revision exhausted"))?;
        if let Some(old) = current.diagnostics.get(&key)
            && let Some(path) = &old.path
        {
            next.adjust(path, old.counts, false)?;
        }
        if let Some(path) = &self.input.path {
            next.adjust(path, self.input.counts, true)?;
        }
        /* Keep the last revision even after clearing, so an old batch cannot resurrect it. */
        next.diagnostics.insert(key, self.input);
        engine.memory.check()?;
        *current = next;
        Ok(Reply::NoChange)
    }
}

/** Worker-local resolution: only symlink prefixes need IO, shared by rows in this query. */
struct Paths<'a> {
    source: &'a Source,
    links: HashMap<NodeId, Option<Arc<Path>>>,
    parent: Option<(NodeId, PathBuf, Charge)>,
    extras: HashMap<NodeId, Annotation>,
    _memory: Vec<Charge>,
}
impl Paths<'_> {
    fn link(&mut self, node: NodeId, path: &Path) -> Result<Option<Arc<Path>>> {
        if let Some(value) = self.links.get(&node) {
            return Ok(value.clone());
        }
        let expected = resource::entry(self.source, node)?;
        let stale = || Error::new(ErrorCode::Stale, "annotation symlink identity changed");
        let failed = |operation, error: std::io::Error| {
            if matches!(
                error.kind(),
                std::io::ErrorKind::NotFound | std::io::ErrorKind::NotADirectory
            ) {
                stale()
            } else {
                resource::io_error(operation, error)
            }
        };
        let verify = || {
            let current = super::Entry::read(path)
                .map_err(|error| failed("inspect annotation symlink", error))?;
            if current.identity != expected.identity
                || current.kind != expected.kind
                || current.link != expected.link
                || current.target != expected.target
            {
                return Err(stale());
            }
            Ok(())
        };
        verify()?;
        let value = match std::fs::canonicalize(path) {
            Ok(target) => {
                let metadata = std::fs::metadata(&target)
                    .map_err(|error| failed("inspect annotation target", error))?;
                let identity = super::FileIdentity::at(&target, &metadata, true)
                    .map_err(|error| failed("identify annotation target", error))?;
                if expected.target != Some((Kind::metadata(&metadata), identity)) {
                    return Err(stale());
                }
                Some(Arc::<Path>::from(target))
            }
            Err(_) if expected.target.is_none() => None,
            Err(error) => return Err(failed("resolve annotation symlink", error)),
        };
        /* Canonicalization can race a link or an intermediate target replacement. */
        verify()?;
        self._memory.push(Charge::new(
            value
                .as_ref()
                .map_or(64, |path| path.as_os_str().len() * 2 + 64),
        ));
        self.links.insert(node, value.clone());
        Ok(value)
    }

    fn parent_path(&mut self, parent: Option<NodeId>) -> Result<PathBuf> {
        let Some(parent) = parent else {
            return Ok(PathBuf::new());
        };
        if let Some((id, path, _)) = &self.parent
            && *id == parent
        {
            return Ok(path.clone());
        }
        let mut chain = Vec::new();
        let mut current = Some(parent);
        while let Some(id) = current {
            chain.push(id);
            current = self
                .source
                .node(id)
                .ok_or_else(|| Error::missing(id))?
                .parent;
        }
        let mut path = PathBuf::new();
        for id in chain.into_iter().rev() {
            let entry = resource::entry(self.source, id)?;
            if let Some(anchor) = &entry.anchor {
                path = anchor.clone();
            } else {
                path.push(&entry.name);
            }
            if entry.kind == Kind::Link
                && let Some(target) = self.link(id, &path)?
            {
                path = target.to_path_buf();
            }
        }
        /* Sibling queries reuse one prefix; never retain a full path for every loaded node. */
        let memory = Charge::new(path.as_os_str().len() * 2 + 64);
        self.parent = Some((parent, path.clone(), memory));
        Ok(path)
    }

    fn own_annotation(
        &mut self,
        annotations: &Annotations,
        node: NodeId,
    ) -> Result<(Annotation, bool)> {
        let mut path = self.parent_path(
            self.source
                .node(node)
                .ok_or_else(|| Error::missing(node))?
                .parent,
        )?;
        let entry = resource::entry(self.source, node)?;
        if let Some(anchor) = &entry.anchor {
            path = anchor.clone();
        } else {
            path.push(&entry.name);
        }
        let mut result = annotations.lookup(&path, entry.kind == Kind::Directory);
        let mut file = entry.kind == Kind::File;
        if entry.kind == Kind::Link
            && let Some(target) = self.link(node, &path)?
        {
            let status = annotations.lookup(&target, entry.directory());
            result.git |= status.git;
            result.staged |= status.staged;
            result.unstaged |= status.unstaged;
            result.diagnostics = status.diagnostics;
            file = entry.target.is_some_and(|(kind, _)| kind == Kind::File);
        }
        crate::ux::treeview::memory::check()?;
        Ok((result, file))
    }
}

impl Paths<'_> {
    fn annotation(
        &mut self,
        annotations: &Annotations,
        node: NodeId,
    ) -> Result<(Annotation, bool)> {
        let (mut value, file) = self.own_annotation(annotations, node)?;
        if self
            .source
            .node(node)
            .is_some_and(|node| node.data.can_expand)
        {
            /* Physical inputs are stored once; each loaded logical alias contributes to its ancestors. */
            let _stack = Charge::new(self.source.len() * 16);
            let mut stack = vec![(node, false)];
            while let Some((id, visited)) = stack.pop() {
                if self.extras.contains_key(&id) {
                    continue;
                }
                let children: Vec<_> = self
                    .source
                    .node(id)
                    .expect("annotation subtree")
                    .children()
                    .collect();
                if !visited {
                    stack.push((id, true));
                    stack.extend(
                        children
                            .iter()
                            .filter(|child| {
                                self.source
                                    .node(**child)
                                    .is_some_and(|child| child.child_count() != 0)
                            })
                            .map(|child| (*child, false)),
                    );
                    continue;
                }
                let mut extra = Annotation::default();
                for child in children {
                    if let Some(nested) = self.extras.get(&child) {
                        merge(&mut extra, *nested)?;
                    }
                    if super::Entry::is_link(
                        &self
                            .source
                            .node(child)
                            .expect("annotation child")
                            .data
                            .fields,
                    ) {
                        merge(&mut extra, self.own_annotation(annotations, child)?.0)?;
                    }
                }
                self._memory.push(Charge::new(128));
                self.extras.insert(id, extra);
            }
            merge(&mut value, self.extras[&node])?;
        }
        crate::ux::treeview::memory::check()?;
        Ok((value, file))
    }
}

fn merge(target: &mut Annotation, value: Annotation) -> Result<()> {
    for (target, count) in target.diagnostics.iter_mut().zip(value.diagnostics) {
        *target = target
            .checked_add(count)
            .ok_or_else(|| Error::limit("diagnostic occurrence count overflow"))?;
    }
    target.git |= value.git;
    target.staged |= value.staged;
    target.unstaged |= value.unstaged;
    Ok(())
}

pub struct AnnotationRows {
    pub revision: u64,
    pub frame: u64,
    pub first: usize,
    pub rows: Vec<Annotation>,
    _memory: Charge,
}

#[derive(Clone, Copy)]
pub enum AnnotationKind {
    Git,
    Diagnostic,
    Error,
    Warning,
}

impl Filetree {
    pub fn annotation_revision(&self) -> u64 {
        self.annotations
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .revision
    }

    pub(crate) fn set_git(
        &self,
        root: PathBuf,
        revision: u64,
        status: Option<Arc<git::Snapshot>>,
        ignored: Option<Arc<git::IgnoreSnapshot>>,
    ) -> Request<()> {
        let memory = self.data().memory();
        let _guard = memory.enter();
        if !root.is_absolute() {
            return Request::ready(Err(Error::invalid("Git source root must be absolute")));
        }
        let status = status.map(|value| {
            Arc::new(GitPayload {
                _memory: Payload::external(value.clone(), value.retained_bytes()),
                value,
            })
        });
        let ignored = ignored.map(|value| {
            Arc::new(IgnorePayload {
                _memory: Payload::external(value.clone(), value.retained_bytes()),
                value,
            })
        });
        let reservation = Charge::new(root.as_os_str().len() * 2 + 256);
        if let Err(error) = memory.check() {
            return Request::ready(Err(error));
        }
        let tree = self.clone();
        Request::run(move || {
            let _guard = memory.enter();
            let physical = canonical_prefix(&root);
            drop(reservation);
            let input = GitInput {
                revision,
                _memory: Charge::new(
                    root.as_os_str().len() * 2 + physical.as_os_str().len() * 2 + 128,
                ),
                root: Arc::from(root),
                physical,
                status,
                ignored,
            };
            memory.check()?;
            work::wait(tree.data().submit(Action::Native(Box::new(SetGit {
                tree: tree.clone(),
                input,
            }))))?;
            Ok(())
        })
    }

    pub fn set_diagnostics(
        &self,
        namespace: u32,
        bufnr: u32,
        revision: u64,
        path: Option<PathBuf>,
        counts: [u32; 4],
    ) -> Request<()> {
        let memory = self.data().memory();
        let _guard = memory.enter();
        let reservation =
            Charge::new(path.as_ref().map_or(0, |path| path.as_os_str().len() * 2) + 128);
        if let Err(error) = memory.check() {
            return Request::ready(Err(error));
        }
        let tree = self.clone();
        Request::run(move || {
            let _guard = memory.enter();
            if path.is_none() && counts != [0; 4] {
                return Err(Error::invalid("nonempty diagnostics require a path"));
            }
            let path = path
                .map(diagnostic_path)
                .transpose()?
                .map(Arc::<Path>::from);
            drop(reservation);
            let input = DiagnosticInput {
                revision,
                counts,
                _memory: Charge::new(
                    path.as_ref().map_or(0, |path| path.as_os_str().len() * 2) + 128,
                ),
                path,
            };
            memory.check()?;
            work::wait(tree.data().submit(Action::Native(Box::new(SetDiagnostics {
                tree: tree.clone(),
                namespace,
                bufnr,
                input,
            }))))?;
            Ok(())
        })
    }

    pub fn annotations(
        &self,
        frame: Arc<Snapshot>,
        first: usize,
        last: usize,
    ) -> Request<Arc<AnnotationRows>> {
        let tree = self.clone();
        let snapshot = self
            .annotations
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .clone();
        Request::run(move || {
            let memory = tree.data().memory();
            let _guard = memory.enter();
            if frame.source().identity() != tree.source().identity()
                || first > last
                || last > frame.len()
            {
                return Err(Error::invalid("invalid Filetree annotation viewport"));
            }
            if last - first > 512 {
                return Err(Error::limit("annotation viewport exceeds 512 rows"));
            }
            let charge = Charge::new((last - first) * std::mem::size_of::<Annotation>() + 128);
            let mut paths = Paths {
                source: frame.source(),
                links: HashMap::new(),
                parent: None,
                extras: HashMap::new(),
                _memory: Vec::new(),
            };
            let rows = if snapshot.is_empty() {
                vec![Annotation::default(); last - first]
            } else {
                frame
                    .rows
                    .iter_from(first)
                    .take(last - first)
                    .map(|row| paths.annotation(&snapshot, row.id).map(|value| value.0))
                    .collect::<Result<_>>()?
            };
            memory.check()?;
            Ok(Arc::new(AnnotationRows {
                revision: snapshot.revision,
                frame: frame.id,
                first,
                rows,
                _memory: charge,
            }))
        })
    }

    pub fn next_annotation(
        &self,
        frame: Arc<Snapshot>,
        from: Option<usize>,
        kind: AnnotationKind,
        forward: bool,
    ) -> Request<Option<usize>> {
        let tree = self.clone();
        let snapshot = self
            .annotations
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .clone();
        Request::run(move || {
            let memory = tree.data().memory();
            let _guard = memory.enter();
            if frame.source().identity() != tree.source().identity()
                || from.is_some_and(|row| row >= frame.len())
            {
                return Err(Error::invalid("invalid annotation navigation frame or row"));
            }
            if frame.is_empty()
                || (matches!(kind, AnnotationKind::Git) && !snapshot.has_git())
                || (!matches!(kind, AnnotationKind::Git) && snapshot.counts.is_empty())
            {
                return Ok(None);
            }
            let mut paths = Paths {
                source: frame.source(),
                links: HashMap::new(),
                parent: None,
                extras: HashMap::new(),
                _memory: Vec::new(),
            };
            let start = from.unwrap_or(if forward { frame.len() - 1 } else { 0 });
            /* Sparse inputs can reject ordinary basenames before decoding full paths.
             * Links and Git directories still need target/subtree lookup. Untracked
             * entries may apply to descendants, so they use the general path. */
            let names: Option<HashSet<String>> = if matches!(kind, AnnotationKind::Git) {
                let size: usize = snapshot
                    .git
                    .iter()
                    .filter_map(|(_, input)| input.status.as_ref())
                    .map(|status| status.value.entries().len())
                    .sum();
                if size < frame.len() / 4 {
                    snapshot
                        .git
                        .iter()
                        .filter_map(|(_, input)| input.status.as_ref())
                        .flat_map(|status| status.value.entries().iter())
                        .map(|(path, entry)| {
                            if (entry.staged | entry.unstaged) & 2 != 0 {
                                None
                            } else {
                                git_basename(path)
                            }
                        })
                        .collect()
                } else {
                    None
                }
            } else if snapshot.counts.len() < frame.len() / 4 {
                Some({
                    snapshot
                        .counts
                        .iter()
                        .filter(|(_, counts)| counts.own != [0; 4])
                        .filter_map(|(path, _)| path.file_name().map(super::display_name))
                        .collect()
                })
            } else {
                None
            };
            let _names = Charge::new(
                names
                    .as_ref()
                    .map_or(0, |names| names.iter().map(|name| name.len() + 64).sum()),
            );
            memory.check()?;
            for offset in 1..=frame.len() {
                let at = if forward {
                    (start + offset) % frame.len()
                } else {
                    (start + frame.len() - offset) % frame.len()
                };
                let row = frame.row(at).expect("visible row");
                if let Some(names) = &names
                    && !names.contains(row.label.as_ref())
                {
                    let node = frame.source().node(row.id).expect("visible resource");
                    if !super::Entry::is_link(&node.data.fields)
                        && (!matches!(kind, AnnotationKind::Git) || !node.data.can_expand)
                    {
                        continue;
                    }
                }
                let (value, file) = paths.annotation(&snapshot, row.id)?;
                let matches = match kind {
                    AnnotationKind::Git => value.git & !256 != 0,
                    AnnotationKind::Diagnostic => file && value.diagnostics != [0; 4],
                    AnnotationKind::Error => file && value.diagnostics[0] != 0,
                    AnnotationKind::Warning => file && value.diagnostics[1] != 0,
                };
                if matches {
                    return Ok(Some(at));
                }
            }
            Ok(None)
        })
    }
}

#[cfg(test)]
mod tests;
