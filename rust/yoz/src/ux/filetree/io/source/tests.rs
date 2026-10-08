use super::*;
use crate::ux::filetree::tests::Directory;
use std::fs;
use std::io::Read;
use std::os::unix::fs::symlink;

#[test]
fn t_source_open_checks_the_descriptor_and_does_not_follow_replacements() {
    let directory = Directory::new();
    let path = directory.0.join("source");
    fs::write(&path, b"original").unwrap();
    let expected = Signature::read(&path, false).unwrap();
    let mut input = open(&path, &expected).unwrap();
    let mut contents = Vec::new();
    input.file.read_to_end(&mut contents).unwrap();
    assert_eq!(contents, b"original");
    fs::rename(&path, directory.0.join("moved")).unwrap();
    fs::write(&path, b"replacement").unwrap();
    assert!(open(&path, &expected).is_err());
    fs::remove_file(&path).unwrap();
    symlink("moved", &path).unwrap();
    assert!(open(&path, &expected).is_err());
    fs::remove_file(&path).unwrap();
    fs::create_dir(&path).unwrap();
    assert!(open(&path, &expected).is_err());
}

#[test]
fn t_source_open_cannot_block_on_a_replacement_fifo() {
    use std::os::unix::ffi::OsStrExt;
    let directory = Directory::new();
    let path = directory.0.join("source");
    fs::write(&path, b"original").unwrap();
    let expected = Signature::read(&path, false).unwrap();
    fs::remove_file(&path).unwrap();
    let name = std::ffi::CString::new(path.as_os_str().as_bytes()).unwrap();
    assert_eq!(unsafe { libc::mkfifo(name.as_ptr(), 0o600) }, 0);
    assert!(open(&path, &expected).is_err());
}
