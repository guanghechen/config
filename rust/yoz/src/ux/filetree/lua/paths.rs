//! Slash-separated Lua paths meet native filesystem paths only at this boundary.

use mlua::prelude::*;
use std::path::{Path, PathBuf};

#[cfg(any(windows, test))]
fn windows_slashes(path: &str) -> String {
    path.replace('\\', "/")
}

pub(crate) fn input(value: LuaString) -> LuaResult<PathBuf> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStringExt;
        Ok(std::ffi::OsString::from_vec(value.as_bytes().to_vec()).into())
    }
    #[cfg(windows)]
    {
        let value = value.to_str()?;
        if value.contains('\\') {
            return Err(LuaError::external("Filetree paths must use '/' separators"));
        }
        Ok(PathBuf::from(
            crate::canonical_path::to_os_path(&value).as_ref(),
        ))
    }
}

pub(crate) fn output(lua: &Lua, path: &Path) -> LuaResult<Option<LuaString>> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        lua.create_string(path.as_os_str().as_bytes()).map(Some)
    }
    #[cfg(windows)]
    {
        path.to_str()
            .map(|path| lua.create_string(windows_slashes(path)))
            .transpose()
    }
}

pub(crate) fn required(lua: &Lua, path: &Path) -> LuaResult<LuaString> {
    output(lua, path)?
        .ok_or_else(|| LuaError::external("path cannot be represented as a Neovim filepath"))
}

pub(crate) fn label(path: &Path) -> String {
    #[cfg(unix)]
    {
        super::super::display_name(path.as_os_str())
    }
    #[cfg(windows)]
    {
        use std::os::windows::ffi::{OsStrExt, OsStringExt};
        let units: Vec<_> = path
            .as_os_str()
            .encode_wide()
            .map(|unit| {
                if unit == u16::from(b'\\') {
                    u16::from(b'/')
                } else {
                    unit
                }
            })
            .collect();
        super::super::display_name(&std::ffi::OsString::from_wide(&units))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t_windows_paths_preserve_prefixes_and_round_trip() {
        for (native, logical) in [
            (r"C:\work\a.txt", "C:/work/a.txt"),
            (r"\\server\share\a.txt", "//server/share/a.txt"),
            (r"\\?\C:\work\a. ", "//?/C:/work/a. "),
            (r"\\?\UNC\server\share\a.txt", "//?/UNC/server/share/a.txt"),
            (r"..\link\..\a", "../link/../a"),
        ] {
            assert_eq!(windows_slashes(native), logical);
            assert_eq!(logical.replace('/', "\\"), native);
        }
    }

    #[cfg(unix)]
    #[test]
    fn t_unix_display_retains_literal_backslashes_and_bytes() {
        use std::os::unix::ffi::OsStrExt;
        let path = Path::new(std::ffi::OsStr::from_bytes(b"/work\\space/\xff"));
        assert_eq!(label(path), "/work\\\\space/\\xff");
    }
}
