use super::{Explorer, Mark};
use crate::ux::filetree::Request;
use crate::ux::filetree::lua::LuaFiletree;
use crate::ux::filetree::lua::jobs::{LuaJob, create_plan, operation_plan};
use crate::ux::treeview::lua::{LuaFrame, LuaState, LuaTicket, input, output};
use mlua::prelude::*;
use std::path::PathBuf;

struct LuaExplorer(Explorer);
struct LuaPath(Request<PathBuf>);

impl LuaUserData for LuaPath {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("poll", |lua, this, ()| match this.0.poll() {
            None => Ok((false, LuaValue::Nil)),
            Some(Err(error)) => Ok((
                true,
                output::outcome(lua, crate::ux::treeview::Outcome::Reply(error.into()))?,
            )),
            Some(Ok(path)) => {
                #[cfg(unix)]
                {
                    use std::os::unix::ffi::OsStrExt;
                    Ok((
                        true,
                        lua.create_string(path.as_os_str().as_bytes())?
                            .into_lua(lua)?,
                    ))
                }
                #[cfg(windows)]
                Ok((
                    true,
                    path.to_str()
                        .ok_or_else(|| {
                            LuaError::external("reveal path cannot be represented in Neovim")
                        })?
                        .into_lua(lua)?,
                ))
            }
        });
    }
}

impl LuaUserData for LuaExplorer {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("workspace", |_, this, ()| {
            Ok(output::node(this.0.workspace))
        });
        methods.add_method("workspace_path", |lua, this, ()| {
            let path = this.0.workspace_path().map_err(LuaError::external)?;
            #[cfg(unix)]
            {
                use std::os::unix::ffi::OsStrExt;
                lua.create_string(path.as_os_str().as_bytes())
            }
            #[cfg(windows)]
            lua.create_string(path.to_str().ok_or_else(|| {
                LuaError::external("workspace path cannot be represented in Neovim")
            })?)
        });
        methods.add_method("previous", |_, this, ()| {
            Ok(this.0.previous().map(output::node))
        });
        methods.add_method("job", |_, this, ()| Ok(this.0.job().map(LuaJob)));
        methods.add_method("reveal_path", |_, this, path: LuaString| {
            Ok(LuaPath(
                this.0.reveal_path(crate::ux::filetree::lua::path(path)?),
            ))
        });
        methods.add_method("start_operation", |_, this, value: LuaTable| {
            this.0
                .start_operation(operation_plan(value)?)
                .map(LuaJob)
                .map_err(LuaError::external)
        });
        methods.add_method("start_create", |_, this, value: LuaTable| {
            this.0
                .start_create(create_plan(value)?)
                .map(LuaJob)
                .map_err(LuaError::external)
        });
        methods.add_method("mode", |_, this, frame: LuaAnyUserData| {
            let frame = frame.borrow::<LuaFrame>()?;
            if frame.0.state_id() != this.0.state.id() {
                return Err(LuaError::external(
                    "Explorer frame belongs to another state",
                ));
            }
            Ok(super::mode(&frame.0).map(str::to_owned))
        });
        methods.add_method("mark", |_, this, (frame, first, last, mark, visual): (LuaAnyUserData, usize, usize, String, bool)| {
            let start = first.checked_sub(1).ok_or_else(|| LuaError::external("mark uses 1-based ranges"))?;
            let mark = match mark.as_str() {
                "toggle" => Mark::Toggle,
                "select" => Mark::Select,
                "copy" => Mark::Copy,
                "cut" => Mark::Cut,
                _ => return Err(LuaError::external("unknown Explorer mark")),
            };
            Ok(LuaTicket {
                ticket: this.0.mark(frame.borrow::<LuaFrame>()?.0.clone(), start, last, mark, visual),
                _data: this.0.state.data().clone(),
            })
        });
        methods.add_method(
            "inspect_range",
            |_, this, (frame, first, last): (LuaAnyUserData, usize, usize)| {
                let start = first
                    .checked_sub(1)
                    .ok_or_else(|| LuaError::external("range uses 1-based rows"))?;
                Ok(LuaTicket {
                    ticket: this.0.inspect_range(
                        frame.borrow::<LuaFrame>()?.0.clone(),
                        start,
                        last,
                    ),
                    _data: this.0.state.data().clone(),
                })
            },
        );
        methods.add_method("navigate", |_, this, (node, reveal): (LuaValue, bool)| {
            let node = input::node(node).map_err(LuaError::external)?;
            Ok(LuaTicket {
                ticket: this.0.navigate(node, reveal),
                _data: this.0.state.data().clone(),
            })
        });
    }
}

pub(crate) fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let module = lua.create_table()?;
    module.set(
        "new",
        lua.create_function(|_, (tree, state): (LuaAnyUserData, LuaAnyUserData)| {
            Explorer::new(
                tree.borrow::<LuaFiletree>()?.0.clone(),
                state.borrow::<LuaState>()?.0.clone(),
            )
            .map(LuaExplorer)
            .map_err(LuaError::external)
        })?,
    )?;
    Ok(module)
}
