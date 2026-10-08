//! Coalesced pipe notifications; only the Neovim thread drains native state.

use super::*;
use crate::ux::treeview::runtime::Listener;
use std::sync::Mutex;

struct Descriptor(libc::c_int);

impl Drop for Descriptor {
    fn drop(&mut self) {
        unsafe {
            libc::close(self.0);
        }
    }
}

struct State {
    descriptor: Option<Descriptor>,
    pending: bool,
    error: Option<String>,
}

struct Pipe(Mutex<State>);

impl Listener for Pipe {
    fn wake(&self) {
        let mut state = self.0.lock().unwrap_or_else(|error| error.into_inner());
        if state.pending {
            return;
        }
        let Some(descriptor) = &state.descriptor else {
            return;
        };
        let byte = 1u8;
        loop {
            let written = unsafe { libc::write(descriptor.0, (&raw const byte).cast(), 1) };
            if written == 1 {
                state.pending = true;
                return;
            }
            let error = std::io::Error::last_os_error();
            if error.kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            state.error = Some(format!("Treeview notification write failed: {error}"));
            state.descriptor = None;
            return;
        }
    }

    fn close(&self) {
        self.0
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .descriptor = None;
    }

    fn is_closed(&self) -> bool {
        self.0
            .lock()
            .unwrap_or_else(|error| error.into_inner())
            .descriptor
            .is_none()
    }
}

pub(super) struct Notifications(Option<Arc<Pipe>>);

impl Notifications {
    pub(super) fn new(data: &DataHandle, descriptor: libc::c_int) -> LuaResult<Self> {
        #[cfg(unix)]
        let duplicate = unsafe { libc::fcntl(descriptor, libc::F_DUPFD_CLOEXEC, 0) };
        #[cfg(windows)]
        let duplicate = unsafe { libc::dup(descriptor) };
        if duplicate < 0 {
            return Err(LuaError::external(std::io::Error::last_os_error()));
        }
        let descriptor = Descriptor(duplicate);
        #[cfg(windows)]
        {
            #[link(name = "kernel32")]
            unsafe extern "system" {
                fn SetHandleInformation(handle: isize, mask: u32, flags: u32) -> i32;
            }
            if unsafe { SetHandleInformation(libc::get_osfhandle(duplicate), 1, 0) } == 0 {
                return Err(LuaError::external(std::io::Error::last_os_error()));
            }
        }
        let pipe = Arc::new(Pipe(Mutex::new(State {
            descriptor: Some(descriptor),
            pending: false,
            error: None,
        })));
        let listener: Arc<dyn Listener> = pipe.clone();
        data.listen(&listener).map_err(LuaError::external)?;
        Ok(Self(Some(pipe)))
    }
}

impl Drop for Notifications {
    fn drop(&mut self) {
        if let Some(pipe) = self.0.take() {
            pipe.close();
        }
    }
}

impl LuaUserData for Notifications {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("acknowledge", |_, this, ()| {
            let Some(pipe) = &this.0 else {
                return Ok(());
            };
            let mut state = pipe.0.lock().unwrap_or_else(|error| error.into_inner());
            state.pending = false;
            if let Some(error) = &state.error {
                return Err(LuaError::external(error.clone()));
            }
            Ok(())
        });
        methods.add_method_mut("close", |_, this, ()| {
            /* Synchronize with a writer before Lua closes the read endpoint. */
            if let Some(pipe) = this.0.take() {
                pipe.close();
            }
            Ok(())
        });
    }
}
