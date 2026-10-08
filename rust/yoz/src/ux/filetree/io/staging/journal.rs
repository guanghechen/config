use super::*;
use crate::ux::filetree::memory::{Memory, Reservation};
use std::ops::{Index, IndexMut};

const CHUNK: usize = 256;

pub(super) struct Owned {
    parent: u32,
    pub name: Box<OsStr>,
    identity: [u64; 3],
    pub kind: Kind,
    live: bool,
}

impl Owned {
    pub fn parent(&self) -> Option<usize> {
        (self.parent != u32::MAX).then_some(self.parent as usize)
    }
    pub fn identity(&self) -> Option<FileIdentity> {
        self.live.then(|| FileIdentity {
            volume: self.identity[0],
            file: self.identity[1] as u128 | ((self.identity[2] as u128) << 64),
        })
    }
    pub fn set_identity(&mut self, identity: Option<FileIdentity>) {
        self.live = identity.is_some();
        if let Some(identity) = identity {
            self.identity = [
                identity.volume,
                identity.file as u64,
                (identity.file >> 64) as u64,
            ];
        }
    }
}

pub(super) struct Directory {
    pub permissions: Option<Permissions>,
    pub children: usize,
}

/** Fixed blocks avoid a full ownership-vector reallocation at the high-water mark. */
pub(super) struct Journal {
    chunks: Vec<Vec<Owned>>,
    directories: HashMap<usize, Directory>,
    len: usize,
    memory: Reservation,
}

impl Journal {
    pub fn new(memory: &Arc<Memory>) -> io::Result<Self> {
        Ok(Self {
            chunks: Vec::new(),
            directories: HashMap::new(),
            len: 0,
            memory: memory.reserve(0).map_err(io::Error::other)?,
        })
    }
    pub fn len(&self) -> usize {
        self.len
    }
    fn name_bytes(name: &OsStr) -> usize {
        name.len().next_multiple_of(16) + 16
    }

    pub fn push(&mut self, parent: Option<usize>, name: &OsStr, kind: Kind) -> io::Result<usize> {
        let parent = parent
            .map(u32::try_from)
            .transpose()
            .map_err(|_| capacity())?
            .unwrap_or(u32::MAX);
        let chunk = self.len.is_multiple_of(CHUNK);
        let bytes = Self::name_bytes(name)
            + if chunk {
                CHUNK * std::mem::size_of::<Owned>() + 112
            } else {
                0
            }
            + if kind == Kind::Directory { 160 } else { 0 };
        self.memory.grow(bytes).map_err(io::Error::other)?;
        if chunk {
            self.chunks.push(Vec::with_capacity(CHUNK));
        }
        self.chunks.last_mut().expect("journal block").push(Owned {
            parent,
            name: name.to_owned().into_boxed_os_str(),
            identity: [0; 3],
            kind,
            live: false,
        });
        let index = self.len;
        self.len += 1;
        if kind == Kind::Directory {
            self.directories.insert(
                index,
                Directory {
                    permissions: None,
                    children: 0,
                },
            );
        }
        Ok(index)
    }

    pub fn pop(&mut self) {
        let owned = self
            .chunks
            .last_mut()
            .expect("journal block")
            .pop()
            .expect("owned item");
        self.len -= 1;
        let mut bytes = Self::name_bytes(&owned.name);
        if owned.kind == Kind::Directory {
            self.directories.remove(&self.len);
            self.directories.shrink_to_fit();
            bytes += 160;
        }
        if self.chunks.last().is_some_and(Vec::is_empty) {
            self.chunks.pop();
            self.chunks.shrink_to_fit();
            bytes += CHUNK * std::mem::size_of::<Owned>() + 112;
        }
        self.memory.shrink(self.memory.bytes() - bytes);
    }

    pub fn directory(&self, index: usize) -> &Directory {
        self.directories
            .get(&index)
            .expect("owned directory metadata")
    }
    pub fn directory_mut(&mut self, index: usize) -> &mut Directory {
        self.directories
            .get_mut(&index)
            .expect("owned directory metadata")
    }
    pub fn permissions(&self, index: usize) -> Option<Permissions> {
        self.directories
            .get(&index)
            .and_then(|directory| directory.permissions.clone())
    }
}

impl Index<usize> for Journal {
    type Output = Owned;
    fn index(&self, index: usize) -> &Self::Output {
        &self.chunks[index / CHUNK][index % CHUNK]
    }
}
impl IndexMut<usize> for Journal {
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        &mut self.chunks[index / CHUNK][index % CHUNK]
    }
}
