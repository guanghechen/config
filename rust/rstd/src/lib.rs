pub mod algorithm;
pub use algorithm::*;

pub mod find;
pub use find::*;

pub mod search;
pub use search::*;

pub mod string;
pub use string::*;

pub mod types;
pub use types::*;

pub mod r#fn;
pub use r#fn::*;

pub mod path;
pub use path::*;

pub mod fs;
pub use fs::*;

pub mod replace;
pub use replace::*;

use mlua::prelude::*;
use mlua::{FromLua, IntoLua, MultiValue as LuaMultiValue, Value as LuaValue};

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
        (
            "get_locations",
            lua.create_function(|_, (text, offsets): (String, Vec<usize>)| {
                Ok(string::get_locations(&text, &offsets))
            })?,
        ),
        (
            "parse_lines",
            lua.create_function(|lua, (text, widths): (String, Option<Vec<u32>>)| {
                let lines = string::parse_lines(&text, widths.as_deref());
                lines.into_lua(lua)
            })?,
        ),
    ])
}

fn path_module(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    let table = lua.create_table_from([
        (
            "is_absolute",
            lua.create_function(|_, filepath: String| Ok(path::is_absolute(&filepath)))?,
        ),
        (
            "is_dirpath",
            lua.create_function(|_, filepath: String| Ok(path::is_dirpath(&filepath)))?,
        ),
        (
            "is_exist",
            lua.create_function(|_, filepath: String| Ok(path::is_exist(&filepath)))?,
        ),
        (
            "is_exist_dirpath",
            lua.create_function(|_, filepath: String| Ok(path::is_exist_dirpath(&filepath)))?,
        ),
        (
            "is_exist_filepath",
            lua.create_function(|_, filepath: String| Ok(path::is_exist_filepath(&filepath)))?,
        ),
        (
            "is_descendant",
            lua.create_function(|_, (from, to): (String, String)| {
                Ok(path::is_descendant(&from, &to))
            })?,
        ),
        (
            "basename",
            lua.create_function(|_, filepath: String| Ok(path::basename(&filepath)))?,
        ),
        (
            "dirname",
            lua.create_function(|_, filepath: String| Ok(path::dirname(&filepath)))?,
        ),
        (
            "extname",
            lua.create_function(|_, filepath: String| Ok(path::extname(&filepath)))?,
        ),
    ])?;
    table.set("SEP", path::SEP)?;
    Ok(table)
}

fn fs_module(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    lua.create_table_from([
        (
            "collect_files",
            lua.create_function(
                |lua, (dirpath, recursive): (String, bool)| -> LuaResult<LuaMultiValue> {
                    match fs::collect_files(&dirpath, recursive) {
                        Ok(result) => {
                            let data = result.into_lua(lua)?;
                            Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                        }
                        Err(error) => {
                            let err = error.into_lua(lua)?;
                            Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                        }
                    }
                },
            )?,
        ),
        (
            "get_filesize",
            lua.create_function(|lua, filepath: String| -> LuaResult<LuaMultiValue> {
                match fs::get_filesize(&filepath) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "readdir",
            lua.create_function(|lua, dirpath: String| -> LuaResult<LuaMultiValue> {
                match fs::readdir(&dirpath) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "move",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params = crate::types::IFsMoveParams::from_lua(params, lua)?;
                match fs::r#move(&params) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
    ])
}

fn replace_module(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    lua.create_table_from([
        (
            "replace_file",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params = crate::types::replace::IReplaceFileParams::from_lua(params, lua)?;
                match crate::replace::replace_file(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_by_matches",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceFileByMatchesParams::from_lua(params, lua)?;
                match crate::replace::replace_file_by_matches(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_by_matches_advance",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params = crate::types::replace::IReplaceFileByMatchesAdvanceParams::from_lua(
                    params, lua,
                )?;
                match crate::replace::replace_file_by_matches_advance(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                    &params.remain_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_preview",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceFilePreviewParams::from_lua(params, lua)?;
                match crate::replace::replace_file_preview(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_preview_advance",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceFilePreviewParams::from_lua(params, lua)?;
                match crate::replace::replace_file_preview_advance(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_file_preview_by_matches_advance",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceFilePreviewByMatchesAdvanceParams::from_lua(
                        params, lua,
                    )?;
                match crate::replace::replace_file_preview_by_matches_advance(
                    &params.filepath,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_text_preview",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceTextPreviewParams::from_lua(params, lua)?;
                match crate::replace::replace_text_preview(
                    &params.text,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_text_preview_by_matches",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params = crate::types::replace::IReplaceTextPreviewByMatchesParams::from_lua(
                    params, lua,
                )?;
                match crate::replace::replace_text_preview_by_matches(
                    &params.text,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_text_preview_advance",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceTextPreviewAdvanceParams::from_lua(params, lua)?;
                match crate::replace::replace_text_preview_advance(
                    &params.text,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
        (
            "replace_text_preview_by_matches_advance",
            lua.create_function(|lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
                let params =
                    crate::types::replace::IReplaceTextPreviewByMatchesAdvanceParams::from_lua(
                        params, lua,
                    )?;
                match crate::replace::replace_text_preview_by_matches_advance(
                    &params.text,
                    &params.search_pattern,
                    &params.replace_pattern,
                    params.keep_search_pieces,
                    params.flag_regex,
                    params.flag_case_sensitive,
                    &params.match_offsets,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => Ok(LuaMultiValue::from_vec(vec![
                        LuaValue::Nil,
                        LuaValue::String(lua.create_string(error)?),
                    ])),
                }
            })?,
        ),
    ])
}

fn find_module(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    lua.create_table_from([(
        "find_files",
        lua.create_function(|lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
            let options = IFindFilesOptions::from_lua(options, lua)?;
            match find::find_files(&options) {
                Ok(result) => {
                    let data = result.into_lua(lua)?;
                    Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                }
                Err(error) => {
                    let err = error.into_lua(lua)?;
                    Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                }
            }
        })?,
    )])
}

fn search_module(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    lua.create_table_from([
        (
            "search_in_files",
            lua.create_function(|lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = ISearchInFilesOptions::from_lua(options, lua)?;
                match search::search_in_files(&options) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "search_in_lines",
            lua.create_function(|lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInLinesOptions::from_lua(options, lua)?;
                match search::search_in_lines(
                    &options.pattern,
                    &options.lines,
                    options.flag_fuzzy,
                    options.flag_regex,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "search_in_text",
            lua.create_function(|lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInTextOptions::from_lua(options, lua)?;
                match search::search_in_text(
                    &options.pattern,
                    &options.text,
                    options.flag_fuzzy,
                    options.flag_regex,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "search_in_lines_literal",
            lua.create_function(|lua, options: LuaValue| -> LuaResult<LuaValue> {
                let options = search::ISearchInLinesLiteralOptions::from_lua(options, lua)?;
                let result = search::search_in_lines_literal(
                    &options.pattern,
                    &options.lines,
                    options.flag_fuzzy,
                    options.flag_case_sensitive,
                );
                result.into_lua(lua)
            })?,
        ),
        (
            "search_in_lines_regex",
            lua.create_function(|lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInLinesRegexOptions::from_lua(options, lua)?;
                match search::search_in_lines_regex(
                    &options.pattern,
                    &options.lines,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = error.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
    ])
}

#[mlua::lua_module]
fn rstd(lua: &Lua) -> LuaResult<LuaTable<'_>> {
    let exports = lua.create_table()?;
    exports.set("string", string_module(lua)?)?;
    exports.set("fn", fn_module(lua)?)?;
    exports.set("path", path_module(lua)?)?;
    exports.set("fs", fs_module(lua)?)?;
    exports.set("replace", replace_module(lua)?)?;
    exports.set("find", find_module(lua)?)?;
    exports.set("search", search_module(lua)?)?;
    Ok(exports)
}
