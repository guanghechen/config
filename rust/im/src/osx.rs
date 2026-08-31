//! macOS backend using Text Input Source Services.

use std::collections::HashMap;
use std::ffi::{CStr, c_char, c_void};
use std::ptr::{self, NonNull};

use super::InputMethod;

type Boolean = u8;
type CFHashCode = usize;
type CFIndex = isize;
type CFStringEncoding = u32;
type CFTypeRef = *const c_void;
type CFAllocatorRef = *const c_void;
type CFStringRef = *const c_void;
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
const NO_ERR: OSStatus = 0;
const ENGLISH_SOURCE_ID: &str = "com.apple.keylayout.ABC";
const CHINESE_SOURCE_ID: &str = "com.apple.inputmethod.SCIM.ITABC";

#[link(name = "Carbon", kind = "framework")]
unsafe extern "C" {
    static kTISPropertyInputSourceID: CFStringRef;

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
    static kCFTypeDictionaryKeyCallBacks: CFDictionaryKeyCallBacks;
    static kCFTypeDictionaryValueCallBacks: CFDictionaryValueCallBacks;

    fn CFRetain(cf: CFTypeRef) -> CFTypeRef;
    fn CFRelease(cf: CFTypeRef);
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

pub(super) fn input_method(source_id: &str) -> Option<InputMethod> {
    match source_id {
        ENGLISH_SOURCE_ID => Some(InputMethod::English),
        CHINESE_SOURCE_ID => Some(InputMethod::Chinese),
        _ => None,
    }
}

pub(super) fn source_id_for(input_method: InputMethod) -> &'static str {
    match input_method {
        InputMethod::English => ENGLISH_SOURCE_ID,
        InputMethod::Chinese => CHINESE_SOURCE_ID,
    }
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

fn copy_current() -> Result<(String, OwnedCFRef), String> {
    let reference = unsafe { TISCopyCurrentKeyboardInputSource() };
    let im = unsafe { OwnedCFRef::from_created(reference.cast(), "im.current")? };
    let source_id = source_id(im.as_ptr().cast(), "im.current")?;
    Ok((source_id, im))
}

fn copy_ascii_capable() -> Option<(String, OwnedCFRef)> {
    let reference = unsafe { TISCopyCurrentASCIICapableKeyboardInputSource() };
    let im = unsafe { OwnedCFRef::from_created(reference.cast(), "im.select").ok()? };
    let source_id = source_id(im.as_ptr().cast(), "im.select").ok()?;
    Some((source_id, im))
}

fn resolve(source_id: &str) -> Result<OwnedCFRef, String> {
    if let Some((ascii_source_id, im)) = copy_ascii_capable()
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

#[derive(Default)]
pub struct Backend {
    cache: HashMap<String, OwnedCFRef>,
}

impl Backend {
    pub fn current(&mut self) -> Result<String, String> {
        let (source_id, im) = copy_current()?;
        self.cache.insert(source_id.clone(), im);
        Ok(source_id)
    }

    pub fn select(&mut self, source_id: &str) -> Result<(), String> {
        validate_source_id(source_id)?;
        if !self.cache.contains_key(source_id) {
            self.current()?;
            if !self.cache.contains_key(source_id) {
                self.cache.insert(source_id.to_owned(), resolve(source_id)?);
            }
        }
        let im = self.cache.get(source_id).ok_or_else(|| {
            format!("[im.select] Resolved input source was not cached: {source_id}")
        })?;
        let im = im.as_ptr();
        // Selection becomes observable asynchronously. Always submit the latest request;
        // a current-source read may still reflect an earlier pending selection.
        let status = unsafe { TISSelectInputSource(im.cast()) };
        if status != NO_ERR {
            self.cache.remove(source_id);
            return Err(format!(
                "[im.select] Failed to select {source_id}: OSStatus {status}"
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::{
        Backend, InputMethod, copy_ascii_capable, input_method, resolve, source_id,
        validate_source_id,
    };

    #[test]
    fn t_rejects_invalid_source_ids() {
        assert!(validate_source_id("").is_err());
        assert!(validate_source_id("invalid\0source").is_err());
    }

    #[test]
    fn t_maps_input_methods() {
        assert_eq!(
            input_method("com.apple.keylayout.ABC"),
            Some(InputMethod::English)
        );
        assert_eq!(
            input_method("com.apple.inputmethod.SCIM.ITABC"),
            Some(InputMethod::Chinese)
        );
        assert_eq!(input_method("com.apple.inputmethod.Kotoeri.Japanese"), None);
    }

    #[test]
    fn t_reads_current_ascii_and_unknown_sources_without_changing_current_source() {
        let mut im = Backend::default();
        let before = im.current().expect("read current input source");

        let (expected, _) = copy_ascii_capable().expect("read current ASCII-capable source");
        let resolved = resolve(&expected).expect("resolve current ASCII-capable source");
        assert_eq!(source_id(resolved.as_ptr().cast(), "im.test"), Ok(expected));

        let error = im
            .select("dev.yoz.im.does-not-exist")
            .expect_err("unknown source must fail");

        assert!(error.contains("Enabled input source not found"));
        assert_eq!(im.current(), Ok(before));
    }
}
