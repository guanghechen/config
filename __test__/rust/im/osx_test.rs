use super::{
    Backend, SelectionState, copy_ascii_capable, is_ascii_capable, resolve, source_id,
    validate_source_id,
};

static NATIVE_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

fn lock_native_test() -> std::sync::MutexGuard<'static, ()> {
    NATIVE_TEST_LOCK
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}

#[repr(C)]
struct RunLoopSourceContext {
    version: isize,
    info: *mut std::ffi::c_void,
    retain: *const std::ffi::c_void,
    release: *const std::ffi::c_void,
    copy_description: *const std::ffi::c_void,
    equal: *const std::ffi::c_void,
    hash: *const std::ffi::c_void,
    schedule: *const std::ffi::c_void,
    cancel: *const std::ffi::c_void,
    perform: unsafe extern "C" fn(*mut std::ffi::c_void),
}

#[link(name = "CoreFoundation", kind = "framework")]
unsafe extern "C" {
    fn CFRunLoopGetCurrent() -> super::CFTypeRef;
    fn CFRunLoopSourceCreate(
        allocator: super::CFAllocatorRef,
        order: super::CFIndex,
        context: *mut RunLoopSourceContext,
    ) -> super::CFTypeRef;
    fn CFRunLoopAddSource(
        run_loop: super::CFTypeRef,
        source: super::CFTypeRef,
        mode: super::CFStringRef,
    );
    fn CFRunLoopSourceSignal(source: super::CFTypeRef);
    fn CFRunLoopSourceInvalidate(source: super::CFTypeRef);
    fn CFRunLoopStop(run_loop: super::CFTypeRef);
    fn CFRunLoopObserverCreate(
        allocator: super::CFAllocatorRef,
        activities: usize,
        repeats: super::Boolean,
        order: super::CFIndex,
        callback: unsafe extern "C" fn(super::CFTypeRef, usize, *mut std::ffi::c_void),
        context: *mut std::ffi::c_void,
    ) -> super::CFTypeRef;
    fn CFRunLoopAddObserver(
        run_loop: super::CFTypeRef,
        observer: super::CFTypeRef,
        mode: super::CFStringRef,
    );
    fn CFRunLoopObserverInvalidate(observer: super::CFTypeRef);
}

struct CallbackState {
    handled: std::cell::Cell<usize>,
    source: std::cell::Cell<super::CFTypeRef>,
    repeat: bool,
}

struct QueuedCallback {
    source: super::OwnedCFRef,
    state: Box<CallbackState>,
}

impl QueuedCallback {
    fn new(repeat: bool) -> Self {
        unsafe extern "C" fn perform(info: *mut std::ffi::c_void) {
            let state = unsafe { &*info.cast::<CallbackState>() };
            state.handled.set(state.handled.get() + 1);
            if state.repeat {
                unsafe { CFRunLoopSourceSignal(state.source.get()) };
            }
        }

        let state = Box::new(CallbackState {
            handled: std::cell::Cell::new(0),
            source: std::cell::Cell::new(std::ptr::null()),
            repeat,
        });
        let mut context = RunLoopSourceContext {
            version: 0,
            info: std::ptr::from_ref(state.as_ref()).cast_mut().cast(),
            retain: std::ptr::null(),
            release: std::ptr::null(),
            copy_description: std::ptr::null(),
            equal: std::ptr::null(),
            hash: std::ptr::null(),
            schedule: std::ptr::null(),
            cancel: std::ptr::null(),
            perform,
        };
        let source = unsafe {
            super::OwnedCFRef::from_created(
                CFRunLoopSourceCreate(std::ptr::null(), 0, &mut context),
                "im.test",
            )
        }
        .expect("create callback source");
        state.source.set(source.as_ptr());
        unsafe {
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                source.as_ptr(),
                super::kCFRunLoopDefaultMode,
            );
            CFRunLoopSourceSignal(source.as_ptr());
        }
        Self { source, state }
    }
}

impl Drop for QueuedCallback {
    fn drop(&mut self) {
        // Invalidate before freeing the boxed callback data, including when an assertion panics.
        unsafe { CFRunLoopSourceInvalidate(self.source.as_ptr()) };
    }
}

struct InterruptOnEntry(super::OwnedCFRef);

impl InterruptOnEntry {
    fn new() -> Self {
        unsafe extern "C" fn interrupt(
            _observer: super::CFTypeRef,
            _activity: usize,
            _info: *mut std::ffi::c_void,
        ) {
            unsafe { CFRunLoopStop(CFRunLoopGetCurrent()) };
        }
        let observer = unsafe {
            super::OwnedCFRef::from_created(
                CFRunLoopObserverCreate(
                    std::ptr::null(),
                    1, // kCFRunLoopEntry
                    0,
                    0,
                    interrupt,
                    std::ptr::null_mut(),
                ),
                "im.test",
            )
        }
        .expect("create one-shot interruption");
        unsafe {
            CFRunLoopAddObserver(
                CFRunLoopGetCurrent(),
                observer.as_ptr(),
                super::kCFRunLoopDefaultMode,
            );
        }
        Self(observer)
    }
}

impl Drop for InterruptOnEntry {
    fn drop(&mut self) {
        unsafe { CFRunLoopObserverInvalidate(self.0.as_ptr()) };
    }
}

#[test]
fn t_capture_processes_all_queued_notifications_before_reading() {
    let _guard = lock_native_test();
    let mut im = Backend::default();
    im.capture().expect("initialize TIS");
    let callbacks: Vec<_> = (0..8).map(|_| QueuedCallback::new(false)).collect();

    im.capture().expect("capture after queued callbacks");

    for callback in &callbacks {
        assert_eq!(callback.state.handled.get(), 1, "pending callback handled");
    }
}

#[test]
fn t_capture_rejects_an_interrupted_refresh_and_recovers_on_the_next_attempt() {
    let _guard = lock_native_test();
    let mut im = Backend::default();
    im.capture().expect("initialize TIS");
    let pending = QueuedCallback::new(false);
    let interrupt = InterruptOnEntry::new();

    let error = im.capture().expect_err("interrupted refresh must fail");
    assert!(error.contains("notification refresh was interrupted"));
    assert_eq!(pending.state.handled.get(), 0, "callback still pending");

    drop(interrupt);
    im.capture()
        .expect("next attempt handles pending callbacks");
    assert_eq!(pending.state.handled.get(), 1);
}

#[test]
fn t_capture_bounds_notification_work_and_recovers_after_the_queue_quiets() {
    let _guard = lock_native_test();
    let mut im = Backend::default();
    im.capture().expect("initialize TIS");
    let repeating = QueuedCallback::new(true);

    let error = im
        .capture()
        .expect_err("a busy queue cannot yield a fresh snapshot");
    assert!(error.contains("notifications are still busy"));
    assert!(repeating.state.handled.get() > 0);
    assert!(repeating.state.handled.get() <= super::MAX_NOTIFICATION_PASSES);

    drop(repeating);
    im.capture()
        .expect("capture recovers once notifications stop");
}

#[test]
fn t_rejects_invalid_source_ids() {
    assert!(validate_source_id("").is_err());
    assert!(validate_source_id("invalid\0source").is_err());
}

#[test]
fn t_identifies_the_current_ascii_capable_source() {
    let _guard = lock_native_test();
    let (_, im) = copy_ascii_capable().expect("read current ASCII-capable source");
    assert_eq!(is_ascii_capable(im.as_ptr().cast(), "im.test"), Ok(true));
}

#[test]
fn t_reads_current_ascii_and_unknown_sources_without_changing_current_source() {
    let _guard = lock_native_test();
    let mut im = Backend::default();
    let before = im.capture().expect("read current input source");

    let (expected, _) = copy_ascii_capable().expect("read current ASCII-capable source");
    let resolved = resolve(&expected).expect("resolve current ASCII-capable source");
    assert_eq!(source_id(resolved.as_ptr().cast(), "im.test"), Ok(expected));

    let error = im
        .restore("dev.yoz.im.does-not-exist")
        .expect_err("unknown source must fail");

    assert!(error.contains("Enabled input source not found"));
    assert_eq!(im.capture(), Ok(before));
}

#[test]
fn t_selection_requires_matching_current_and_no_conflicting_request() {
    let state = SelectionState::default();
    assert!(!state.needs_selection("source.english", "source.english"));
    assert!(state.needs_selection("source.chinese", "source.english"));
}

#[test]
fn t_last_submission_cannot_be_hidden_by_a_stale_english_read() {
    let mut state = SelectionState::default();
    state.record_request("source.chinese");
    assert!(state.needs_selection("source.english", "source.english"));

    state.record_request("source.english");
    assert!(!state.needs_selection("source.english", "source.english"));
}

#[test]
fn t_stale_matching_capture_cannot_hide_a_later_queued_selection() {
    let _guard = lock_native_test();
    let mut im = Backend::default();
    let initial = im.capture().expect("capture initial source");
    let alternative = "dev.yoz.im.alternative-source";

    // Accepted requests have not yet become visible: A -> [B, A].
    im.selection.record_request(alternative);
    im.selection.record_request(&initial);
    let mut queued = std::collections::VecDeque::from([alternative, initial.as_str()]);
    assert_eq!(im.capture(), Ok(initial.clone()));

    // B becomes visible while the queued A can still overwrite it.
    let mut current = queued.pop_front().expect("first selection");
    if im.selection.needs_selection(current, alternative) {
        im.selection.record_request(alternative);
        queued.push_back(alternative);
    }
    for selected in queued {
        current = selected;
    }
    assert_eq!(current, alternative, "latest requested source must win");
}

#[test]
fn t_matching_queries_do_not_clear_a_conflicting_submission() {
    let mut state = SelectionState::default();
    state.record_request("source.chinese");
    state.record_request("source.english");
    assert!(state.needs_selection("source.chinese", "source.chinese"));

    assert!(!state.needs_selection("source.english", "source.english"));
    assert!(state.needs_selection("source.chinese", "source.chinese"));
    assert_eq!(
        state.last_submitted_source_id.as_deref(),
        Some("source.english")
    );
}

#[test]
fn t_a_different_last_submission_requires_one_conservative_request() {
    let mut state = SelectionState::default();
    state.record_request("source.chinese");
    assert!(state.needs_selection("source.english", "source.english"));
    state.record_request("source.english");
    assert!(!state.needs_selection("source.english", "source.english"));
    assert!(state.needs_selection("source.english", "source.chinese"));
}

#[test]
fn t_restoring_the_current_source_does_not_submit_selection() {
    let _guard = lock_native_test();
    let mut im = Backend::default();
    let current = im.capture().expect("capture current source");
    for _ in 0..3 {
        im.restore(&current).expect("restore current source");
        assert!(im.selection.last_submitted_source_id.is_none());
    }
}

#[test]
fn t_restore_supersedes_a_conflicting_last_submission() {
    let _guard = lock_native_test();
    let mut im = Backend::default();
    let current = im.capture().expect("capture current source");
    im.selection.record_request("dev.yoz.im.pending-source");

    im.restore(&current).expect("submit current source");
    assert_eq!(
        im.selection.last_submitted_source_id.as_deref(),
        Some(current.as_str())
    );

    im.restore(&current)
        .expect("observe submitted current source");
    assert_eq!(
        im.selection.last_submitted_source_id.as_deref(),
        Some(current.as_str())
    );
}

#[test]
fn t_failed_restore_preserves_the_last_successful_submission() {
    let _guard = lock_native_test();
    let mut im = Backend::default();
    im.capture().expect("capture current source");
    im.selection.record_request("dev.yoz.im.pending-source");

    assert!(im.restore("dev.yoz.im.does-not-exist").is_err());
    assert_eq!(
        im.selection.last_submitted_source_id.as_deref(),
        Some("dev.yoz.im.pending-source")
    );
}

#[test]
fn t_latest_intent_wins_with_delayed_queries_and_fifo_selections() {
    for scenario in 0_u16..4096 {
        let mut state = SelectionState::default();
        let mut current = "source.english";
        let mut observed = current;
        let mut requested = current;
        let mut queued = std::collections::VecDeque::new();
        for step in 0..4 {
            let actions = (scenario >> (step * 3)) & 7;
            if actions & 2 != 0
                && let Some(selected) = queued.pop_front()
            {
                current = selected;
            }
            if actions & 4 != 0 {
                observed = current;
            }
            requested = if actions & 1 == 0 {
                "source.english"
            } else {
                "source.chinese"
            };
            if state.needs_selection(observed, requested) {
                state.record_request(requested);
                queued.push_back(requested);
            }
        }
        for selected in queued {
            current = selected;
        }
        assert_eq!(current, requested, "interleaving {scenario}");
    }
}
