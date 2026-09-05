use super::{Backend, is_available, parse_source_id, release_is_wsl};
use crate::CaptureAndSelectError;

#[cfg(unix)]
static PROCESS_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

#[cfg(unix)]
fn lock_process_test() -> std::sync::MutexGuard<'static, ()> {
    PROCESS_TEST_LOCK
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}

#[test]
fn t_detects_wsl_kernel_releases() {
    let _ = is_available();
    assert!(release_is_wsl("5.15.153.1-microsoft-standard-WSL2"));
    assert!(release_is_wsl("4.4.0-19041-Microsoft"));
    assert!(!release_is_wsl("6.12.10-generic"));
}

#[test]
fn t_validates_helper_source_ids() {
    assert_eq!(parse_source_id("1033", "test"), Ok(1033));
    assert_eq!(parse_source_id("2052", "test"), Ok(2052));
    assert_eq!(parse_source_id("67699721", "test"), Ok(67_699_721));
    assert_eq!(
        parse_source_id("18446744073709551615", "test"),
        Ok(u64::MAX)
    );
    assert!(parse_source_id("", "test").is_err());
    assert!(parse_source_id("0", "test").is_err());
    assert!(parse_source_id("invalid", "test").is_err());
}

#[test]
fn t_requires_setup_and_contextualizes_spawn_failures() {
    let mut im = Backend::default();
    assert!(
        im.capture()
            .expect_err("unconfigured backend must fail")
            .contains("has not been configured")
    );
    assert!(im.setup("").is_err());
    assert!(
        im.setup("/dev/yoz-im-does-not-exist")
            .expect_err("missing executable must fail")
            .contains("executable is unavailable")
    );
}

#[cfg(unix)]
#[test]
fn t_times_out_and_reaps_a_hung_helper() {
    use std::os::unix::fs::PermissionsExt;
    use std::time::{Instant, SystemTime, UNIX_EPOCH};

    let _guard = lock_process_test();
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system time")
        .as_nanos();
    let executable =
        std::env::temp_dir().join(format!("yoz-wsl-im-hung-{}-{nonce}.sh", std::process::id()));
    std::fs::write(&executable, "#!/bin/sh\nexec sleep 5\n").expect("write helper");
    let mut permissions = std::fs::metadata(&executable)
        .expect("helper metadata")
        .permissions();
    permissions.set_mode(0o700);
    std::fs::set_permissions(&executable, permissions).expect("make helper executable");

    let mut im = Backend::default();
    im.setup(executable.to_str().expect("UTF-8 helper path"))
        .expect("configure helper");
    let started_at = Instant::now();
    assert!(
        im.capture()
            .expect_err("hung helper must time out")
            .contains("timed out after 1000ms")
    );
    assert!(started_at.elapsed() < std::time::Duration::from_secs(2));

    std::fs::remove_file(executable).expect("remove helper");
}

#[cfg(unix)]
#[test]
fn t_preserves_a_snapshot_when_english_selection_times_out() {
    use std::os::unix::fs::PermissionsExt;
    use std::time::{Instant, SystemTime, UNIX_EPOCH};

    let _guard = lock_process_test();
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system time")
        .as_nanos();
    let executable = std::env::temp_dir().join(format!(
        "yoz-wsl-im-partial-timeout-{}-{nonce}.sh",
        std::process::id()
    ));
    std::fs::write(
        &executable,
        "#!/bin/sh\nprintf '134481924\\n'\nexec sleep 5\n",
    )
    .expect("write helper");
    let mut permissions = std::fs::metadata(&executable)
        .expect("helper metadata")
        .permissions();
    permissions.set_mode(0o700);
    std::fs::set_permissions(&executable, permissions).expect("make helper executable");

    let mut im = Backend::default();
    im.setup(executable.to_str().expect("UTF-8 helper path"))
        .expect("configure helper");
    let started_at = Instant::now();
    let error = im
        .capture_and_select_english()
        .expect_err("hung selection must time out");
    assert_eq!(
        error,
        CaptureAndSelectError::Select {
            snapshot: "134481924".to_owned(),
            error: format!(
                "[im.capture_and_select_english] IM process timed out after 1000ms: {}",
                executable.display()
            ),
        }
    );
    assert!(started_at.elapsed() < std::time::Duration::from_secs(2));

    std::fs::remove_file(executable).expect("remove helper");
}

#[cfg(unix)]
#[test]
fn t_captures_selects_and_restores_through_one_helper_call_each() {
    use std::os::unix::fs::PermissionsExt;
    use std::time::{SystemTime, UNIX_EPOCH};

    let _guard = lock_process_test();
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system time")
        .as_nanos();
    let executable =
        std::env::temp_dir().join(format!("yoz-wsl-im-{}-{nonce}.sh", std::process::id()));
    let state =
        std::env::temp_dir().join(format!("yoz-wsl-im-state-{}-{nonce}", std::process::id()));
    let calls =
        std::env::temp_dir().join(format!("yoz-wsl-im-calls-{}-{nonce}", std::process::id()));
    std::fs::write(&state, "134481924\n").expect("write helper state");
    std::fs::write(
            &executable,
            format!(
                "#!/bin/sh\nstate='{}'\ncalls='{}'\nprintf '%s\\n' \"${{1:-capture}}\" >> \"$calls\"\nif [ \"$#\" -eq 0 ]; then cat \"$state\"; exit 0; fi\nif [ \"$1\" = --english ]; then cat \"$state\"; printf '67699721\\n' > \"$state\"; exit 0; fi\ncase \"$1\" in\n  *[!0-9]*|'') exit 1 ;;\n  *) printf '%s\\n' \"$1\" > \"$state\" ;;\nesac\n",
                state.display(),
                calls.display()
            ),
        )
        .expect("write helper");
    let mut permissions = std::fs::metadata(&executable)
        .expect("helper metadata")
        .permissions();
    permissions.set_mode(0o700);
    std::fs::set_permissions(&executable, permissions).expect("make helper executable");

    let mut im = Backend::default();
    im.setup(executable.to_str().expect("UTF-8 helper path"))
        .expect("configure helper");
    assert_eq!(im.capture(), Ok("134481924".to_owned()));
    assert_eq!(im.capture_and_select_english(), Ok("134481924".to_owned()));
    assert_eq!(im.capture(), Ok("67699721".to_owned()));
    assert!(im.restore("134481924").is_ok());
    assert_eq!(im.capture(), Ok("134481924".to_owned()));
    assert!(im.is_english("67699721"));
    assert!(!im.is_english("134481924"));
    assert_eq!(
        std::fs::read_to_string(&calls).expect("read helper calls"),
        "capture\n--english\ncapture\n134481924\ncapture\n"
    );

    std::fs::remove_file(executable).expect("remove helper");
    std::fs::remove_file(state).expect("remove helper state");
    std::fs::remove_file(calls).expect("remove helper calls");
}

#[cfg(unix)]
#[test]
fn t_preserves_a_snapshot_when_english_selection_fails() {
    use std::os::unix::fs::PermissionsExt;
    use std::time::{SystemTime, UNIX_EPOCH};

    let _guard = lock_process_test();
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system time")
        .as_nanos();
    let executable = std::env::temp_dir().join(format!(
        "yoz-wsl-im-partial-{}-{nonce}.sh",
        std::process::id()
    ));
    std::fs::write(
        &executable,
        "#!/bin/sh\nprintf '134481924\\n'\nprintf 'selection failed\\n' >&2\nexit 1\n",
    )
    .expect("write helper");
    let mut permissions = std::fs::metadata(&executable)
        .expect("helper metadata")
        .permissions();
    permissions.set_mode(0o700);
    std::fs::set_permissions(&executable, permissions).expect("make helper executable");

    let mut im = Backend::default();
    im.setup(executable.to_str().expect("UTF-8 helper path"))
        .expect("configure helper");
    let error = im
        .capture_and_select_english()
        .expect_err("selection failure must preserve its snapshot");
    assert_eq!(
        error,
        CaptureAndSelectError::Select {
            snapshot: "134481924".to_owned(),
            error: "[im.capture_and_select_english] IM process exited with 1: selection failed"
                .to_owned(),
        }
    );

    std::fs::remove_file(executable).expect("remove helper");
}

#[cfg(unix)]
#[test]
fn t_rejects_unexpected_restore_output() {
    use std::os::unix::fs::PermissionsExt;
    use std::time::{SystemTime, UNIX_EPOCH};

    let _guard = lock_process_test();
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system time")
        .as_nanos();
    let executable = std::env::temp_dir().join(format!(
        "yoz-wsl-im-output-{}-{nonce}.sh",
        std::process::id()
    ));
    std::fs::write(&executable, "#!/bin/sh\nprintf 'unexpected\\n'\n").expect("write helper");
    let mut permissions = std::fs::metadata(&executable)
        .expect("helper metadata")
        .permissions();
    permissions.set_mode(0o700);
    std::fs::set_permissions(&executable, permissions).expect("make helper executable");

    let mut im = Backend::default();
    im.setup(executable.to_str().expect("UTF-8 helper path"))
        .expect("configure helper");
    assert!(
        im.restore("134481924")
            .expect_err("restore output must fail")
            .contains("unexpected output")
    );

    std::fs::remove_file(executable).expect("remove helper");
}
