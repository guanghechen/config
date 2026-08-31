#![no_main]
#![no_std]

use core::convert::TryFrom;
use core::ffi::c_void;
use core::ptr;

type Bool = i32;
type Dword = u32;
type Handle = *mut c_void;
type Hkl = *mut c_void;
type Hwnd = *mut c_void;
type Lparam = isize;
type Lresult = isize;
type Uint = u32;
type Wparam = usize;

const INVALID_HANDLE_VALUE: Handle = usize::MAX as Handle;
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

fn requested_input_locale() -> Result<Option<u16>, ()> {
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
        return Ok(None);
    }

    let mut value = 0_u32;
    let mut digits = 0_usize;
    while is_digit(unsafe { *cursor }) {
        value = value
            .checked_mul(10)
            .and_then(|current| current.checked_add(u32::from(unsafe { *cursor } - b'0' as u16)))
            .ok_or(())?;
        if value > u32::from(u16::MAX) {
            return Err(());
        }
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
    Ok(Some(value as u16))
}

fn current_input_locale() -> Result<u16, CurrentError> {
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
    Ok((layout as usize & usize::from(u16::MAX)) as u16)
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

fn write_decimal(handle: Handle, value: u32) -> bool {
    let mut buffer = [0_u8; 11];
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
            let _ = write_decimal(stderr, code);
        } else {
            let _ = write_bytes(stderr, b"\n");
        }
    }
    unsafe { ExitProcess(1) }
}

fn current_or_exit() -> u16 {
    match current_input_locale() {
        Ok(input_locale) => input_locale,
        Err(CurrentError::NoForegroundWindow) => exit_error(b"No foreground window", None),
        Err(CurrentError::NoInputLocale) => {
            exit_error(b"Foreground thread has no input locale", None)
        }
        Err(CurrentError::Windows(code)) => {
            exit_error(b"Failed to inspect foreground window", Some(code))
        }
    }
}

fn select_input_locale(requested: u16) -> ! {
    let hwnd = unsafe { GetForegroundWindow() };
    if hwnd.is_null() {
        exit_error(b"No foreground window", None);
    }
    let thread_id = unsafe { GetWindowThreadProcessId(hwnd, ptr::null_mut()) };
    if thread_id == 0 {
        exit_error(
            b"Failed to inspect foreground window",
            Some(unsafe { GetLastError() }),
        );
    }
    let current = unsafe { GetKeyboardLayout(thread_id) };
    if current.is_null() {
        exit_error(b"Foreground thread has no input locale", None);
    }
    if (current as usize & usize::from(u16::MAX)) as u16 == requested {
        unsafe { ExitProcess(0) }
    }

    let mut message_result = 0;
    unsafe { SetLastError(0) };
    let sent = unsafe {
        SendMessageTimeoutW(
            hwnd,
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
        let selected = unsafe { GetKeyboardLayout(thread_id) };
        if !selected.is_null() && (selected as usize & usize::from(u16::MAX)) as u16 == requested {
            unsafe { ExitProcess(0) }
        }
        if attempt + 1 < SELECT_READBACK_ATTEMPTS {
            unsafe { Sleep(SELECT_READBACK_INTERVAL_MS) };
        }
    }
    exit_error(b"Foreground input locale did not change", None)
}

#[unsafe(no_mangle)]
pub extern "C" fn mainCRTStartup() -> ! {
    match requested_input_locale() {
        Ok(None) => {
            let current = current_or_exit();
            let Some(stdout) = std_handle(STD_OUTPUT_HANDLE) else {
                unsafe { ExitProcess(1) }
            };
            if !write_decimal(stdout, u32::from(current)) {
                unsafe { ExitProcess(1) }
            }
            unsafe { ExitProcess(0) }
        }
        Ok(Some(requested)) => select_input_locale(requested),
        Err(()) => exit_error(b"Expected one decimal input locale in range 1..65535", None),
    }
}
