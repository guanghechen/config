use crate::ux::treeview::{Fields, NodeData, Value};
use std::collections::BTreeMap;
use std::ffi::{OsStr, OsString};
use std::fmt::Write;
use std::fs::{self, Metadata};
use std::io;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct FileIdentity {
    pub volume: u64,
    pub file: u128,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[repr(u8)]
pub enum Kind {
    File = 1,
    Directory = 2,
    Link = 3,
    Other = 4,
}

impl Kind {
    pub(crate) fn metadata(metadata: &Metadata) -> Self {
        let kind = metadata.file_type();
        if kind.is_symlink() {
            Self::Link
        } else if kind.is_dir() {
            Self::Directory
        } else if kind.is_file() {
            Self::File
        } else {
            Self::Other
        }
    }

    fn decode(value: u8) -> io::Result<Self> {
        match value {
            1 => Ok(Self::File),
            2 => Ok(Self::Directory),
            3 => Ok(Self::Link),
            4 => Ok(Self::Other),
            _ => Err(invalid("invalid file kind")),
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Entry {
    pub name: OsString,
    pub identity: FileIdentity,
    pub kind: Kind,
    pub size: u64,
    pub created: Option<i128>,
    pub modified: Option<i128>,
    pub mode: u32,
    pub uid: u32,
    pub gid: u32,
    pub link: Option<PathBuf>,
    pub target: Option<(Kind, FileIdentity)>,
    pub target_unknown: bool,
    pub cycle: bool,
    pub anchor: Option<PathBuf>,
}

fn invalid(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

fn timestamp(time: SystemTime) -> i128 {
    match time.duration_since(UNIX_EPOCH) {
        Ok(duration) => duration.as_nanos() as i128,
        Err(error) => -(error.duration().as_nanos() as i128),
    }
}

#[cfg(unix)]
fn identity(_: &Path, metadata: &Metadata, _: bool) -> io::Result<FileIdentity> {
    use std::os::unix::fs::MetadataExt;
    if metadata.ino() == 0 {
        return Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "filesystem identity unavailable",
        ));
    }
    Ok(FileIdentity {
        volume: metadata.dev(),
        file: metadata.ino() as u128,
    })
}

#[cfg(windows)]
fn identity(path: &Path, _: &Metadata, follow: bool) -> io::Result<FileIdentity> {
    use std::os::windows::fs::OpenOptionsExt;
    let file = fs::OpenOptions::new()
        .access_mode(0x80)
        .share_mode(7)
        .custom_flags(0x02000000 | if follow { 0 } else { 0x00200000 })
        .open(path)?;
    file_identity(&file)
}

#[cfg(windows)]
fn file_identity(file: &fs::File) -> io::Result<FileIdentity> {
    use std::os::windows::io::AsRawHandle;
    #[repr(C)]
    struct FileIdInfo {
        volume: u64,
        id: [u8; 16],
    }
    #[link(name = "kernel32")]
    unsafe extern "system" {
        fn GetFileInformationByHandleEx(
            handle: *mut std::ffi::c_void,
            class: i32,
            info: *mut std::ffi::c_void,
            size: u32,
        ) -> i32;
    }
    let mut info = FileIdInfo {
        volume: 0,
        id: [0; 16],
    };
    let ok = unsafe {
        GetFileInformationByHandleEx(
            file.as_raw_handle(),
            18,
            (&mut info as *mut FileIdInfo).cast(),
            std::mem::size_of::<FileIdInfo>() as u32,
        )
    };
    if ok == 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(FileIdentity {
        volume: info.volume,
        file: u128::from_le_bytes(info.id),
    })
}

impl FileIdentity {
    pub(crate) fn at(path: &Path, metadata: &Metadata, follow: bool) -> io::Result<Self> {
        identity(path, metadata, follow)
    }
    pub(crate) fn from_file(file: &fs::File) -> io::Result<Self> {
        #[cfg(unix)]
        {
            identity(Path::new(""), &file.metadata()?, false)
        }
        #[cfg(windows)]
        {
            file_identity(file)
        }
    }
}

#[cfg(unix)]
fn os_bytes(value: &OsStr) -> Vec<u8> {
    use std::os::unix::ffi::OsStrExt;
    value.as_bytes().to_vec()
}

#[cfg(windows)]
fn os_bytes(value: &OsStr) -> Vec<u8> {
    use std::os::windows::ffi::OsStrExt;
    value.encode_wide().flat_map(u16::to_le_bytes).collect()
}

#[cfg(unix)]
fn os_string(value: &[u8]) -> io::Result<OsString> {
    use std::os::unix::ffi::OsStringExt;
    Ok(OsString::from_vec(value.to_vec()))
}

#[cfg(windows)]
fn os_string(value: &[u8]) -> io::Result<OsString> {
    use std::os::windows::ffi::OsStringExt;
    if !value.len().is_multiple_of(2) {
        return Err(invalid("invalid native filename encoding"));
    }
    Ok(OsString::from_wide(
        &value
            .chunks_exact(2)
            .map(|pair| u16::from_le_bytes([pair[0], pair[1]]))
            .collect::<Vec<_>>(),
    ))
}

fn display_char(output: &mut String, ch: char) {
    match ch {
        '\\' => output.push_str("\\\\"),
        '\n' => output.push_str("\\n"),
        '\r' => output.push_str("\\r"),
        '\t' => output.push_str("\\t"),
        ch if ch.is_control()
            || matches!(ch, '\u{2028}'..='\u{202e}' | '\u{2066}'..='\u{2069}') =>
        {
            let _ = write!(output, "\\u{{{:x}}}", ch as u32);
        }
        ch => output.push(ch),
    }
}

pub fn display_name(name: &OsStr) -> String {
    let mut output = String::new();
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        let mut bytes = name.as_bytes();
        while !bytes.is_empty() {
            match std::str::from_utf8(bytes) {
                Ok(text) => {
                    for ch in text.chars() {
                        display_char(&mut output, ch);
                    }
                    break;
                }
                Err(error) => {
                    let valid = error.valid_up_to();
                    for ch in std::str::from_utf8(&bytes[..valid])
                        .expect("valid UTF-8 prefix")
                        .chars()
                    {
                        display_char(&mut output, ch);
                    }
                    let length = error.error_len().unwrap_or(bytes.len() - valid);
                    for byte in &bytes[valid..valid + length] {
                        let _ = write!(output, "\\x{byte:02x}");
                    }
                    bytes = &bytes[valid + length..];
                }
            }
        }
    }
    #[cfg(windows)]
    {
        use std::os::windows::ffi::OsStrExt;
        for ch in char::decode_utf16(name.encode_wide()) {
            match ch {
                Ok(ch) => display_char(&mut output, ch),
                Err(error) => {
                    let _ = write!(output, "\\u{{{:x}}}", error.unpaired_surrogate());
                }
            }
        }
    }
    output
}

impl Entry {
    pub fn read(path: &Path) -> io::Result<Self> {
        let metadata = fs::symlink_metadata(path)?;
        Self::from_metadata(path, &metadata)
    }

    pub fn from_metadata(path: &Path, metadata: &Metadata) -> io::Result<Self> {
        let kind = Kind::metadata(metadata);
        let link = (kind == Kind::Link)
            .then(|| fs::read_link(path))
            .transpose()?;
        let mut target_unknown = false;
        let target = if kind == Kind::Link {
            match fs::metadata(path) {
                Ok(target) => Some((Kind::metadata(&target), identity(path, &target, true)?)),
                Err(error) => {
                    target_unknown = !matches!(
                        error.kind(),
                        io::ErrorKind::NotFound | io::ErrorKind::NotADirectory
                    );
                    None
                }
            }
        } else {
            None
        };
        #[cfg(unix)]
        let (mode, uid, gid) = {
            use std::os::unix::fs::MetadataExt;
            (metadata.mode(), metadata.uid(), metadata.gid())
        };
        #[cfg(windows)]
        let (mode, uid, gid) = {
            use std::os::windows::fs::MetadataExt;
            (metadata.file_attributes(), 0, 0)
        };
        Ok(Self {
            name: path.file_name().unwrap_or(path.as_os_str()).to_owned(),
            identity: identity(path, metadata, false)?,
            kind,
            size: metadata.len(),
            created: metadata.created().ok().map(timestamp),
            modified: metadata.modified().ok().map(timestamp),
            mode,
            uid,
            gid,
            link,
            target,
            target_unknown,
            cycle: false,
            anchor: None,
        })
    }

    /** Only reuse confirmed metadata for an observation at the same logical path, never a move. */
    pub(crate) fn retain_unknown_target(&mut self, old: &Self) {
        if self.target_unknown
            && self.kind == Kind::Link
            && old.kind == Kind::Link
            && self.identity == old.identity
            && self.name == old.name
            && self.link == old.link
        {
            self.target = old.target;
            self.cycle = old.cycle;
        }
    }

    pub fn directory(&self) -> bool {
        !self.cycle
            && (self.kind == Kind::Directory
                || self.target.is_some_and(|(kind, _)| kind == Kind::Directory))
    }

    pub fn target_identity(&self) -> Option<FileIdentity> {
        if self.kind == Kind::Directory {
            Some(self.identity)
        } else {
            self.target
                .filter(|(kind, _)| *kind == Kind::Directory)
                .map(|(_, identity)| identity)
        }
    }

    pub fn sort_key(&self) -> (bool, Vec<u8>, Vec<u8>) {
        let raw = self.name.as_encoded_bytes().to_vec();
        (
            !self.directory(),
            raw.iter().map(u8::to_ascii_lowercase).collect(),
            raw,
        )
    }

    pub fn node_data(&self) -> NodeData {
        let mut fields = BTreeMap::new();
        fields.insert("filetree".to_owned(), Value::Bytes(self.encode().into()));
        NodeData {
            label: display_name(&self.name).into(),
            can_expand: self.directory() || self.target_unknown,
            foldable: self.kind == Kind::Directory,
            hidden: self.name.as_encoded_bytes().first() == Some(&b'.'),
            fields: Arc::new(fields),
            ..NodeData::default()
        }
    }

    pub(crate) fn is_link(fields: &Fields) -> bool {
        matches!(fields.get("filetree"), Some(Value::Bytes(bytes)) if bytes.starts_with(b"FT01\x03"))
    }

    pub fn from_fields(fields: &Fields) -> io::Result<Self> {
        let Some(Value::Bytes(bytes)) = fields.get("filetree") else {
            return Err(invalid("node has no Filetree resource"));
        };
        Self::decode(bytes)
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(b"FT01");
        bytes.push(self.kind as u8);
        bytes.push(u8::from(self.target_unknown) | (u8::from(self.cycle) << 1));
        put_identity(&mut bytes, self.identity);
        bytes.push(self.target.map_or(0, |(kind, _)| kind as u8));
        if let Some((_, identity)) = self.target {
            put_identity(&mut bytes, identity);
        }
        bytes.extend_from_slice(&self.size.to_le_bytes());
        bytes.extend_from_slice(&self.created.unwrap_or(i128::MIN).to_le_bytes());
        bytes.extend_from_slice(&self.modified.unwrap_or(i128::MIN).to_le_bytes());
        for value in [self.mode, self.uid, self.gid] {
            bytes.extend_from_slice(&value.to_le_bytes());
        }
        put_os(&mut bytes, &self.name);
        for path in [&self.link, &self.anchor] {
            bytes.push(u8::from(path.is_some()));
            if let Some(path) = path {
                put_os(&mut bytes, path.as_os_str());
            }
        }
        bytes
    }

    pub fn decode(bytes: &[u8]) -> io::Result<Self> {
        let mut input = Input { bytes, at: 0 };
        if input.take(4)? != b"FT01" {
            return Err(invalid("unknown Filetree resource encoding"));
        }
        let kind = Kind::decode(input.take(1)?[0])?;
        let flags = input.take(1)?[0];
        let identity = input.identity()?;
        let target = match input.take(1)?[0] {
            0 => None,
            tag => Some((Kind::decode(tag)?, input.identity()?)),
        };
        let size = u64::from_le_bytes(input.array()?);
        let created = i128::from_le_bytes(input.array()?);
        let modified = i128::from_le_bytes(input.array()?);
        let mode = u32::from_le_bytes(input.array()?);
        let uid = u32::from_le_bytes(input.array()?);
        let gid = u32::from_le_bytes(input.array()?);
        let name = input.os()?;
        let link = input.optional_path()?;
        let anchor = input.optional_path()?;
        if input.at != bytes.len() || flags & !3 != 0 {
            return Err(invalid("invalid Filetree resource tail"));
        }
        Ok(Self {
            name,
            identity,
            kind,
            size,
            created: (created != i128::MIN).then_some(created),
            modified: (modified != i128::MIN).then_some(modified),
            mode,
            uid,
            gid,
            link,
            target,
            target_unknown: flags & 1 != 0,
            cycle: flags & 2 != 0,
            anchor,
        })
    }
}

fn put_identity(bytes: &mut Vec<u8>, value: FileIdentity) {
    bytes.extend_from_slice(&value.volume.to_le_bytes());
    bytes.extend_from_slice(&value.file.to_le_bytes());
}

fn put_os(bytes: &mut Vec<u8>, value: &OsStr) {
    let raw = os_bytes(value);
    bytes.extend_from_slice(&(raw.len() as u32).to_le_bytes());
    bytes.extend_from_slice(&raw);
}

struct Input<'a> {
    bytes: &'a [u8],
    at: usize,
}

impl<'a> Input<'a> {
    fn take(&mut self, length: usize) -> io::Result<&'a [u8]> {
        let end = self
            .at
            .checked_add(length)
            .ok_or_else(|| invalid("Filetree resource length overflow"))?;
        let value = self
            .bytes
            .get(self.at..end)
            .ok_or_else(|| invalid("truncated Filetree resource"))?;
        self.at = end;
        Ok(value)
    }
    fn array<const N: usize>(&mut self) -> io::Result<[u8; N]> {
        Ok(self.take(N)?.try_into().expect("fixed-size input"))
    }
    fn identity(&mut self) -> io::Result<FileIdentity> {
        let volume = u64::from_le_bytes(self.array()?);
        let file = u128::from_le_bytes(self.array()?);
        Ok(FileIdentity { volume, file })
    }
    fn os(&mut self) -> io::Result<OsString> {
        let length = u32::from_le_bytes(self.array()?) as usize;
        os_string(self.take(length)?)
    }
    fn optional_path(&mut self) -> io::Result<Option<PathBuf>> {
        match self.take(1)?[0] {
            0 => Ok(None),
            1 => Ok(Some(self.os()?.into())),
            _ => Err(invalid("invalid optional path")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct Directory(PathBuf);

    impl Directory {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!("yoz-filetree-{}", uuid::Uuid::new_v4()));
            fs::create_dir(&path).unwrap();
            Self(path)
        }
    }

    impl Drop for Directory {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn t_names_remain_native_while_display_text_is_single_line() {
        assert_eq!(
            display_name(OsStr::new("文\n\\n\t.lua")),
            "文\\n\\\\n\\t.lua"
        );
        #[cfg(unix)]
        {
            use std::os::unix::ffi::OsStrExt;
            let name = OsStr::from_bytes(b"a\xff\n");
            assert_eq!(display_name(name), "a\\xff\\n");
            assert_eq!(os_string(&os_bytes(name)).unwrap(), name);
        }
    }

    #[test]
    fn t_resource_encoding_roundtrips_without_display_path_conversion() {
        let entry = Entry {
            name: "link".into(),
            identity: FileIdentity {
                volume: 3,
                file: u128::MAX,
            },
            kind: Kind::Link,
            size: 8,
            created: Some(-7),
            modified: Some(12),
            mode: 0o777,
            uid: 23,
            gid: 24,
            link: Some("../文\n".into()),
            target: None,
            target_unknown: false,
            cycle: false,
            anchor: None,
        };
        let bytes = entry.encode();
        assert_eq!(Entry::decode(&bytes).unwrap(), entry);
        for end in 0..bytes.len() {
            assert!(Entry::decode(&bytes[..end]).is_err());
        }
    }

    #[test]
    fn t_file_identity_survives_setting_an_older_modified_time() {
        let directory = Directory::new();
        let path = directory.0.join("file");
        let file = fs::File::create_new(&path).unwrap();
        let before = Entry::read(&path).unwrap();
        let identities = std::collections::HashSet::from([before.identity]);
        let modified = UNIX_EPOCH + std::time::Duration::from_secs(946_684_800);
        file.set_times(fs::FileTimes::new().set_modified(modified))
            .unwrap();
        let after = Entry::read(&path).unwrap();
        assert_eq!(after.modified, Some(timestamp(modified)));
        assert_eq!(before.identity, after.identity);
        assert!(identities.contains(&after.identity));
        assert_eq!(
            Entry::from_fields(&after.node_data().fields).unwrap(),
            after
        );
    }

    #[test]
    fn t_filesystem_identity_distinguishes_replacement_from_write_and_rename() {
        let directory = Directory::new();
        let path = directory.0.join("a");
        fs::write(&path, b"first").unwrap();
        let first = Entry::read(&path).unwrap();
        fs::write(&path, b"second value").unwrap();
        let written = Entry::read(&path).unwrap();
        assert_eq!(first.identity, written.identity);
        assert_ne!(first.size, written.size);
        let renamed = directory.0.join("renamed");
        fs::rename(&path, &renamed).unwrap();
        let moved = Entry::read(&renamed).unwrap();
        assert_eq!(written.identity, moved.identity);
        fs::hard_link(&renamed, &path).unwrap();
        assert_eq!(Entry::read(&path).unwrap().identity, moved.identity);
        fs::remove_file(&path).unwrap();
        fs::write(&path, b"replacement").unwrap();
        assert_ne!(Entry::read(&path).unwrap().identity, moved.identity);
        assert_eq!(
            Entry::from_fields(&moved.node_data().fields).unwrap(),
            moved
        );
    }

    #[cfg(unix)]
    #[test]
    fn t_symlink_identity_and_text_survive_target_changes() {
        use std::os::unix::fs::symlink;
        let directory = Directory::new();
        let path = directory.0.join("link");
        let target = directory.0.join("target");
        fs::create_dir(&target).unwrap();
        symlink("target", &path).unwrap();
        let linked = Entry::read(&path).unwrap();
        assert_eq!(linked.kind, Kind::Link);
        assert_eq!(linked.link.as_deref(), Some(Path::new("target")));
        assert_ne!(linked.identity, Entry::read(&target).unwrap().identity);
        assert_eq!(
            linked.target_identity(),
            Some(Entry::read(&target).unwrap().identity)
        );
        assert!(linked.directory());
        assert!(!linked.node_data().foldable);
        fs::remove_dir(&target).unwrap();
        let dangling = Entry::read(&path).unwrap();
        assert_eq!(dangling.identity, linked.identity);
        assert!(!dangling.directory());
        assert!(!dangling.target_unknown);
        assert!(dangling.target.is_none());
        fs::write(&target, b"file").unwrap();
        let file_link = Entry::read(&path).unwrap();
        assert_eq!(file_link.identity, linked.identity);
        assert_eq!(file_link.target.unwrap().0, Kind::File);
        assert!(!file_link.directory());
        let invalid_path = directory.0.join("invalid");
        symlink("target/child", &invalid_path).unwrap();
        let not_directory = Entry::read(&invalid_path).unwrap();
        assert!(!not_directory.target_unknown);
        assert!(!not_directory.node_data().can_expand);
        let mut cycle = linked;
        cycle.cycle = true;
        assert!(!cycle.node_data().can_expand);
        let encoded = cycle.encode();
        assert_eq!(Entry::decode(&encoded).unwrap(), cycle);
    }
}
