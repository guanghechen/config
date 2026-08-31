//! Windows backend and language-ID mapping shared with WSL.

use super::InputMethod;

const ENGLISH_LANGUAGE_ID: u16 = 1033;
const CHINESE_LANGUAGE_ID: u16 = 2052;

fn language_id(source_id: &str) -> Option<u16> {
    let input_locale = source_id.parse::<u64>().ok()?;
    Some((input_locale & u64::from(u16::MAX)) as u16)
}

pub(super) fn input_method(source_id: &str) -> Option<InputMethod> {
    match language_id(source_id) {
        Some(ENGLISH_LANGUAGE_ID) => Some(InputMethod::English),
        Some(CHINESE_LANGUAGE_ID) => Some(InputMethod::Chinese),
        _ => None,
    }
}

pub(super) fn source_id_for(input_method: InputMethod) -> &'static str {
    match input_method {
        InputMethod::English => "1033",
        InputMethod::Chinese => "2052",
    }
}

#[cfg(any(target_os = "windows", test))]
pub(super) fn input_locale_matches(current: u64, requested: u64) -> bool {
    if requested <= u64::from(u16::MAX) {
        current & u64::from(u16::MAX) == requested
    } else {
        current == requested
    }
}

#[cfg(target_os = "windows")]
mod native {
    use std::ffi::c_void;
    use std::ptr;

    use super::input_locale_matches;
    type Dword = u32;
    type Hkl = *mut c_void;
    type Hwnd = *mut c_void;
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

    fn last_error(subject: &str) -> String {
        let code = unsafe { GetLastError() };
        format!("[{subject}] Windows error {code}")
    }

    fn foreground_window(subject: &str) -> Result<Hwnd, String> {
        let hwnd = unsafe { GetForegroundWindow() };
        if hwnd.is_null() {
            return Err(format!("[{subject}] No foreground window"));
        }
        Ok(hwnd)
    }

    fn window_thread(hwnd: Hwnd, subject: &str) -> Result<Dword, String> {
        let thread_id = unsafe { GetWindowThreadProcessId(hwnd, ptr::null_mut()) };
        if thread_id == 0 {
            return Err(last_error(subject));
        }
        Ok(thread_id)
    }

    fn keyboard_layout(thread_id: Dword, subject: &str) -> Result<usize, String> {
        let layout = unsafe { GetKeyboardLayout(thread_id) };
        if layout.is_null() {
            return Err(format!("[{subject}] Foreground thread has no input locale"));
        }
        Ok(layout as usize)
    }

    fn parse_source_id(source_id: &str) -> Result<usize, String> {
        let input_locale = source_id.parse::<usize>().map_err(|error| {
            format!("[im.select] Invalid Windows input locale {source_id:?}: {error}")
        })?;
        if input_locale == 0 {
            return Err("[im.select] Windows input locale must not be zero".to_owned());
        }
        Ok(input_locale)
    }

    #[derive(Default)]
    pub struct Backend;

    impl Backend {
        pub fn current(&mut self) -> Result<String, String> {
            let hwnd = foreground_window("im.current")?;
            let thread_id = window_thread(hwnd, "im.current")?;
            let input_locale = keyboard_layout(thread_id, "im.current")?;
            Ok(input_locale.to_string())
        }

        pub fn select(&mut self, source_id: &str) -> Result<(), String> {
            let input_locale = parse_source_id(source_id)?;
            let hwnd = foreground_window("im.select")?;
            let thread_id = window_thread(hwnd, "im.select")?;
            if input_locale_matches(
                keyboard_layout(thread_id, "im.select")? as u64,
                input_locale as u64,
            ) {
                return Ok(());
            }

            let mut result = 0;
            unsafe { SetLastError(0) };
            let sent = unsafe {
                SendMessageTimeoutW(
                    hwnd,
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
                    Err("[im.select] Failed to request input locale".to_owned())
                } else {
                    Err(format!("[im.select] Windows error {error_code}"))
                };
            }
            let selected = keyboard_layout(thread_id, "im.select")?;
            if !input_locale_matches(selected as u64, input_locale as u64) {
                return Err(format!(
                    "[im.select] Foreground window did not select {source_id}; current input locale is {selected}"
                ));
            }
            Ok(())
        }
    }

    #[cfg(test)]
    mod tests {
        use super::super::input_locale_matches;
        use super::parse_source_id;

        #[test]
        fn t_parses_decimal_input_locales() {
            assert_eq!(parse_source_id("1033"), Ok(1033));
            assert_eq!(parse_source_id("2052"), Ok(2052));
            assert_eq!(parse_source_id("67699721"), Ok(67699721));
        }

        #[test]
        fn t_rejects_invalid_input_locales() {
            assert!(parse_source_id("").is_err());
            assert!(parse_source_id("0").is_err());
            assert!(parse_source_id("english").is_err());
        }

        #[test]
        fn t_matches_language_ids_and_exact_layouts() {
            assert!(input_locale_matches(67_699_721, 1033));
            assert!(input_locale_matches(134_481_924, 2052));
            assert!(input_locale_matches(67_699_721, 67_699_721));
            assert!(!input_locale_matches(67_699_721, 134_481_924));
        }
    }
}

#[cfg(target_os = "windows")]
pub use native::Backend;

#[cfg(test)]
mod tests {
    use super::{InputMethod, input_locale_matches, input_method, source_id_for};

    #[test]
    fn t_maps_language_ids_and_full_input_locales() {
        assert_eq!(input_method("1033"), Some(InputMethod::English));
        assert_eq!(input_method("2052"), Some(InputMethod::Chinese));
        assert_eq!(input_method("67699721"), Some(InputMethod::English));
        assert_eq!(input_method("134481924"), Some(InputMethod::Chinese));
        assert_eq!(input_method("18446744073709552649"), None);
        assert_eq!(input_method("invalid"), None);
    }

    #[test]
    fn t_maps_semantic_methods_to_language_ids() {
        assert_eq!(source_id_for(InputMethod::English), "1033");
        assert_eq!(source_id_for(InputMethod::Chinese), "2052");
    }

    #[test]
    fn t_matches_semantic_language_ids_and_exact_input_locales() {
        assert!(input_locale_matches(67_699_721, 1033));
        assert!(input_locale_matches(134_481_924, 2052));
        assert!(input_locale_matches(67_699_721, 67_699_721));
        assert!(!input_locale_matches(67_699_721, 134_481_924));
    }
}
