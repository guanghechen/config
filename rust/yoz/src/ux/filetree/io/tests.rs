use super::*;
use crate::ux::filetree::tests::Directory;
use crate::ux::treeview::{Error, ErrorCode, memory::Budget};

#[test]
fn t_copy_reuses_its_working_set_and_releases_the_budget() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    fs::write(&source, b"contents").unwrap();
    let expected = Signature::read(&source, false).unwrap();
    let cancel = AtomicBool::new(false);
    let budget = Budget::new(4 * COPY_BUFFER);
    let _guard = budget.enter();
    let mut copier = Copier::default();
    let mut allocation = std::ptr::null();
    let mut bytes = 0;
    for index in 0..3 {
        let target = Destination {
            path: directory.0.join(format!("target-{index}")),
            parent: Signature::read(&directory.0, true).unwrap(),
            expected: None,
        };
        copier
            .copy(&source, &expected, &target, &cancel, |_| {})
            .unwrap();
        assert_eq!(fs::read(&target.path).unwrap(), b"contents");
        if index == 0 {
            allocation = copier.buffer.as_ptr();
            bytes = budget.used();
        } else {
            assert_eq!(allocation, copier.buffer.as_ptr());
            assert_eq!(bytes, budget.used());
        }
    }
    assert!(
        bytes < 64 * 1024,
        "small files must not reserve a full large-file buffer"
    );
    let contents = vec![b'x'; COPY_BUFFER * 2 + 37];
    fs::write(&source, &contents).unwrap();
    let target = Destination {
        path: directory.0.join("large"),
        parent: Signature::read(&directory.0, true).unwrap(),
        expected: None,
    };
    copier
        .copy(&source, &expected, &target, &cancel, |_| {})
        .unwrap();
    assert_eq!(fs::read(&target.path).unwrap(), contents);
    assert!(budget.used() >= COPY_BUFFER && budget.used() < COPY_BUFFER + 64 * 1024);
    drop(copier);
    assert_eq!(budget.used(), 0);
}

#[test]
fn t_copy_stream_preserves_binary_contents_and_cancels_at_chunk_boundaries() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    let contents: Vec<_> = (0..COPY_BUFFER * 2 + 37).map(|index| index as u8).collect();
    fs::write(&source, &contents).unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&source, fs::Permissions::from_mode(0o640)).unwrap();
    }
    let expected = Signature::read(&source, false).unwrap();
    for stop in [false, true] {
        let target = Destination {
            path: directory
                .0
                .join(if stop { "cancelled" } else { "complete" }),
            parent: Signature::read(&directory.0, true).unwrap(),
            expected: None,
        };
        let cancel = AtomicBool::new(false);
        let copied = std::cell::Cell::new(0);
        let result = Copier::default().copy(&source, &expected, &target, &cancel, |bytes| {
            assert!(bytes > 0 && bytes <= COPY_BUFFER as u64);
            copied.set(copied.get() + bytes);
            if stop {
                cancel.store(true, Ordering::Release);
            }
        });
        if stop {
            assert_eq!(result.unwrap_err().kind(), io::ErrorKind::Interrupted);
            assert!(copied.get() > 0 && copied.get() <= COPY_BUFFER as u64);
            assert!(!target.path.exists());
            assert_eq!(fs::read_dir(&directory.0).unwrap().count(), 2);
        } else {
            result.unwrap();
            assert_eq!(copied.get(), contents.len() as u64);
            assert_eq!(fs::read(&target.path).unwrap(), contents);
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                assert_eq!(
                    fs::metadata(&target.path).unwrap().permissions().mode() & 0o777,
                    0o640
                );
            }
        }
        assert_eq!(fs::read(&source).unwrap(), contents);
    }
}

#[cfg(target_os = "linux")]
#[test]
fn t_unsupported_kernel_copy_preserves_existing_stream_offsets() {
    use std::io::{Seek, SeekFrom};
    let directory = Directory::new();
    let source = directory.0.join("source");
    let target = directory.0.join("target");
    let contents: Vec<_> = (0..32_000).map(|index| index as u8).collect();
    fs::write(&source, &contents).unwrap();
    let expected = Signature::read(&source, false).unwrap();
    let mut copier = Copier::default();
    let mut input = copier.open_source(&source, &expected).unwrap().unwrap();
    let prefix = 417;
    input.file.seek(SeekFrom::Start(prefix as u64)).unwrap();
    fs::write(&target, &contents[..prefix]).unwrap();
    /* Linux rejects sendfile to O_APPEND; the buffered fallback must resume both streams. */
    let mut output = OpenOptions::new().append(true).open(&target).unwrap();
    let copied = std::cell::Cell::new(0);
    copier
        .stream(
            &mut input.file,
            &mut output,
            &AtomicBool::new(false),
            |bytes| {
                copied.set(copied.get() + bytes);
            },
        )
        .unwrap();
    assert!(copier.stream_fallback);
    assert_eq!(copied.get(), (contents.len() - prefix) as u64);
    assert_eq!(fs::read(target).unwrap(), contents);
}

#[test]
fn t_copy_keeps_streaming_when_a_small_source_grows() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    fs::write(&source, b"head").unwrap();
    let expected = Signature::read(&source, false).unwrap();
    let target = Destination {
        path: directory.0.join("target"),
        parent: Signature::read(&directory.0, true).unwrap(),
        expected: None,
    };
    let appended = std::cell::Cell::new(false);
    Copier::default()
        .copy(&source, &expected, &target, &AtomicBool::new(false), |_| {
            if !appended.replace(true) {
                OpenOptions::new()
                    .append(true)
                    .open(&source)
                    .unwrap()
                    .write_all(b" tail")
                    .unwrap();
            }
        })
        .unwrap();
    assert_eq!(fs::read(&target.path).unwrap(), b"head tail");
}

#[test]
fn t_copy_rechecks_source_identity_after_streaming() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    let output = directory.0.join("target");
    fs::write(&source, b"original source").unwrap();
    fs::write(&output, b"original target").unwrap();
    let expected = Signature::read(&source, false).unwrap();
    let target = Destination {
        path: output,
        parent: Signature::read(&directory.0, true).unwrap(),
        expected: existing(&directory.0.join("target")).unwrap(),
    };
    let replaced = std::cell::Cell::new(false);
    let error = Copier::default()
        .copy(&source, &expected, &target, &AtomicBool::new(false), |_| {
            if !replaced.replace(true) {
                fs::rename(&source, directory.0.join("saved")).unwrap();
                fs::write(&source, b"replacement source").unwrap();
            }
        })
        .unwrap_err();
    assert_eq!(error.kind(), io::ErrorKind::AlreadyExists);
    assert_eq!(fs::read(&source).unwrap(), b"replacement source");
    assert_eq!(fs::read(&target.path).unwrap(), b"original target");
    assert_eq!(
        fs::read(directory.0.join("saved")).unwrap(),
        b"original source"
    );
    assert_eq!(fs::read_dir(&directory.0).unwrap().count(), 3);
}

#[test]
fn t_copy_rechecks_new_and_confirmed_destinations_after_streaming() {
    for overwrite in [false, true] {
        let directory = Directory::new();
        let source = directory.0.join("source");
        let output = directory.0.join("target");
        fs::write(&source, b"original source").unwrap();
        if overwrite {
            fs::write(&output, b"confirmed target").unwrap();
        }
        let expected = Signature::read(&source, false).unwrap();
        let target = Destination {
            expected: existing(&output).unwrap(),
            path: output,
            parent: Signature::read(&directory.0, true).unwrap(),
        };
        let replaced = std::cell::Cell::new(false);
        let error = Copier::default()
            .copy(&source, &expected, &target, &AtomicBool::new(false), |_| {
                if !replaced.replace(true) {
                    if overwrite {
                        fs::rename(&target.path, directory.0.join("saved")).unwrap();
                    }
                    fs::write(&target.path, b"replacement target").unwrap();
                }
            })
            .unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::AlreadyExists);
        assert_eq!(fs::read(&source).unwrap(), b"original source");
        assert_eq!(fs::read(&target.path).unwrap(), b"replacement target");
        if overwrite {
            assert_eq!(
                fs::read(directory.0.join("saved")).unwrap(),
                b"confirmed target"
            );
        }
        assert_eq!(
            fs::read_dir(&directory.0).unwrap().count(),
            2 + usize::from(overwrite)
        );
    }
}

#[cfg(unix)]
#[test]
fn t_cached_copy_parent_cannot_retarget_a_replaced_directory() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    let parent = directory.0.join("destination");
    fs::write(&source, b"contents").unwrap();
    fs::create_dir(&parent).unwrap();
    let expected = Signature::read(&source, false).unwrap();
    let cancel = AtomicBool::new(false);
    let mut copier = Copier::default();
    let mut target = Destination {
        path: parent.join("first"),
        parent: Signature::read(&parent, true).unwrap(),
        expected: None,
    };
    copier
        .copy(&source, &expected, &target, &cancel, |_| {})
        .unwrap();
    let previous = copier.parent.as_ref().unwrap().file.clone();
    fs::rename(&parent, directory.0.join("old")).unwrap();
    fs::create_dir(&parent).unwrap();
    target.path = parent.join("second");
    assert!(
        copier
            .copy(&source, &expected, &target, &cancel, |_| {})
            .is_err()
    );
    assert!(!target.path.exists());
    assert!(!directory.0.join("old/second").exists());
    target.parent = Signature::read(&parent, true).unwrap();
    copier
        .copy(&source, &expected, &target, &cancel, |_| {})
        .unwrap();
    assert!(!Arc::ptr_eq(
        &previous,
        &copier.parent.as_ref().unwrap().file
    ));
    assert_eq!(fs::read(target.path).unwrap(), b"contents");
}

#[test]
fn t_copy_capacity_failure_precedes_creating_private_output() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    fs::write(&source, b"contents").unwrap();
    let expected = Signature::read(&source, false).unwrap();
    let target = Destination {
        path: directory.0.join("target"),
        parent: Signature::read(&directory.0, true).unwrap(),
        expected: None,
    };
    let budget = Budget::new(128);
    let _guard = budget.enter();
    let error = Copier::default()
        .copy(&source, &expected, &target, &AtomicBool::new(false), |_| {})
        .unwrap_err();
    assert_eq!(
        error
            .get_ref()
            .unwrap()
            .downcast_ref::<Error>()
            .unwrap()
            .code,
        ErrorCode::ResourceLimit
    );
    assert_eq!(budget.used(), 0);
    assert_eq!(fs::read_dir(&directory.0).unwrap().count(), 1);
}

#[cfg(target_os = "macos")]
#[test]
fn t_copied_descriptor_observation_rejects_a_replaced_output_name() {
    let directory = Directory::new();
    let source = directory.0.join("source");
    fs::write(&source, b"contents").unwrap();
    let expected = Signature::read(&source, false).unwrap();
    let target = Destination {
        path: directory.0.join("target"),
        parent: Signature::read(&directory.0, true).unwrap(),
        expected: None,
    };
    let mut copier = Copier::default();
    let output = copier
        .copy(&source, &expected, &target, &AtomicBool::new(false), |_| {})
        .unwrap()
        .unwrap();
    let observed = observed_output(&target.path, Some(&output)).unwrap();
    assert_eq!(observed.identity, FileIdentity::from_file(&output).unwrap());
    assert_eq!(observed.name, "target");
    fs::rename(&target.path, directory.0.join("saved")).unwrap();
    fs::write(&target.path, b"replacement").unwrap();
    assert!(observed_output(&target.path, Some(&output)).is_err());
    assert_eq!(fs::read(&target.path).unwrap(), b"replacement");
    assert_eq!(fs::read(directory.0.join("saved")).unwrap(), b"contents");
}
