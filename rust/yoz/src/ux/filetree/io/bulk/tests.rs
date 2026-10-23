use super::*;
use crate::test_support::TempDir;
use std::collections::BTreeSet;
use std::fs;
use std::os::unix::fs::{PermissionsExt, symlink};

/** Lists `root` with metadata, checks each listed entry against a read by path, and returns all names
and the names left to that read. */
fn list(root: &Path) -> (BTreeSet<OsString>, BTreeSet<OsString>) {
    let listing = Listing::open(root).unwrap();
    assert!(
        matches!(listing, Listing::Bulk(_)),
        "{root:?} lists names only"
    );
    let (mut names, mut by_path) = (BTreeSet::new(), BTreeSet::new());
    for listed in listing {
        match listed.unwrap() {
            Listed::Entry(entry) => {
                let read = Entry::read(&root.join(&entry.name)).unwrap();
                assert_eq!(entry, read, "{:?}", entry.name);
                names.insert(entry.name);
            }
            Listed::Name(name) => {
                by_path.insert(name.clone());
                names.insert(name);
            }
        }
    }
    (names, by_path)
}

#[test]
fn t_bulk_listing_matches_reads_by_path() {
    let dir = TempDir::new();
    let root = dir.path();
    /* More entries than one buffer holds, so the listing reads several batches. */
    for index in 0..2000 {
        fs::write(root.join(format!("file-{index:04}")), vec![b'x'; index % 7]).unwrap();
    }
    fs::create_dir(root.join("empty")).unwrap();
    fs::create_dir(root.join("full")).unwrap();
    fs::write(root.join("full/inner"), b"x").unwrap();
    fs::set_permissions(root.join("file-0001"), fs::Permissions::from_mode(0o4755)).unwrap();
    fs::set_permissions(root.join("file-0002"), fs::Permissions::from_mode(0o600)).unwrap();
    fs::set_permissions(root.join("full"), fs::Permissions::from_mode(0o1777)).unwrap();
    fs::hard_link(root.join("file-0003"), root.join("hard")).unwrap();
    symlink("file-0004", root.join("link")).unwrap();
    symlink("missing", root.join("dangling")).unwrap();
    fs::write(root.join("\u{e9}-nfc"), b"nfc").unwrap();
    fs::write(root.join("e\u{301}-nfd"), b"nfd").unwrap();
    let fifo = c_path(&root.join("pipe")).unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o644) }, 0);

    let (names, by_path) = list(root);
    let expected: BTreeSet<_> = fs::read_dir(root)
        .unwrap()
        .map(|entry| entry.unwrap().file_name())
        .collect();
    assert_eq!(names, expected);
    /* Only links leave their metadata to a read by path. */
    assert_eq!(by_path, BTreeSet::from(["dangling".into(), "link".into()]));
}

#[test]
fn t_bulk_listing_reads_firmlinks_by_path() {
    let (_, by_path) = list(Path::new("/"));
    /* `/Users` is a firmlink into the data volume. */
    assert!(by_path.contains(OsStr::new("Users")), "{by_path:?}");
}

#[test]
fn t_bulk_listing_reads_mount_points_by_path() {
    let (_, by_path) = list(Path::new("/System/Volumes"));
    /* The data volume is mounted over a directory of the system volume. */
    assert!(by_path.contains(OsStr::new("Data")), "{by_path:?}");
}

#[test]
fn t_bulk_listing_reads_other_volumes_by_path() {
    /* devfs is not APFS. */
    let listing = Listing::open(Path::new("/dev")).unwrap();
    assert!(matches!(listing, Listing::Names(_)));
    let names: Vec<_> = listing
        .map(|listed| match listed.unwrap() {
            Listed::Name(name) => name,
            Listed::Entry(entry) => panic!("{:?} is listed with metadata", entry.name),
        })
        .collect();
    assert!(names.iter().any(|name| name == "null"), "{names:?}");
}

#[test]
fn t_bulk_metadata_is_listed_only_on_apfs_without_nosuid() {
    let volume = |kind: &str, flags: libc::c_int| {
        let mut volume: libc::statfs = unsafe { std::mem::zeroed() };
        for (to, from) in volume.f_fstypename.iter_mut().zip(kind.bytes()) {
            *to = from as libc::c_char;
        }
        volume.f_flags = flags as u32;
        volume
    };
    assert!(consistent(&volume("apfs", libc::MNT_RDONLY)));
    assert!(!consistent(&volume("apfs", libc::MNT_NOSUID)));
    assert!(!consistent(&volume("exfat", 0)));
    assert!(!consistent(&volume("msdos", 0)));
}

/** One regular file's group as getattrlistbulk lays it out, with `dirattr` claimed as returned. */
fn group(dirattr: u32) -> Vec<u8> {
    let returned = [
        libc::ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_ERROR | COMMON,
        0,
        dirattr,
        libc::ATTR_FILE_DATALENGTH,
        0,
    ];
    let mut group = vec![0; 4];
    returned
        .iter()
        .for_each(|word| group.extend(word.to_ne_bytes()));
    group.extend(0u32.to_ne_bytes());
    let reference_at = group.len();
    group.extend([0; 8]);
    group.extend(1i32.to_ne_bytes());
    group.extend(1u32.to_ne_bytes());
    /* Creation and modification times, owner, group, access mask and flags. */
    group.extend([0; 48]);
    group.extend(7u64.to_ne_bytes());
    if dirattr != 0 {
        group.extend([0; 12]);
    }
    group.extend(4i64.to_ne_bytes());
    let offset = (group.len() - reference_at) as i32;
    group.extend(b"file\0");
    group[reference_at..reference_at + 4].copy_from_slice(&offset.to_ne_bytes());
    group[reference_at + 4..reference_at + 8].copy_from_slice(&5u32.to_ne_bytes());
    let length = group.len() as u32;
    group[..4].copy_from_slice(&length.to_ne_bytes());
    group
}

#[test]
fn t_bulk_parse_reads_unexpected_layouts_by_path() {
    let parsed = parse(&group(0));
    assert!(
        matches!(&parsed, Some(Listed::Entry(entry)) if entry.size == 4 && entry.identity.file == 7),
        "a regular file's group parses"
    );
    /* Directory attributes on a file would shift its length; the name is left to a read by path. */
    let parsed = parse(&group(DIRECTORY));
    assert!(matches!(&parsed, Some(Listed::Name(name)) if name == "file"));
}
