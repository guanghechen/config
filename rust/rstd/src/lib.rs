pub mod string;
pub use string::*;

pub mod r#fn;
pub use r#fn::*;

use mlua::prelude::*;

fn fn_module(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    lua.create_table_from([
        ("uuid", lua.create_function(|_, ()| Ok(r#fn::uuid()))?),
        (
            "md5",
            lua.create_function(|_, input: String| Ok(r#fn::md5(&input)))?,
        ),
    ])
}

fn string_module(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    lua.create_table_from([
        (
            "calc_linewidths",
            lua.create_function(|_, text: String| Ok(string::calc_linewidths(&text)))?,
        ),
        (
            "count_lines",
            lua.create_function(|_, text: String| Ok(string::count_lines(&text)))?,
        ),
        (
            "parse_comma_list",
            lua.create_function(|_, text: String| Ok(string::parse_comma_list(&text)))?,
        ),
    ])
}

#[mlua::lua_module]
fn rstd(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    let exports = lua.create_table()?;
    exports.set("string", string_module(lua)?)?;
    exports.set("fn", fn_module(lua)?)?;
    Ok(exports)
}
