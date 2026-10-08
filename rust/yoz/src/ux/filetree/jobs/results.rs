use super::*;
use std::ffi::OsStr;

#[cfg(test)]
mod tests;

pub(super) struct Parents {
    source: PathBuf,
    target: Option<PathBuf>,
    origin: Option<Arc<walk::Origin>>,
    _memory: Reservation,
}

pub(super) struct Details {
    pub source: PathBuf,
    pub target: Option<PathBuf>,
    pub source_physical: Option<PathBuf>,
    pub target_physical: Option<PathBuf>,
    pub error: Option<Error>,
    pub error_kind: Option<String>,
    pub os_code: Option<i32>,
    pub sync_error: Option<Error>,
    pub _path_memory: Option<Reservation>,
}

pub(super) enum Contents {
    Success {
        parents: Arc<Parents>,
        name: Box<OsStr>,
        signature: Option<walk::CapturedSignature>,
    },
    Detail {
        value: Box<Details>,
        witness: Option<Box<walk::Witness>>,
    },
}

impl ItemResult {
    pub(super) fn new(
        item: ItemId,
        node: Option<NodeId>,
        status: ItemStatus,
        value: Details,
        mut memory: Reservation,
        previous: &mut Weak<Parents>,
        witness: Option<walk::Witness>,
    ) -> Arc<Self> {
        let name = value.source.file_name();
        let contents = if status == ItemStatus::Success
            && value.error.is_none()
            && value.sync_error.is_none()
            && value.source_physical.is_none()
            && value.target_physical.is_none()
            && name.is_some()
            && value
                .target
                .as_ref()
                .is_none_or(|path| path.file_name() == name)
        {
            let name = name.expect("success basename");
            let source = value.source.parent().expect("success parent");
            let target = value.target.as_deref().and_then(Path::parent);
            let origin = witness.as_ref().map(|witness| &witness.parent);
            let parents = previous.upgrade().filter(|paths| {
                paths.source == source
                    && paths.target.as_deref() == target
                    && match (paths.origin.as_ref(), origin) {
                        (Some(a), Some(b)) => Arc::ptr_eq(a, b),
                        (None, None) => true,
                        _ => false,
                    }
            });
            let parents = parents.unwrap_or_else(|| {
                let bytes = std::mem::size_of::<Parents>()
                    + 64
                    + source.as_os_str().len() * 2
                    + target.map_or(0, |path| path.as_os_str().len() * 2);
                let parents = Arc::new(Parents {
                    source: source.to_path_buf(),
                    target: target.map(Path::to_path_buf),
                    origin: origin.cloned(),
                    _memory: memory.split(bytes),
                });
                *previous = Arc::downgrade(&parents);
                parents
            });
            /* Include Arc storage, basename allocation, result-vector spare capacity and
             * cleanup NodeIds. Compaction releases vector capacity beyond this allowance. */
            let bytes = std::mem::size_of::<Self>()
                + 32
                + 2 * std::mem::size_of::<Arc<Self>>()
                + 2 * std::mem::size_of::<NodeId>()
                + name.len()
                + witness
                    .as_ref()
                    .and_then(|witness| witness.signature.as_ref())
                    .map_or(0, walk::CapturedSignature::extra_bytes);
            memory.shrink(bytes);
            Contents::Success {
                parents,
                name: name.to_os_string().into_boxed_os_str(),
                signature: witness.and_then(|witness| witness.signature),
            }
        } else {
            let bytes = std::mem::size_of::<Self>()
                + std::mem::size_of::<Details>()
                + witness.as_ref().map_or(0, |witness| {
                    std::mem::size_of::<walk::Witness>()
                        + 32
                        + witness
                            .signature
                            .as_ref()
                            .map_or(0, walk::CapturedSignature::extra_bytes)
                })
                + 192
                + value.source.as_os_str().len() * 2
                + value
                    .target
                    .as_ref()
                    .map_or(0, |path| path.as_os_str().len() * 2)
                + value.error.as_ref().map_or(0, |error| error.message.len())
                + value
                    .sync_error
                    .as_ref()
                    .map_or(0, |error| error.message.len());
            if bytes < memory.bytes() {
                memory.shrink(bytes);
            }
            Contents::Detail {
                value: Box::new(value),
                witness: witness.map(Box::new),
            }
        };
        Arc::new(Self {
            item,
            node,
            status,
            contents,
            _memory: memory,
        })
    }

    fn details(&self) -> Option<&Details> {
        match &self.contents {
            Contents::Detail { value, .. } => Some(value),
            Contents::Success { .. } => None,
        }
    }

    pub(super) fn witness(&self) -> Option<(&Arc<walk::Origin>, &walk::CapturedSignature)> {
        match &self.contents {
            Contents::Success {
                parents,
                signature: Some(signature),
                ..
            } => Some((parents.origin.as_ref()?, signature)),
            Contents::Detail {
                witness: Some(witness),
                ..
            } => Some((&witness.parent, witness.signature.as_ref()?)),
            _ => None,
        }
    }

    /** Like Resource::path, this constructs a query value without retaining another native copy. */
    pub fn source(&self) -> PathBuf {
        match &self.contents {
            Contents::Success { parents, name, .. } => parents.source.join(name.as_ref()),
            Contents::Detail { value, .. } => value.source.clone(),
        }
    }

    pub(super) fn source_bytes(&self) -> usize {
        match &self.contents {
            Contents::Success { parents, name, .. } => {
                parents.source.as_os_str().len() + 1 + name.len()
            }
            Contents::Detail { value, .. } => value.source.as_os_str().len(),
        }
    }

    pub fn target(&self) -> Option<PathBuf> {
        match &self.contents {
            Contents::Success { parents, name, .. } => {
                parents.target.as_ref().map(|path| path.join(name.as_ref()))
            }
            Contents::Detail { value, .. } => value.target.clone(),
        }
    }

    pub fn source_physical(&self) -> Option<&Path> {
        self.details()
            .and_then(|value| value.source_physical.as_deref())
    }

    pub fn target_physical(&self) -> Option<&Path> {
        self.details()
            .and_then(|value| value.target_physical.as_deref())
    }

    pub fn error(&self) -> Option<&Error> {
        self.details().and_then(|value| value.error.as_ref())
    }

    pub fn sync_error(&self) -> Option<&Error> {
        self.details().and_then(|value| value.sync_error.as_ref())
    }

    pub fn error_kind(&self) -> Option<&str> {
        self.details().and_then(|value| value.error_kind.as_deref())
    }

    pub fn os_code(&self) -> Option<i32> {
        self.details().and_then(|value| value.os_code)
    }
}
