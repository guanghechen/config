mod annotations;
pub(crate) mod jobs;
use super::{Filetree, Request, Resource};
use crate::ux::treeview::lua::{
    LuaData, LuaFrame, LuaIds, LuaSource, LuaState, LuaTicket, input, output,
};
use crate::ux::treeview::{self, Error, Outcome, Result};
use mlua::prelude::*;
use std::path::PathBuf;

pub(crate) struct LuaFiletree(pub(crate) Filetree);
pub(crate) struct LuaResource(pub(crate) Resource);
struct LuaOpen(Request<Filetree>);
struct LuaResolve(Request<Resource>);
struct LuaDetails(Request<super::Details>);

impl LuaUserData for LuaDetails {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("poll", |lua, this, ()| match this.0.poll() {
            None => Ok((false, LuaValue::Nil)),
            Some(Err(error)) => Ok((true, output::outcome(lua, Outcome::Reply(error.into()))?)),
            Some(Ok(details)) => {
                let value = lua.create_table()?;
                value.set("size", details.size)?;
                value.set("permissions", details.permissions)?;
                value.set("mode", format!("{:04o}", details.mode & 0o7777))?;
                value.set("modified", details.modified)?;
                value.set("accessed", details.accessed)?;
                value.set("created", details.created)?;
                Ok((true, value.into_lua(lua)?))
            }
        });
    }
}

pub(crate) fn path(value: LuaString) -> LuaResult<PathBuf> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStringExt;
        Ok(std::ffi::OsString::from_vec(value.as_bytes().to_vec()).into())
    }
    #[cfg(windows)]
    {
        Ok(PathBuf::from(value.to_str()?.as_ref()))
    }
}

fn result(lua: &Lua, value: Result<LuaValue>) -> LuaResult<LuaValue> {
    match value {
        Ok(value) => Ok(value),
        Err(error) => output::outcome(lua, Outcome::Reply(error.into())),
    }
}

impl LuaUserData for LuaOpen {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("poll", |lua, this, ()| match this.0.poll() {
            None => Ok((false, LuaValue::Nil)),
            Some(value) => Ok((
                true,
                result(
                    lua,
                    value.and_then(|value| {
                        LuaFiletree(value)
                            .into_lua(lua)
                            .map_err(|error| Error::invalid(error.to_string()))
                    }),
                )?,
            )),
        });
    }
}
impl LuaUserData for LuaResolve {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("poll", |lua, this, ()| match this.0.poll() {
            None => Ok((false, LuaValue::Nil)),
            Some(value) => Ok((
                true,
                result(
                    lua,
                    value.and_then(|value| {
                        LuaResource(value)
                            .into_lua(lua)
                            .map_err(|error| Error::invalid(error.to_string()))
                    }),
                )?,
            )),
        });
    }
}
impl LuaUserData for LuaResource {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("node", |_, this, ()| Ok(output::node(this.0.node)));
        methods.add_method("source", |_, this, ()| Ok(LuaSource(this.0.source.clone())));
        methods.add_method("path", |lua, this, ()| {
            let path = this.0.path().map_err(LuaError::external)?;
            #[cfg(unix)]
            {
                use std::os::unix::ffi::OsStrExt;
                lua.create_string(path.as_os_str().as_bytes())
            }
            #[cfg(windows)]
            {
                lua.create_string(path.to_str().ok_or_else(|| {
                    LuaError::external("path cannot be represented as a Neovim filepath")
                })?)
            }
        });
        methods.add_method("info", |lua, this, ()| {
            let entry = this.0.entry().map_err(LuaError::external)?;
            let info = lua.create_table()?;
            info.set("node", output::node(this.0.node))?;
            info.set("label", super::display_name(&entry.name))?;
            info.set(
                "kind",
                match entry.kind {
                    super::Kind::File => "file",
                    super::Kind::Directory => "directory",
                    super::Kind::Link => "link",
                    super::Kind::Other => "other",
                },
            )?;
            info.set(
                "identity",
                format!("{:x}:{:x}", entry.identity.volume, entry.identity.file),
            )?;
            info.set("size", entry.size)?;
            info.set("mode", entry.mode)?;
            info.set("uid", entry.uid)?;
            info.set("gid", entry.gid)?;
            info.set("modified_ns", entry.modified.map(|value| value.to_string()))?;
            info.set("created_ns", entry.created.map(|value| value.to_string()))?;
            info.set("directory", entry.directory())?;
            info.set("cycle", entry.cycle)?;
            info.set("target_unknown", entry.target_unknown)?;
            info.set(
                "target_kind",
                entry.target.map(|(kind, _)| match kind {
                    super::Kind::File => "file",
                    super::Kind::Directory => "directory",
                    super::Kind::Link => "link",
                    super::Kind::Other => "other",
                }),
            )?;
            if let Some(link) = entry.link {
                #[cfg(unix)]
                {
                    use std::os::unix::ffi::OsStrExt;
                    info.set("link", lua.create_string(link.as_os_str().as_bytes())?)?;
                }
                #[cfg(windows)]
                {
                    info.set("link", link.to_str())?;
                }
            }
            Ok(info)
        });
    }
}
impl LuaUserData for LuaFiletree {
    fn add_methods<M: LuaUserDataMethods<Self>>(methods: &mut M) {
        jobs::methods(methods);
        annotations::methods(methods);
        methods.add_method("details", |_, this, resource: LuaAnyUserData| {
            Ok(LuaDetails(
                this.0.details(resource.borrow::<LuaResource>()?.0.clone()),
            ))
        });
        methods.add_method(
            "check_transfer_target",
            |_, this, (source, target): (LuaAnyUserData, LuaAnyUserData)| {
                Ok(LuaResolve(this.0.check_transfer_target(
                    source.borrow::<LuaResource>()?.0.clone(),
                    target.borrow::<LuaResource>()?.0.clone(),
                )))
            },
        );
        methods.add_method("watch_status", |lua, this, previous: Option<String>| {
            let status = this.0.watch_status();
            let revision = status.revision.to_string();
            if previous.as_ref() == Some(&revision) {
                return Ok(None);
            }
            let value = lua.create_table()?;
            value.set("revision", revision)?;
            value.set("directories", status.directories)?;
            value.set("covered", LuaIds(status.covered))?;
            value.set("limited", status.limited)?;
            if let Some(error) = status.error {
                value.set("error", output::error(lua, &error)?)?;
            }
            Ok(Some(value))
        });
        methods.add_method("watch_visible", |_, this, values: LuaTable| {
            if values.raw_len() > 64 {
                return Err(LuaError::external("too many watch viewports"));
            }
            let mut viewports = Vec::new();
            for value in values.sequence_values::<LuaTable>() {
                let value = value?;
                let frame: LuaAnyUserData = value.raw_get("frame")?;
                let frame = frame.borrow::<LuaFrame>()?.0.clone();
                let first: usize = value.raw_get("first")?;
                let last: usize = value.raw_get("last")?;
                if first > last
                    || last > frame.len()
                    || last - first > 4096
                    || frame.source().identity() != this.0.source().identity()
                {
                    return Err(LuaError::external("invalid Filetree viewport range"));
                }
                let memory = this.0.data().memory();
                let _guard = memory.enter();
                let nodes: std::sync::Arc<[treeview::NodeId]> = frame
                    .rows
                    .iter_from(first)
                    .take(last - first)
                    .flat_map(|row| row.folded_ids().iter().copied())
                    .collect();
                let charge = treeview::memory::Charge::new(nodes.len() * 8 + 128);
                memory.check().map_err(LuaError::external)?;
                viewports.push(super::watch::Viewport {
                    state: frame.state.id,
                    root: frame.root().clone(),
                    nodes,
                    _memory: charge,
                });
            }
            this.0.set_viewports(viewports).map_err(LuaError::external)
        });
        methods.add_method("is_busy", |_, this, ()| Ok(this.0.data().has_work()));
        methods.add_method("stats", |lua, this, ()| {
            let value = lua.create_table()?;
            value.set("retained_bytes", this.0.data().retained_bytes())?;
            value.set("nodes", this.0.source().len())?;
            value.set("queue_depth", this.0.data().queue_depth())?;
            Ok(value)
        });
        methods.add_method("treeview", |_, this, ()| {
            this.0
                .data()
                .acknowledge_publication(this.0.source().revision());
            Ok(LuaData(this.0.data().clone()))
        });
        methods.add_method("root", |_, this, ()| Ok(output::node(this.0.root())));
        methods.add_method("source", |_, this, ()| Ok(LuaSource(this.0.source())));
        methods.add_method(
            "create_state",
            |_, this, (root, display): (LuaValue, LuaValue)| {
                let parsed = (|| {
                    Ok((
                        if matches!(root, LuaValue::Nil) {
                            None
                        } else {
                            Some(input::root(root)?)
                        },
                        input::display(display)?,
                    ))
                })();
                let ticket = match parsed {
                    Ok((root, display)) => this.0.create_state(root, display),
                    Err(error) => treeview::Ticket::ready(error),
                };
                Ok(LuaTicket {
                    ticket,
                    _data: this.0.data().clone(),
                })
            },
        );
        methods.add_method("resolve", |_, this, value: LuaString| {
            Ok(LuaResolve(this.0.resolve(path(value)?)))
        });
        methods.add_method(
            "inspect",
            |_, this, (source, node): (LuaAnyUserData, LuaValue)| {
                let source = source.borrow::<LuaSource>()?;
                let node = input::node(node).map_err(LuaError::external)?;
                this.0
                    .inspect(source.0.clone(), node)
                    .map(LuaResource)
                    .map_err(LuaError::external)
            },
        );
        methods.add_method("refresh", |_, this, state: LuaAnyUserData| {
            let state = state.borrow::<LuaState>()?;
            Ok(LuaTicket {
                ticket: this
                    .0
                    .refresh(&state.0)
                    .unwrap_or_else(treeview::Ticket::ready),
                _data: this.0.data().clone(),
            })
        });
    }
}

pub(crate) fn module(lua: &Lua) -> LuaResult<LuaTable> {
    let module = lua.create_table()?;
    module.set(
        "open",
        lua.create_function(|_, value: LuaString| Ok(LuaOpen(Filetree::open(path(value)?))))?,
    )?;
    Ok(module)
}
