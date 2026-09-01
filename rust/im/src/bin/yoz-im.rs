#![no_main]
#![no_std]

use core::convert::TryFrom;
use core::ffi::c_void;
use core::mem::MaybeUninit;
use core::ptr;

type Bool = i32;
type Dword = u32;
type Handle = *mut c_void;
type Hkl = *mut c_void;
type Hwnd = *mut c_void;
type Int = i32;
type Lparam = isize;
type Lresult = isize;
type Uint = u32;
type Wparam = usize;

const INVALID_HANDLE_VALUE: Handle = usize::MAX as Handle;
const ENGLISH_PRIMARY_LANGUAGE_ID: usize = 0x09;
const MAX_INPUT_LOCALES: usize = 64;
const SELECT_READBACK_ATTEMPTS: usize = 11;
const SELECT_READBACK_INTERVAL_MS: Dword = 10;
const SELECT_TIMEOUT_MS: Uint = 50;
const SMTO_ABORTIFHUNG: Uint = 0x0002;
const SMTO_BLOCK: Uint = 0x0001;
const STD_ERROR_HANDLE: Dword = (-12_i32) as Dword;
const STD_OUTPUT_HANDLE: Dword = (-11_i32) as Dword;
const WM_INPUTLANGCHANGEREQUEST: Uint = 0x0050;

#[link(name = "kernel32")]
unsafe extern "system" {
    fn ExitProcess(exit_code: Uint) -> !;
    fn GetCommandLineW() -> *const u16;
    fn GetLastError() -> Dword;
    fn GetStdHandle(std_handle: Dword) -> Handle;
    fn SetLastError(error_code: Dword);
    fn Sleep(milliseconds: Dword);
    fn WriteFile(
        file: Handle,
        buffer: *const c_void,
        bytes_to_write: Dword,
        bytes_written: *mut Dword,
        overlapped: *mut c_void,
    ) -> Bool;
}

#[link(name = "user32")]
unsafe extern "system" {
    fn GetForegroundWindow() -> Hwnd;
    fn GetKeyboardLayout(thread_id: Dword) -> Hkl;
    fn GetKeyboardLayoutList(buffer_size: Int, input_locales: *mut Hkl) -> Int;
    fn GetWindowThreadProcessId(hwnd: Hwnd, process_id: *mut Dword) -> Dword;
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

#[derive(Clone, Copy)]
enum CurrentError {
    NoForegroundWindow,
    NoInputLocale,
    Windows(Dword),
}

#[derive(Clone, Copy)]
struct Foreground {
    hwnd: Hwnd,
    thread_id: Dword,
    input_locale: usize,
}

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    unsafe { ExitProcess(70) }
}

fn is_space(value: u16) -> bool {
    value == b' ' as u16 || value == b'\t' as u16 || value == b'\r' as u16 || value == b'\n' as u16
}

fn is_digit(value: u16) -> bool {
    value >= b'0' as u16 && value <= b'9' as u16
}

enum Request {
    Current,
    English,
    Restore(usize),
}

fn request() -> Result<Request, ()> {
    let mut cursor = unsafe { GetCommandLineW() };
    if cursor.is_null() {
        return Err(());
    }

    let first = unsafe { *cursor };
    if first == b'"' as u16 {
        cursor = unsafe { cursor.add(1) };
        while unsafe { *cursor } != 0 && unsafe { *cursor } != b'"' as u16 {
            cursor = unsafe { cursor.add(1) };
        }
        if unsafe { *cursor } == b'"' as u16 {
            cursor = unsafe { cursor.add(1) };
        }
    } else {
        while unsafe { *cursor } != 0 && !is_space(unsafe { *cursor }) {
            cursor = unsafe { cursor.add(1) };
        }
    }

    while is_space(unsafe { *cursor }) {
        cursor = unsafe { cursor.add(1) };
    }
    if unsafe { *cursor } == 0 {
        return Ok(Request::Current);
    }

    let argument = cursor;
    let mut english_cursor = cursor;
    let mut english = true;
    for expected in b"--english" {
        if unsafe { *english_cursor } != u16::from(*expected) {
            english = false;
            break;
        }
        english_cursor = unsafe { english_cursor.add(1) };
    }
    if english {
        while is_space(unsafe { *english_cursor }) {
            english_cursor = unsafe { english_cursor.add(1) };
        }
        if unsafe { *english_cursor } == 0 {
            return Ok(Request::English);
        }
    }

    cursor = argument;
    let mut value = 0_usize;
    let mut digits = 0_usize;
    while is_digit(unsafe { *cursor }) {
        value = value
            .checked_mul(10)
            .and_then(|current| current.checked_add(usize::from(unsafe { *cursor } - b'0' as u16)))
            .ok_or(())?;
        digits += 1;
        cursor = unsafe { cursor.add(1) };
    }
    if digits == 0 || value == 0 {
        return Err(());
    }
    while is_space(unsafe { *cursor }) {
        cursor = unsafe { cursor.add(1) };
    }
    if unsafe { *cursor } != 0 {
        return Err(());
    }
    Ok(Request::Restore(value))
}

fn current_input_locale() -> Result<Foreground, CurrentError> {
    let hwnd = unsafe { GetForegroundWindow() };
    if hwnd.is_null() {
        return Err(CurrentError::NoForegroundWindow);
    }
    let thread_id = unsafe { GetWindowThreadProcessId(hwnd, ptr::null_mut()) };
    if thread_id == 0 {
        return Err(CurrentError::Windows(unsafe { GetLastError() }));
    }
    let layout = unsafe { GetKeyboardLayout(thread_id) };
    if layout.is_null() {
        return Err(CurrentError::NoInputLocale);
    }
    Ok(Foreground {
        hwnd,
        thread_id,
        input_locale: layout as usize,
    })
}

fn std_handle(kind: Dword) -> Option<Handle> {
    let handle = unsafe { GetStdHandle(kind) };
    (!handle.is_null() && handle != INVALID_HANDLE_VALUE).then_some(handle)
}

fn write_raw(handle: Handle, mut bytes: *const u8, mut len: usize) -> bool {
    while len > 0 {
        let Ok(bytes_to_write) = Dword::try_from(len) else {
            return false;
        };
        let mut bytes_written = 0;
        let written = unsafe {
            WriteFile(
                handle,
                bytes.cast(),
                bytes_to_write,
                &mut bytes_written,
                ptr::null_mut(),
            )
        };
        if written == 0 || bytes_written == 0 {
            return false;
        }
        bytes = unsafe { bytes.add(bytes_written as usize) };
        len -= bytes_written as usize;
    }
    true
}

fn write_bytes(handle: Handle, bytes: &[u8]) -> bool {
    write_raw(handle, bytes.as_ptr(), bytes.len())
}

fn write_decimal(handle: Handle, value: usize) -> bool {
    let mut buffer = [0_u8; 21];
    let buffer_ptr = buffer.as_mut_ptr();
    let mut cursor = buffer.len() - 1;
    unsafe { *buffer_ptr.add(cursor) = b'\n' };
    let mut remaining = value;
    loop {
        cursor -= 1;
        unsafe { *buffer_ptr.add(cursor) = b'0' + (remaining % 10) as u8 };
        remaining /= 10;
        if remaining == 0 {
            break;
        }
    }
    write_raw(
        handle,
        unsafe { buffer_ptr.add(cursor) },
        buffer.len() - cursor,
    )
}

fn exit_error(message: &[u8], windows_error: Option<Dword>) -> ! {
    if let Some(stderr) = std_handle(STD_ERROR_HANDLE) {
        let _ = write_bytes(stderr, message);
        if let Some(code) = windows_error {
            let _ = write_bytes(stderr, b": Windows error ");
            let _ = write_decimal(stderr, code as usize);
        } else {
            let _ = write_bytes(stderr, b"\n");
        }
    }
    unsafe { ExitProcess(1) }
}

fn current_or_exit() -> Foreground {
    match current_input_locale() {
        Ok(foreground) => foreground,
        Err(CurrentError::NoForegroundWindow) => exit_error(b"No foreground window", None),
        Err(CurrentError::NoInputLocale) => {
            exit_error(b"Foreground thread has no input locale", None)
        }
        Err(CurrentError::Windows(code)) => {
            exit_error(b"Failed to inspect foreground window", Some(code))
        }
    }
}

fn write_source_or_exit(source_id: usize) {
    let Some(stdout) = std_handle(STD_OUTPUT_HANDLE) else {
        unsafe { ExitProcess(1) }
    };
    if !write_decimal(stdout, source_id) {
        unsafe { ExitProcess(1) }
    }
}

fn is_english(input_locale: usize) -> bool {
    let language_id = input_locale & usize::from(u16::MAX);
    language_id & 0x03ff == ENGLISH_PRIMARY_LANGUAGE_ID
}

fn input_locale_matches(current: usize, requested: usize) -> bool {
    current == requested
}

fn english_input_locale_or_exit() -> usize {
    unsafe { SetLastError(0) };
    let count = unsafe { GetKeyboardLayoutList(0, ptr::null_mut()) };
    if count <= 0 {
        exit_error(
            b"Failed to enumerate input locales",
            Some(unsafe { GetLastError() }),
        );
    }
    if count as usize > MAX_INPUT_LOCALES {
        exit_error(b"Too many loaded input locales", None);
    }

    let mut input_locales = [const { MaybeUninit::<Hkl>::uninit() }; MAX_INPUT_LOCALES];
    let copied = unsafe { GetKeyboardLayoutList(count, input_locales.as_mut_ptr().cast()) };
    if copied <= 0 {
        exit_error(
            b"Failed to read input locales",
            Some(unsafe { GetLastError() }),
        );
    }
    if copied as usize > MAX_INPUT_LOCALES {
        exit_error(b"Input locale count exceeded buffer", None);
    }
    let mut index = 0_usize;
    while index < copied as usize {
        let input_locale =
            unsafe { input_locales.as_ptr().add(index).read().assume_init() } as usize;
        if is_english(input_locale) {
            return input_locale;
        }
        index += 1;
    }
    exit_error(b"No loaded English input locale", None)
}

fn select_input_locale(foreground: Foreground, requested: usize, english: bool) -> ! {
    let current = foreground.input_locale;
    let matches = if english {
        is_english(current)
    } else {
        input_locale_matches(current, requested)
    };
    if matches {
        unsafe { ExitProcess(0) }
    }

    let mut message_result = 0;
    unsafe { SetLastError(0) };
    let sent = unsafe {
        SendMessageTimeoutW(
            foreground.hwnd,
            WM_INPUTLANGCHANGEREQUEST,
            0,
            requested as isize,
            SMTO_BLOCK | SMTO_ABORTIFHUNG,
            SELECT_TIMEOUT_MS,
            &mut message_result,
        )
    };
    if sent == 0 {
        let error_code = unsafe { GetLastError() };
        if error_code == 0 {
            exit_error(b"Failed to request input locale", None);
        }
        exit_error(b"Failed to request input locale", Some(error_code));
    }

    for attempt in 0..SELECT_READBACK_ATTEMPTS {
        let selected = unsafe { GetKeyboardLayout(foreground.thread_id) };
        if !selected.is_null() {
            let selected = selected as usize;
            let matches = if english {
                is_english(selected)
            } else {
                input_locale_matches(selected, requested)
            };
            if matches {
                unsafe { ExitProcess(0) }
            }
        }
        if attempt + 1 < SELECT_READBACK_ATTEMPTS {
            unsafe { Sleep(SELECT_READBACK_INTERVAL_MS) };
        }
    }
    exit_error(b"Foreground input locale did not change", None)
}

#[unsafe(no_mangle)]
pub extern "C" fn mainCRTStartup() -> ! {
    match request() {
        Ok(Request::Current) => {
            let foreground = current_or_exit();
            write_source_or_exit(foreground.input_locale);
            unsafe { ExitProcess(0) }
        }
        Ok(Request::English) => {
            let foreground = current_or_exit();
            write_source_or_exit(foreground.input_locale);
            if is_english(foreground.input_locale) {
                unsafe { ExitProcess(0) }
            }
            select_input_locale(foreground, english_input_locale_or_exit(), true)
        }
        Ok(Request::Restore(requested)) => {
            let foreground = current_or_exit();
            select_input_locale(foreground, requested, false)
        }
        Err(()) => exit_error(b"Expected no argument, --english, or one decimal HKL", None),
    }
}
