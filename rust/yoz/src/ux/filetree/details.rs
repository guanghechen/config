use super::{Entry, Filetree, Kind, Request, Resource, resource};
use crate::ux::treeview::{Error, memory::Charge};
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone)]
pub struct Details {
    pub path: PathBuf,
    pub size: u64,
    pub permissions: String,
    pub mode: u32,
    pub modified: Option<String>,
    pub accessed: Option<String>,
    pub created: Option<String>,
    _memory: Arc<Charge>,
}

fn timestamp(value: std::io::Result<SystemTime>) -> Option<String> {
    let value = value.ok()?;
    let nanos = match value.duration_since(UNIX_EPOCH) {
        Ok(value) => value.as_nanos() as i128,
        Err(value) => -(value.duration().as_nanos() as i128),
    };
    time::OffsetDateTime::from_unix_timestamp_nanos(nanos)
        .ok()?
        .format(&time::format_description::well_known::Rfc3339)
        .ok()
}

impl Filetree {
    pub fn details(&self, resource: Resource) -> Request<Details> {
        if resource.source.identity() != self.source().identity() {
            return Request::ready(Err(Error::invalid("resource belongs to another Filetree")));
        }
        let memory = self.data().memory();
        Request::run(move || {
            let _guard = memory.enter();
            let path = resource.path()?;
            let charge = Arc::new(Charge::new(path.as_os_str().len() * 2 + 2048));
            memory.check()?;
            let mut chain = Some(resource.node);
            while let Some(node) = chain {
                let expected = resource::entry(&resource.source, node)?;
                let path = resource::path(&resource.source, node)?;
                let current = Entry::read(&path)
                    .map_err(|error| resource::io_error("inspect resource details", error))?;
                if expected.identity != current.identity
                    || expected.kind != current.kind
                    || expected.link != current.link
                    || expected.kind == Kind::Link && expected.target != current.target
                {
                    return Err(Error::stale(
                        "resource identity changed before details query",
                    ));
                }
                chain = resource.source.node(node).and_then(|node| node.parent);
            }
            let metadata = std::fs::symlink_metadata(&path)
                .map_err(|error| resource::io_error("read resource details", error))?;
            let current = Entry::from_metadata(&path, &metadata)
                .map_err(|error| resource::io_error("decode resource details", error))?;
            let expected = resource.entry()?;
            if current.identity != expected.identity
                || current.kind != expected.kind
                || current.link != expected.link
            {
                return Err(Error::stale("resource changed during details query"));
            }
            #[cfg(unix)]
            let permissions = {
                let mut value = String::with_capacity(9);
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
                    value.push(if current.mode & mask != 0 {
                        symbol
                    } else {
                        '-'
                    });
                }
                value
            };
            #[cfg(windows)]
            let permissions = if metadata.permissions().readonly() {
                "read only"
            } else {
                "read/write"
            }
            .to_owned();
            Ok(Details {
                path,
                size: metadata.len(),
                permissions,
                mode: current.mode,
                modified: timestamp(metadata.modified()),
                accessed: timestamp(metadata.accessed()),
                created: timestamp(metadata.created()),
                _memory: charge,
            })
        })
    }
}
