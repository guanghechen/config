//! Windows backend and English-source classification shared with WSL.

const ENGLISH_PRIMARY_LANGUAGE_ID: u16 = 0x09;

pub(super) fn is_english(source_id: &str) -> bool {
    source_id.parse::<u64>().is_ok_and(is_english_input_locale)
}

fn is_english_input_locale(input_locale: u64) -> bool {
    let language_id = (input_locale & u64::from(u16::MAX)) as u16;
    language_id & 0x03ff == ENGLISH_PRIMARY_LANGUAGE_ID
}

#[cfg(any(target_os = "windows", test))]
fn first_english_input_locale(input_locales: impl IntoIterator<Item = u64>) -> Option<u64> {
    input_locales
        .into_iter()
        .find(|input_locale| is_english_input_locale(*input_locale))
}

#[cfg(any(target_os = "windows", test))]
pub(super) fn input_locale_matches(current: u64, requested: u64) -> bool {
    current == requested
}

#[cfg(target_os = "windows")]
mod native {
    use std::ffi::c_void;
    use std::ptr;

    use crate::CaptureAndSelectError;

    use super::input_locale_matches;
    type Dword = u32;
    type Hkl = *mut c_void;
    type Hwnd = *mut c_void;
    type Int = i32;
    type Lparam = isize;
    type Lresult = isize;
    type Uint = u32;
    type Wparam = usize;

    const WM_INPUTLANGCHANGEREQUEST: Uint = 0x0050;
    const SMTO_BLOCK: Uint = 0x0001;
    const SMTO_ABORTIFHUNG: Uint = 0x0002;
    const SELECT_TIMEOUT_MS: Uint = 50;

    #[link(name = "user32")]
    unsafe extern "system" {
        fn GetForegroundWindow() -> Hwnd;
        fn GetWindowThreadProcessId(hwnd: Hwnd, process_id: *mut Dword) -> Dword;
        fn GetKeyboardLayout(thread_id: Dword) -> Hkl;
        fn GetKeyboardLayoutList(buffer_size: Int, input_locales: *mut Hkl) -> Int;
        fn SendMessageTimeoutW(
            hwnd: Hwnd,
            message: Uint,
            wparam: Wparam,
            lparam: Lparam,
            flags: Uint,
            timeout: Uint,
            result: *mut Wparam,
        ) -> Lresult;
    }

    #[link(name = "kernel32")]
    unsafe extern "system" {
        fn GetLastError() -> Dword;
        fn SetLastError(error_code: Dword);
    }

    #[derive(Clone, Copy)]
    struct Foreground {
        hwnd: Hwnd,
        thread_id: Dword,
        input_locale: usize,
    }

    fn foreground(subject: &str) -> Result<Foreground, String> {
        let hwnd = unsafe { GetForegroundWindow() };
        if hwnd.is_null() {
            return Err(format!("[{subject}] No foreground window"));
        }
        let thread_id = unsafe { GetWindowThreadProcessId(hwnd, ptr::null_mut()) };
        if thread_id == 0 {
            let code = unsafe { GetLastError() };
            return Err(format!("[{subject}] Windows error {code}"));
        }
        let layout = unsafe { GetKeyboardLayout(thread_id) };
        if layout.is_null() {
            return Err(format!("[{subject}] Foreground thread has no input locale"));
        }
        Ok(Foreground {
            hwnd,
            thread_id,
            input_locale: layout as usize,
        })
    }

    fn parse_source_id(source_id: &str, subject: &str) -> Result<usize, String> {
        let input_locale = source_id.parse::<usize>().map_err(|error| {
            format!("[{subject}] Invalid Windows input locale {source_id:?}: {error}")
        })?;
        if input_locale == 0 {
            return Err(format!("[{subject}] Windows input locale must not be zero"));
        }
        Ok(input_locale)
    }

    fn english_input_locale(subject: &str) -> Result<usize, String> {
        unsafe { SetLastError(0) };
        let count = unsafe { GetKeyboardLayoutList(0, ptr::null_mut()) };
        if count <= 0 {
            let code = unsafe { GetLastError() };
            return Err(format!(
                "[{subject}] Failed to enumerate input locales: Windows error {code}"
            ));
        }

        let mut input_locales = vec![ptr::null_mut(); count as usize];
        let copied = unsafe { GetKeyboardLayoutList(count, input_locales.as_mut_ptr()) };
        if copied <= 0 {
            let code = unsafe { GetLastError() };
            return Err(format!(
                "[{subject}] Failed to read input locales: Windows error {code}"
            ));
        }
        let english_input_locale = super::first_english_input_locale(
            input_locales
                .into_iter()
                .take(copied as usize)
                .map(|input_locale| input_locale as usize as u64),
        );
        english_input_locale
            .map(|input_locale| input_locale as usize)
            .ok_or_else(|| format!("[{subject}] No loaded English input locale"))
    }

    fn select(foreground: Foreground, input_locale: usize, subject: &str) -> Result<(), String> {
        if input_locale_matches(foreground.input_locale as u64, input_locale as u64) {
            return Ok(());
        }

        let mut result = 0;
        unsafe { SetLastError(0) };
        let sent = unsafe {
            SendMessageTimeoutW(
                foreground.hwnd,
                WM_INPUTLANGCHANGEREQUEST,
                0,
                input_locale as Lparam,
                SMTO_BLOCK | SMTO_ABORTIFHUNG,
                SELECT_TIMEOUT_MS,
                &mut result,
            )
        };
        if sent == 0 {
            let error_code = unsafe { GetLastError() };
            return if error_code == 0 {
                Err(format!("[{subject}] Failed to request input locale"))
            } else {
                Err(format!("[{subject}] Windows error {error_code}"))
            };
        }
        let selected = unsafe { GetKeyboardLayout(foreground.thread_id) };
        if selected.is_null() {
            return Err(format!("[{subject}] Foreground thread has no input locale"));
        }
        let selected = selected as usize;
        if !input_locale_matches(selected as u64, input_locale as u64) {
            return Err(format!(
                "[{subject}] Foreground window did not select {input_locale}; current input locale is {selected}"
            ));
        }
        Ok(())
    }

    #[derive(Default)]
    pub struct Backend;

    impl Backend {
        pub fn capture(&mut self) -> Result<String, String> {
            foreground("im.capture").map(|foreground| foreground.input_locale.to_string())
        }

        pub fn capture_and_select_english(&mut self) -> Result<String, CaptureAndSelectError> {
            let subject = "im.capture_and_select_english";
            let foreground = foreground(subject).map_err(CaptureAndSelectError::Capture)?;
            let snapshot = foreground.input_locale.to_string();
            if super::is_english_input_locale(foreground.input_locale as u64) {
                return Ok(snapshot);
            }
            let english_input_locale =
                english_input_locale(subject).map_err(|error| CaptureAndSelectError::Select {
                    snapshot: snapshot.clone(),
                    error,
                })?;
            select(foreground, english_input_locale, subject).map_err(|error| {
                CaptureAndSelectError::Select {
                    snapshot: snapshot.clone(),
                    error,
                }
            })?;
            Ok(snapshot)
        }

        pub fn restore(&mut self, source_id: &str) -> Result<(), String> {
            let subject = "im.restore";
            let input_locale = parse_source_id(source_id, subject)?;
            select(foreground(subject)?, input_locale, subject)
        }

        pub fn is_english(&mut self, source_id: &str) -> bool {
            super::is_english(source_id)
        }
    }

    #[cfg(test)]
    mod tests {
        use super::super::input_locale_matches;
        use super::parse_source_id;

        #[test]
        fn t_parses_decimal_input_locales() {
            assert_eq!(parse_source_id("1033", "test"), Ok(1033));
            assert_eq!(parse_source_id("2052", "test"), Ok(2052));
            assert_eq!(parse_source_id("67699721", "test"), Ok(67699721));
        }

        #[test]
        fn t_rejects_invalid_input_locales() {
            assert!(parse_source_id("", "test").is_err());
            assert!(parse_source_id("0", "test").is_err());
            assert!(parse_source_id("english", "test").is_err());
        }

        #[test]
        fn t_matches_language_ids_and_exact_layouts() {
            assert!(input_locale_matches(1033, 1033));
            assert!(input_locale_matches(67_699_721, 67_699_721));
            assert!(!input_locale_matches(67_699_721, 1033));
            assert!(!input_locale_matches(134_481_924, 2052));
            assert!(!input_locale_matches(67_699_721, 134_481_924));
        }
    }
}

#[cfg(target_os = "windows")]
pub use native::Backend;

#[cfg(test)]
mod tests {
    use super::{first_english_input_locale, input_locale_matches, is_english};

    #[test]
    fn t_classifies_english_language_ids_and_full_input_locales() {
        assert!(is_english("1033"));
        assert!(is_english("2057"));
        assert!(is_english("67699721"));
        assert!(is_english(
            &((u64::from(2057_u16) << 16) | u64::from(2057_u16)).to_string()
        ));
        assert!(!is_english("1041"));
        assert!(!is_english("2052"));
        assert!(!is_english("invalid"));
    }

    #[test]
    fn t_matches_language_ids_and_exact_input_locales() {
        assert!(input_locale_matches(1033, 1033));
        assert!(input_locale_matches(67_699_721, 67_699_721));
        assert!(!input_locale_matches(67_699_721, 1033));
        assert!(!input_locale_matches(134_481_924, 2052));
        assert!(!input_locale_matches(67_699_721, 134_481_924));
    }

    #[test]
    fn t_selects_an_available_english_variant() {
        assert_eq!(
            first_english_input_locale([134_481_924, 134_809_609]),
            Some(134_809_609)
        );
        assert_eq!(first_english_input_locale([134_481_924, 68_224_017]), None);
    }
}
