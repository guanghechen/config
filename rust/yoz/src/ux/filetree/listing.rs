use super::{Filetree, Kind, Request, resource};
use crate::ux::treeview::{Error, NodeId, Root, Snapshot, memory::Charge};
use std::collections::HashMap;
use std::sync::Arc;

#[derive(Clone)]
pub struct ListingRow {
    pub node: NodeId,
    pub directory: bool,
    pub permissions: String,
    pub size: String,
    pub date: String,
    pub owner: String,
    pub group: String,
}

#[derive(Clone)]
pub struct Listing {
    pub rows: Vec<ListingRow>,
    _frame: Arc<Snapshot>,
    _memory: Arc<Charge>,
}

#[cfg(unix)]
fn account_name(id: u32, group: bool) -> String {
    use std::ffi::CStr;
    let mut buffer = vec![0u8; 16384];
    loop {
        let mut found_user = std::ptr::null_mut();
        let mut found_group = std::ptr::null_mut();
        let mut user = std::mem::MaybeUninit::<libc::passwd>::uninit();
        let mut record = std::mem::MaybeUninit::<libc::group>::uninit();
        let code = unsafe {
            if group {
                libc::getgrgid_r(
                    id,
                    record.as_mut_ptr(),
                    buffer.as_mut_ptr().cast(),
                    buffer.len(),
                    &mut found_group,
                )
            } else {
                libc::getpwuid_r(
                    id,
                    user.as_mut_ptr(),
                    buffer.as_mut_ptr().cast(),
                    buffer.len(),
                    &mut found_user,
                )
            }
        };
        if code == libc::ERANGE && buffer.len() < 1024 * 1024 {
            buffer.resize(buffer.len() * 2, 0);
            continue;
        }
        if code != 0
            || if group {
                found_group.is_null()
            } else {
                found_user.is_null()
            }
        {
            return id.to_string();
        }
        /* Reentrant libc calls return the name in this call's live buffer. */
        let name = unsafe {
            if group {
                record.assume_init().gr_name
            } else {
                user.assume_init().pw_name
            }
        };
        return unsafe { CStr::from_ptr(name) }
            .to_string_lossy()
            .into_owned();
    }
}

#[cfg(not(unix))]
fn account_name(id: u32, _group: bool) -> String {
    id.to_string()
}

fn size(value: u64) -> String {
    let mut amount = value as f64;
    let mut unit = "B";
    for next in ["KB", "MB", "GB", "TB"] {
        if amount < 1024.0 {
            break;
        }
        amount /= 1024.0;
        unit = next;
    }
    let number = format!("{amount:.2}");
    format!(
        "{}{unit}",
        number.trim_end_matches('0').trim_end_matches('.')
    )
}

impl Filetree {
    /** Format only the viewport's captured metadata; never rescan or stat directory contents. */
    pub fn listing(
        &self,
        frame: Arc<Snapshot>,
        first: usize,
        last: usize,
        parent_context: bool,
    ) -> Request<Listing> {
        if frame.source().identity() != self.source().identity()
            || first > last
            || last > frame.len()
            || last - first > 512
        {
            return Request::ready(Err(Error::invalid("invalid Filetree listing viewport")));
        }
        let memory = self.data().memory();
        Request::run(move || {
            let _guard = memory.enter();
            let charge = Arc::new(Charge::new((last - first) * 4096 + 1024 * 1024));
            memory.check()?;
            let mut owners = HashMap::new();
            let mut groups = HashMap::new();
            let mut rows = Vec::with_capacity(last - first);
            for row in first..last {
                let node = frame
                    .row(row)
                    .ok_or_else(|| Error::invalid("missing listing row"))?
                    .id;
                let subject = if parent_context && frame.root() == &Root::ChildrenOf(node) {
                    frame
                        .source()
                        .node(node)
                        .and_then(|node| node.parent)
                        .unwrap_or(node)
                } else {
                    node
                };
                let entry = resource::entry(frame.source(), subject)?;
                let mut permissions = String::with_capacity(10);
                permissions.push(match entry.kind {
                    Kind::Directory => 'd',
                    Kind::Link => 'l',
                    _ => '-',
                });
                #[cfg(unix)]
                for (mask, symbol) in [
                    (0o400, 'r'),
                    (0o200, 'w'),
                    (0o100, 'x'),
                    (0o040, 'r'),
                    (0o020, 'w'),
                    (0o010, 'x'),
                    (0o004, 'r'),
                    (0o002, 'w'),
                    (0o001, 'x'),
                ] {
                    permissions.push(if entry.mode & mask != 0 { symbol } else { '-' });
                }
                #[cfg(windows)]
                permissions.push_str(if entry.mode & 1 != 0 { "r--" } else { "rw-" });
                let date = entry
                    .modified
                    .and_then(|nanos| time::OffsetDateTime::from_unix_timestamp_nanos(nanos).ok())
                    .and_then(|timestamp| {
                        let offset = time::UtcOffset::local_offset_at(timestamp)
                            .unwrap_or(time::UtcOffset::UTC);
                        timestamp
                            .to_offset(offset)
                            .format(time::macros::format_description!(
                                "[month repr:short] [day padding:space] [hour]:[minute]"
                            ))
                            .ok()
                    })
                    .unwrap_or_default();
                rows.push(ListingRow {
                    node,
                    directory: entry.directory(),
                    permissions,
                    size: size(entry.size),
                    date,
                    owner: owners
                        .entry(entry.uid)
                        .or_insert_with(|| account_name(entry.uid, false))
                        .clone(),
                    group: groups
                        .entry(entry.gid)
                        .or_insert_with(|| account_name(entry.gid, true))
                        .clone(),
                });
            }
            Ok(Listing {
                rows,
                _frame: frame,
                _memory: charge,
            })
        })
    }
}
