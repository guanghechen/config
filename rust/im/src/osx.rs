//! macOS backend using Text Input Source Services.

use std::collections::HashMap;
use std::ffi::{CStr, c_char, c_void};
use std::ptr::{self, NonNull};

use super::CaptureAndSelectError;

type Boolean = u8;
type CFHashCode = usize;
type CFIndex = isize;
type CFTimeInterval = f64;
type CFStringEncoding = u32;
type CFTypeRef = *const c_void;
type CFAllocatorRef = *const c_void;
type CFStringRef = *const c_void;
type CFBooleanRef = *const c_void;
type CFDictionaryRef = *const c_void;
type CFArrayRef = *const c_void;
type TISInputSourceRef = *const c_void;
type OSStatus = i32;

type CFDictionaryRetainCallBack =
    Option<unsafe extern "C" fn(CFAllocatorRef, *const c_void) -> *const c_void>;
type CFDictionaryReleaseCallBack = Option<unsafe extern "C" fn(CFAllocatorRef, *const c_void)>;
type CFDictionaryCopyDescriptionCallBack =
    Option<unsafe extern "C" fn(*const c_void) -> CFStringRef>;
type CFDictionaryEqualCallBack =
    Option<unsafe extern "C" fn(*const c_void, *const c_void) -> Boolean>;
type CFDictionaryHashCallBack = Option<unsafe extern "C" fn(*const c_void) -> CFHashCode>;

#[repr(C)]
struct CFDictionaryKeyCallBacks {
    version: CFIndex,
    retain: CFDictionaryRetainCallBack,
    release: CFDictionaryReleaseCallBack,
    copy_description: CFDictionaryCopyDescriptionCallBack,
    equal: CFDictionaryEqualCallBack,
    hash: CFDictionaryHashCallBack,
}

#[repr(C)]
struct CFDictionaryValueCallBacks {
    version: CFIndex,
    retain: CFDictionaryRetainCallBack,
    release: CFDictionaryReleaseCallBack,
    copy_description: CFDictionaryCopyDescriptionCallBack,
    equal: CFDictionaryEqualCallBack,
}

const CF_STRING_ENCODING_UTF8: CFStringEncoding = 0x0800_0100;
const CF_RUN_LOOP_FINISHED: i32 = 1;
const CF_RUN_LOOP_TIMED_OUT: i32 = 3;
const CF_RUN_LOOP_HANDLED_SOURCE: i32 = 4;
const MAX_NOTIFICATION_PASSES: usize = 32;
const NO_ERR: OSStatus = 0;

#[link(name = "Carbon", kind = "framework")]
unsafe extern "C" {
    static kTISPropertyInputSourceID: CFStringRef;
    static kTISPropertyInputSourceIsASCIICapable: CFStringRef;

    fn TISCopyCurrentKeyboardInputSource() -> TISInputSourceRef;
    fn TISCopyCurrentASCIICapableKeyboardInputSource() -> TISInputSourceRef;
    fn TISGetInputSourceProperty(im: TISInputSourceRef, property_key: CFStringRef)
    -> *const c_void;
    fn TISCreateInputSourceList(
        properties: CFDictionaryRef,
        include_all_installed: Boolean,
    ) -> CFArrayRef;
    fn TISSelectInputSource(im: TISInputSourceRef) -> OSStatus;
}

#[link(name = "CoreFoundation", kind = "framework")]
unsafe extern "C" {
    static kCFRunLoopDefaultMode: CFStringRef;
    static kCFTypeDictionaryKeyCallBacks: CFDictionaryKeyCallBacks;
    static kCFTypeDictionaryValueCallBacks: CFDictionaryValueCallBacks;

    fn CFRunLoopRunInMode(
        mode: CFStringRef,
        seconds: CFTimeInterval,
        return_after_source_handled: Boolean,
    ) -> i32;
    fn CFRetain(cf: CFTypeRef) -> CFTypeRef;
    fn CFRelease(cf: CFTypeRef);
    fn CFBooleanGetValue(boolean: CFBooleanRef) -> Boolean;
    fn CFStringCreateWithBytes(
        allocator: CFAllocatorRef,
        bytes: *const u8,
        byte_count: CFIndex,
        encoding: CFStringEncoding,
        is_external_representation: Boolean,
    ) -> CFStringRef;
    fn CFStringGetLength(string: CFStringRef) -> CFIndex;
    fn CFStringGetMaximumSizeForEncoding(length: CFIndex, encoding: CFStringEncoding) -> CFIndex;
    fn CFStringGetCString(
        string: CFStringRef,
        buffer: *mut c_char,
        buffer_size: CFIndex,
        encoding: CFStringEncoding,
    ) -> Boolean;
    fn CFDictionaryCreate(
        allocator: CFAllocatorRef,
        keys: *const *const c_void,
        values: *const *const c_void,
        count: CFIndex,
        key_callbacks: *const CFDictionaryKeyCallBacks,
        value_callbacks: *const CFDictionaryValueCallBacks,
    ) -> CFDictionaryRef;
    fn CFArrayGetCount(array: CFArrayRef) -> CFIndex;
    fn CFArrayGetValueAtIndex(array: CFArrayRef, index: CFIndex) -> *const c_void;
}

struct OwnedCFRef(NonNull<c_void>);

impl OwnedCFRef {
    unsafe fn from_created(reference: CFTypeRef, subject: &str) -> Result<Self, String> {
        NonNull::new(reference.cast_mut())
            .map(Self)
            .ok_or_else(|| format!("[{subject}] CoreFoundation returned a null reference"))
    }

    fn as_ptr(&self) -> CFTypeRef {
        self.0.as_ptr().cast_const()
    }

    fn retain(reference: CFTypeRef, subject: &str) -> Result<Self, String> {
        let retained = unsafe { CFRetain(reference) };
        unsafe { Self::from_created(retained, subject) }
    }
}

impl Drop for OwnedCFRef {
    fn drop(&mut self) {
        unsafe { CFRelease(self.as_ptr()) };
    }
}

fn validate_source_id(source_id: &str) -> Result<(), String> {
    if source_id.is_empty() {
        return Err("[im.select] Input source ID must not be empty".to_owned());
    }
    if source_id.as_bytes().contains(&0) {
        return Err("[im.select] Input source ID must not contain NUL bytes".to_owned());
    }
    Ok(())
}

fn cf_string_to_string(string: CFStringRef, subject: &str) -> Result<String, String> {
    if string.is_null() {
        return Err(format!("[{subject}] Input source has no ID property"));
    }

    let length = unsafe { CFStringGetLength(string) };
    let max_size = unsafe { CFStringGetMaximumSizeForEncoding(length, CF_STRING_ENCODING_UTF8) };
    let buffer_size = max_size
        .checked_add(1)
        .filter(|size| *size > 0)
        .ok_or_else(|| format!("[{subject}] Invalid UTF-8 buffer size: {max_size}"))?;
    let capacity = usize::try_from(buffer_size)
        .map_err(|_| format!("[{subject}] UTF-8 buffer is too large: {buffer_size}"))?;
    let mut buffer = vec![0_u8; capacity];

    let converted = unsafe {
        CFStringGetCString(
            string,
            buffer.as_mut_ptr().cast(),
            buffer_size,
            CF_STRING_ENCODING_UTF8,
        )
    };
    if converted == 0 {
        return Err(format!(
            "[{subject}] Failed to convert input source ID to UTF-8"
        ));
    }

    let value = unsafe { CStr::from_ptr(buffer.as_ptr().cast()) }
        .to_str()
        .map_err(|error| format!("[{subject}] Input source ID is not valid UTF-8: {error}"))?;
    if value.is_empty() {
        return Err(format!("[{subject}] Input source ID is empty"));
    }
    Ok(value.to_owned())
}

fn source_id(im: TISInputSourceRef, subject: &str) -> Result<String, String> {
    if im.is_null() {
        return Err(format!("[{subject}] Input source reference is null"));
    }

    let property_key = unsafe { kTISPropertyInputSourceID };
    if property_key.is_null() {
        return Err(format!("[{subject}] Input source ID property key is null"));
    }
    let property = unsafe { TISGetInputSourceProperty(im, property_key) };
    cf_string_to_string(property.cast(), subject)
}

fn is_ascii_capable(im: TISInputSourceRef, subject: &str) -> Result<bool, String> {
    if im.is_null() {
        return Err(format!("[{subject}] Input source reference is null"));
    }
    let property_key = unsafe { kTISPropertyInputSourceIsASCIICapable };
    if property_key.is_null() {
        return Err(format!(
            "[{subject}] ASCII-capable input source property key is null"
        ));
    }
    let property = unsafe { TISGetInputSourceProperty(im, property_key) };
    if property.is_null() {
        return Err(format!(
            "[{subject}] Input source has no ASCII-capable property"
        ));
    }
    Ok(unsafe { CFBooleanGetValue(property.cast()) } != 0)
}

fn refresh_notifications() -> Result<(), String> {
    // TIS refreshes its process-local state through CFRunLoop notifications, while Neovim drives
    // libuv. One zero-time call can handle just one source. Drain the queue without waiting
    // for future events, but bound the work if a source continually reschedules itself.
    for _ in 0..MAX_NOTIFICATION_PASSES {
        let result = unsafe { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, 1) };
        match result {
            CF_RUN_LOOP_FINISHED | CF_RUN_LOOP_TIMED_OUT => return Ok(()),
            CF_RUN_LOOP_HANDLED_SOURCE => continue,
            _ => {
                return Err(format!(
                    "[im.capture] Input-source notification refresh was interrupted (CFRunLoop {result})"
                ));
            }
        }
    }
    Err(
        "[im.capture] Input-source notifications are still busy; cannot refresh the snapshot"
            .to_owned(),
    )
}

fn copy_current() -> Result<(String, OwnedCFRef), String> {
    refresh_notifications()?;
    let reference = unsafe { TISCopyCurrentKeyboardInputSource() };
    let im = unsafe { OwnedCFRef::from_created(reference.cast(), "im.capture")? };
    let source_id = source_id(im.as_ptr().cast(), "im.capture")?;
    Ok((source_id, im))
}

fn copy_ascii_capable() -> Result<(String, OwnedCFRef), String> {
    let reference = unsafe { TISCopyCurrentASCIICapableKeyboardInputSource() };
    let im = unsafe { OwnedCFRef::from_created(reference.cast(), "im.select")? };
    let source_id = source_id(im.as_ptr().cast(), "im.select")?;
    Ok((source_id, im))
}

fn resolve(source_id: &str) -> Result<OwnedCFRef, String> {
    if let Ok((ascii_source_id, im)) = copy_ascii_capable()
        && ascii_source_id == source_id
    {
        return Ok(im);
    }

    let byte_count = CFIndex::try_from(source_id.len()).map_err(|_| {
        format!(
            "[im.select] Input source ID is too large: {} bytes",
            source_id.len()
        )
    })?;
    let filter_value = unsafe {
        OwnedCFRef::from_created(
            CFStringCreateWithBytes(
                ptr::null(),
                source_id.as_ptr(),
                byte_count,
                CF_STRING_ENCODING_UTF8,
                0,
            )
            .cast(),
            "im.select",
        )?
    };

    let property_key = unsafe { kTISPropertyInputSourceID };
    if property_key.is_null() {
        return Err("[im.select] Input source ID property key is null".to_owned());
    }
    let keys = [property_key.cast()];
    let values = [filter_value.as_ptr()];
    let filter = unsafe {
        OwnedCFRef::from_created(
            CFDictionaryCreate(
                ptr::null(),
                keys.as_ptr(),
                values.as_ptr(),
                1,
                ptr::addr_of!(kCFTypeDictionaryKeyCallBacks),
                ptr::addr_of!(kCFTypeDictionaryValueCallBacks),
            )
            .cast(),
            "im.select",
        )?
    };
    let matches = unsafe { TISCreateInputSourceList(filter.as_ptr().cast(), 0) };
    if matches.is_null() {
        return Err(format!(
            "[im.select] Enabled input source not found: {source_id}"
        ));
    }
    let matches = unsafe { OwnedCFRef::from_created(matches.cast(), "im.select")? };

    let count = unsafe { CFArrayGetCount(matches.as_ptr().cast()) };
    if count == 0 {
        return Err(format!(
            "[im.select] Enabled input source not found: {source_id}"
        ));
    }
    if count != 1 {
        return Err(format!(
            "[im.select] Expected one enabled input source for {source_id}, found {count}"
        ));
    }

    let reference = unsafe { CFArrayGetValueAtIndex(matches.as_ptr().cast(), 0) };
    if reference.is_null() {
        return Err(format!(
            "[im.select] Input source list contains a null reference: {source_id}"
        ));
    }
    OwnedCFRef::retain(reference.cast(), "im.select")
}

fn select_input_source(im: TISInputSourceRef, source_id: &str) -> Result<(), String> {
    // A successful request can become observable through TIS notifications later.
    let status = unsafe { TISSelectInputSource(im) };
    if status != NO_ERR {
        return Err(format!(
            "[im.select] Failed to select {source_id}: OSStatus {status}"
        ));
    }
    Ok(())
}

#[derive(Default)]
struct SelectionState {
    // A matching read can predate queued requests, so it cannot acknowledge a submission.
    last_submitted_source_id: Option<String>,
}

impl SelectionState {
    fn needs_selection(&self, current: &str, requested: &str) -> bool {
        current != requested
            || self
                .last_submitted_source_id
                .as_deref()
                .is_some_and(|submitted| submitted != requested)
    }

    fn record_request(&mut self, source_id: &str) {
        self.last_submitted_source_id = Some(source_id.to_owned());
    }
}

#[derive(Default)]
pub struct Backend {
    cache: HashMap<String, OwnedCFRef>,
    selection: SelectionState,
}

impl Backend {
    pub fn capture(&mut self) -> Result<String, String> {
        let (source_id, im) = copy_current()?;
        self.cache.insert(source_id.clone(), im);
        Ok(source_id)
    }

    fn resolve_cached(&mut self, source_id: &str) -> Result<&OwnedCFRef, String> {
        validate_source_id(source_id)?;
        if !self.cache.contains_key(source_id) {
            self.capture()?;
            if !self.cache.contains_key(source_id) {
                self.cache.insert(source_id.to_owned(), resolve(source_id)?);
            }
        }
        let im = self.cache.get(source_id).ok_or_else(|| {
            format!("[im.select] Resolved input source was not cached: {source_id}")
        })?;
        Ok(im)
    }

    fn select(&mut self, source_id: &str) -> Result<(), String> {
        validate_source_id(source_id)?;
        // A failed fresh read disables the shortcut, but still permits exact restoration.
        if let Ok(current) = self.capture()
            && !self.selection.needs_selection(&current, source_id)
        {
            return Ok(());
        }

        let im = self.resolve_cached(source_id)?.as_ptr();
        if let Err(error) = select_input_source(im.cast(), source_id) {
            self.cache.remove(source_id);
            return Err(error);
        }
        self.selection.record_request(source_id);
        Ok(())
    }

    pub fn capture_and_select_english(&mut self) -> Result<String, CaptureAndSelectError> {
        let (snapshot, current) = copy_current().map_err(CaptureAndSelectError::Capture)?;
        let english = is_ascii_capable(current.as_ptr().cast(), "im.capture_and_select_english")
            .map_err(|error| CaptureAndSelectError::Select {
                snapshot: snapshot.clone(),
                error,
            })?;
        self.cache.insert(snapshot.clone(), current);
        // An earlier non-English restore may still be pending despite this English read.
        if english && !self.selection.needs_selection(&snapshot, &snapshot) {
            return Ok(snapshot);
        }

        let (english_source_id, english_source) =
            copy_ascii_capable().map_err(|error| CaptureAndSelectError::Select {
                snapshot: snapshot.clone(),
                error,
            })?;
        select_input_source(english_source.as_ptr().cast(), &english_source_id).map_err(
            |error| CaptureAndSelectError::Select {
                snapshot: snapshot.clone(),
                error,
            },
        )?;
        self.selection.record_request(&english_source_id);
        self.cache.insert(english_source_id, english_source);
        Ok(snapshot)
    }

    pub fn restore(&mut self, source_id: &str) -> Result<(), String> {
        self.select(source_id)
    }

    pub fn is_english(&mut self, source_id: &str) -> bool {
        self.resolve_cached(source_id)
            .and_then(|im| is_ascii_capable(im.as_ptr().cast(), "im.is_english"))
            .unwrap_or(false)
    }
}

#[cfg(test)]
mod tests {
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
}
