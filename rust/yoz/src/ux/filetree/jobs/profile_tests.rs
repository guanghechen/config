use super::*;
use crate::ux::filetree::jobs_tests::{plan, selection};
use crate::ux::filetree::profile::{self, Profile};
use crate::ux::filetree::tests::{Directory, request};
use std::fs;

fn measure(files: usize) {
    for trial in 0..6 {
        let enabled = trial % 2 == 0;
        let fixture = Directory::new();
        fs::create_dir(fixture.0.join("source")).unwrap();
        fs::create_dir(fixture.0.join("destination")).unwrap();
        for index in 0..files {
            fs::write(fixture.0.join(format!("source/file-{index:05}")), b"data").unwrap();
        }
        let tree = request(Filetree::open(fixture.0.clone()));
        let mut operation = plan(&tree, "source", Some("destination"), OperationKind::Copy);
        let state = selection(&tree, &mut operation);
        let profile = Arc::new(Profile::default());
        let _scope = profile::enter(enabled.then(|| profile.clone()));
        let started = Instant::now();
        let job = tree.start_operation(operation).unwrap();
        let mut peak = 0;
        while !job.status().terminal || enabled && !profile.finished() {
            assert!(started.elapsed() < Duration::from_secs(180));
            peak = peak.max(tree.data().memory().used());
            std::thread::sleep(Duration::from_millis(1));
        }
        let elapsed = started.elapsed();
        let status = job.status();
        assert!(status.error.is_none(), "{:?}", status.error);
        assert!(matches!(status.cleanup, Some(Ok(()))));
        assert_eq!(status.results, 1);
        assert_eq!(status.processed, files + 1);
        assert_eq!(status.bytes, (files * 4) as u64);
        assert!(state.snapshot().unwrap().summary.is_empty());
        assert!(!state.status().unwrap().locked);
        for index in 0..files {
            for parent in ["source", "destination/source"] {
                assert_eq!(
                    fs::read(fixture.0.join(format!("{parent}/file-{index:05}"))).unwrap(),
                    b"data"
                );
            }
        }
        assert_eq!(
            fs::read_dir(fixture.0.join("destination")).unwrap().count(),
            1
        );
        eprintln!(
            "copy_profile files={files} trial={trial} enabled={enabled} elapsed_ns={} sampled_data_peak={} retained_nodes={}",
            elapsed.as_nanos(),
            peak,
            tree.source().len()
        );
        if enabled {
            profile.report(files, trial);
        }
    }
}

#[test]
#[ignore = "opt-in small-file stage measurement; run alone in release mode"]
fn t_profile_copy_1000_stages() {
    measure(1000);
}

#[test]
#[ignore = "opt-in small-file stage measurement; run alone in release mode"]
fn t_profile_copy_10000_stages() {
    measure(10000);
}
