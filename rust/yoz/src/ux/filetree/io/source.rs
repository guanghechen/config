use super::{FileIdentity, Signature};
use std::fs::{File, Metadata, OpenOptions};
use std::io;
use std::path::Path;

#[cfg(all(test, any(target_os = "macos", target_os = "linux")))]
mod tests;

/** One validated source descriptor, owned only by the serial copy operation. */
pub(super) struct Input {
    pub file: File,
    pub metadata: Metadata,
}

pub(super) fn open(path: &Path, expected: &Signature) -> io::Result<Input> {
    let mut options = OpenOptions::new();
    options.read(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC | libc::O_NONBLOCK);
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::OpenOptionsExt;
        options.custom_flags(0x00200000);
    }
    let file = {
        #[cfg(test)]
        let _span =
            crate::ux::filetree::profile::span(crate::ux::filetree::profile::Stage::OpenCall);
        options.open(path)?
    };
    let metadata = {
        #[cfg(test)]
        let _span =
            crate::ux::filetree::profile::span(crate::ux::filetree::profile::Stage::Metadata);
        file.metadata()?
    };
    let same_file = metadata.is_file() && {
        #[cfg(unix)]
        {
            FileIdentity::at(path, &metadata, false)?
        }
        #[cfg(windows)]
        {
            FileIdentity::from_file(&file)?
        }
    } == expected.identity;
    if !same_file {
        return Err(io::Error::new(
            io::ErrorKind::AlreadyExists,
            "source changed before open",
        ));
    }
    Ok(Input { file, metadata })
}
