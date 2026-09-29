//! Native interaction components and their Lua boundaries.

pub mod filetree;
pub mod treeview;

pub(crate) fn module(lua: &mlua::Lua) -> mlua::Result<mlua::Table> {
    let module = lua.create_table()?;
    module.set("treeview", treeview::lua::module(lua)?)?;
    module.set("filetree", filetree::lua::module(lua)?)?;
    Ok(module)
}
