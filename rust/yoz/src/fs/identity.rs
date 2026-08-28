use same_file::Handle;
use std::io;
use std::path::Path;

pub(super) struct FileIdentity(Handle);

impl FileIdentity {
    pub(super) fn from_path(filepath: &Path) -> io::Result<Self> {
        Handle::from_path(filepath).map(Self)
    }

    pub(super) fn matches_path(&self, filepath: &Path) -> io::Result<bool> {
        Ok(self.0 == Handle::from_path(filepath)?)
    }
}
