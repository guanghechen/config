use super::{Entry, FileIdentity};
use crate::ux::treeview::{Error, ErrorCode, NodeId, Result, Source};
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

pub(crate) fn io_error(operation: &str, error: std::io::Error) -> Error {
    Error::new(
        ErrorCode::ProviderError,
        format!(
            "{operation}: {error} (kind={:?}, os={:?})",
            error.kind(),
            error.raw_os_error()
        ),
    )
}

pub(crate) fn sequence() -> Result<u64> {
    static NEXT: AtomicU64 = AtomicU64::new(1);
    NEXT.fetch_update(Ordering::Relaxed, Ordering::Relaxed, |value| {
        value.checked_add(1)
    })
    .map_err(|_| Error::limit("Filetree occurrence identity exhausted"))
}

pub(crate) fn key() -> Result<Arc<str>> {
    sequence().map(|value| format!("ft{value}").into())
}

pub(crate) fn entry(source: &Source, node: NodeId) -> Result<Entry> {
    Entry::from_fields(
        &source
            .node(node)
            .ok_or_else(|| Error::missing(node))?
            .data
            .fields,
    )
    .map_err(|error| io_error("decode resource", error))
}

pub(crate) fn path(source: &Source, node: NodeId) -> Result<PathBuf> {
    let mut names = Vec::new();
    let mut current = node;
    let mut path = loop {
        let node = source
            .node(current)
            .ok_or_else(|| Error::missing(current))?;
        let entry = entry(source, current)?;
        if let Some(anchor) = entry.anchor {
            break anchor;
        }
        names.push(entry.name);
        current = node
            .parent
            .ok_or_else(|| Error::invalid("resource has no filesystem anchor"))?;
    };
    for name in names.into_iter().rev() {
        path.push(name);
    }
    Ok(path)
}

pub(crate) fn ancestors(source: &Source, node: NodeId) -> Result<Vec<FileIdentity>> {
    let mut result = Vec::new();
    let mut current = Some(node);
    while let Some(id) = current {
        if let Some(identity) = entry(source, id)?.target_identity() {
            result.push(identity);
        }
        current = source.node(id).and_then(|node| node.parent);
    }
    Ok(result)
}

#[derive(Clone)]
pub struct Resource {
    pub source: Arc<Source>,
    pub node: NodeId,
}

impl Resource {
    pub fn entry(&self) -> Result<Entry> {
        entry(&self.source, self.node)
    }
    pub fn path(&self) -> Result<PathBuf> {
        path(&self.source, self.node)
    }
}

/** Resolve actual spelling without following the final symlink on case-insensitive macOS volumes. */
#[cfg(target_os = "macos")]
pub(crate) fn observed_name(path: &std::path::Path) -> Result<std::ffi::OsString> {
    use std::os::fd::AsRawFd;
    use std::os::unix::ffi::OsStrExt;
    use std::os::unix::fs::OpenOptionsExt;
    let file = std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_SYMLINK | libc::O_EVTONLY)
        .open(path)
        .map_err(|error| io_error("open resource name", error))?;
    let mut bytes = [0u8; libc::PATH_MAX as usize];
    if unsafe { libc::fcntl(file.as_raw_fd(), libc::F_GETPATH, bytes.as_mut_ptr()) } == -1 {
        return Err(io_error(
            "resolve resource spelling",
            std::io::Error::last_os_error(),
        ));
    }
    let end = bytes
        .iter()
        .position(|byte| *byte == 0)
        .ok_or_else(|| Error::invalid("unterminated resource path"))?;
    let path = std::path::Path::new(std::ffi::OsStr::from_bytes(&bytes[..end]));
    Ok(path.file_name().unwrap_or(path.as_os_str()).to_owned())
}

/** Query the opened occurrence, retaining directory links and the filesystem's spelling. */
#[cfg(windows)]
pub(crate) fn observed_name(path: &std::path::Path) -> Result<std::ffi::OsString> {
    use std::os::windows::{ffi::OsStringExt, fs::OpenOptionsExt, io::AsRawHandle};
    #[link(name = "kernel32")]
    unsafe extern "system" {
        fn GetFinalPathNameByHandleW(
            handle: *mut std::ffi::c_void,
            path: *mut u16,
            length: u32,
            flags: u32,
        ) -> u32;
    }
    let file = std::fs::OpenOptions::new()
        .access_mode(0x80)
        .share_mode(7)
        .custom_flags(0x02000000 | 0x00200000)
        .open(path)
        .map_err(|error| io_error("open resource name", error))?;
    let mut name = vec![0u16; 256];
    loop {
        let length = unsafe {
            GetFinalPathNameByHandleW(
                file.as_raw_handle(),
                name.as_mut_ptr(),
                name.len() as u32,
                0,
            )
        };
        if length == 0 {
            return Err(io_error(
                "resolve resource spelling",
                std::io::Error::last_os_error(),
            ));
        }
        if (length as usize) < name.len() {
            name.truncate(length as usize);
            let path = PathBuf::from(std::ffi::OsString::from_wide(&name));
            return Ok(path.file_name().unwrap_or(path.as_os_str()).to_owned());
        }
        if length > 32768 {
            return Err(Error::limit(
                "resource spelling exceeds the Windows path limit",
            ));
        }
        name.resize(length as usize + 1, 0);
    }
}

pub(crate) fn position(
    source: &Source,
    parent: Option<NodeId>,
    entry: &Entry,
    excluded: Option<NodeId>,
) -> Result<crate::ux::treeview::Position> {
    use crate::ux::treeview::Position;
    let Some(parent) = parent.and_then(|id| source.node(id)) else {
        return Ok(Position::Last);
    };
    let key = entry.sort_key();
    let mut low = 0;
    let mut high = parent.child_count();
    while low < high {
        let middle = (low + high) / 2;
        if self::entry(source, parent.child_at(middle).expect("indexed child"))?.sort_key() < key {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    if parent.child_at(low) == excluded {
        low += 1;
    }
    Ok(parent
        .child_at(low)
        .map_or(Position::Last, |id| Position::Before(id.into())))
}

pub(crate) fn ends_children(old: &Entry, new: &Entry) -> bool {
    old.cycle != new.cycle
        || old.kind == super::Kind::Link
            && (old.target_identity() != new.target_identity()
                || (old.directory() || old.target_unknown)
                    != (new.directory() || new.target_unknown))
}

/** Destructive observations also depend on the captured child slot, including ABA changes. */
pub(crate) fn unchanged(before: &Source, current: &Source, node: NodeId, children: bool) -> bool {
    let matches = |node| {
        before
            .node(node)
            .zip(current.node(node))
            .is_some_and(|(before, current)| {
                before.parent == current.parent
                    && Arc::ptr_eq(&before.data, &current.data)
                    && (!children
                        || before.request_epoch == current.request_epoch
                            && before.subtree_revision == current.subtree_revision)
            })
    };
    if !matches(node) {
        return false;
    }
    if children {
        /* Structural revisions do not include descendant payload updates. */
        let mut stack = vec![(node, 0)];
        while let Some((id, offset)) = stack.last_mut() {
            if let Some(child) = before
                .node(*id)
                .expect("validated occurrence")
                .child_at(*offset)
            {
                *offset += 1;
                if !matches(child) {
                    return false;
                }
                stack.push((child, 0));
            } else {
                stack.pop();
            }
        }
    }
    true
}

/** Changed link targets and cycle boundaries end their old child occurrences. */
pub(crate) fn retarget_children(
    source: &Source,
    operations: Vec<crate::ux::treeview::Operation>,
) -> Result<Vec<crate::ux::treeview::Operation>> {
    use crate::ux::treeview::{Completeness, Operation};
    let mut result = Vec::with_capacity(operations.len());
    for mut operation in operations {
        if let Operation::Update { node, patch } = &mut operation {
            if let Some(fields) = &patch.fields {
                let id = source.resolve(node)?;
                let old = entry(source, id)?;
                if old.kind == super::Kind::Link
                    || old.kind == super::Kind::Directory
                        && (old.cycle || patch.can_expand == Some(false))
                {
                    let new = Entry::from_fields(fields)
                        .map_err(|error| io_error("decode resource target", error))?;
                    if ends_children(&old, &new) {
                        for child in source.node(id).expect("updated resource").children() {
                            result.push(Operation::Remove { node: child.into() });
                        }
                        patch.completeness = Some(if new.directory() || new.target_unknown {
                            Completeness::Unknown
                        } else {
                            Completeness::Complete
                        });
                    }
                }
            }
        }
        result.push(operation);
    }
    Ok(result)
}
