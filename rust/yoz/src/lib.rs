pub mod algorithm;
pub mod dict;
pub mod find;
pub mod r#fn;
pub mod fs;
pub mod path;
pub mod replace;
pub mod search;
pub mod string;
pub mod types;
pub mod uri;

use mlua::FromLua;
use mlua::FromLuaMulti;
use mlua::Function;
use mlua::IntoLua;
use mlua::IntoLuaMulti;
use mlua::MultiValue as LuaMultiValue;
use mlua::Value as LuaValue;
use mlua::prelude::*;

use crate::dict::search::SearchResultKind;

#[inline]
fn f<A, R, F>(lua: &Lua, func: F) -> LuaResult<Function>
where
    A: FromLuaMulti,
    R: IntoLuaMulti,
    F: Fn(&Lua, A) -> LuaResult<R> + Send + 'static,
{
    lua.create_function(func)
}

fn fn_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        ("uuid", f(lua, |_, ()| Ok(r#fn::uuid()))?),
        ("md5", f(lua, |_, input: String| Ok(r#fn::md5(&input)))?),
    ])
}

fn dict_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([(
        "search",
        f(lua, |lua, params: LuaValue| {
            let options = crate::types::IDictSearchOptions::from_lua(params, lua)?;
            let results = crate::dict::search::search(&options);
            let table = lua.create_table_with_capacity(results.len(), 0)?;
            for (idx, result) in results.into_iter().enumerate() {
                let entry = lua.create_table()?;
                let kind = match result.kind {
                    SearchResultKind::Scalar => "scalar",
                    SearchResultKind::Segment => "segment",
                };
                entry.set("type", kind)?;
                entry.set("indexes", result.indexes)?;
                table.set(idx + 1, entry)?;
            }
            Ok(LuaValue::Table(table))
        })?,
    )])
}

fn string_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "calc_linewidths",
            f(lua, |_, text: String| Ok(string::calc_linewidths(&text)))?,
        ),
        (
            "count_lines",
            f(lua, |_, text: String| Ok(string::count_lines(&text)))?,
        ),
        (
            "parse_comma_list",
            f(lua, |_, text: String| Ok(string::parse_comma_list(&text)))?,
        ),
        (
            "get_locations",
            f(lua, |_, (text, offsets): (String, Vec<usize>)| {
                Ok(string::get_locations(&text, &offsets))
            })?,
        ),
        (
            "parse_lines",
            f(lua, |lua, (text, widths): (String, Option<Vec<u32>>)| {
                let lines = string::parse_lines(&text, widths.as_deref());
                lines.into_lua(lua)
            })?,
        ),
    ])
}

fn path_module(lua: &Lua) -> LuaResult<LuaTable> {
    let table = lua.create_table_from([
        (
            "basename",
            f(lua, |_, filepath: String| Ok(path::basename(&filepath)))?,
        ),
        (
            "dirname",
            f(
                lua,
                |_, (filepath, keep_tailing_slash, sep): (String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::dirname(&filepath, keep_tailing_slash, sep))
                },
            )?,
        ),
        (
            "extname",
            f(lua, |_, filepath: String| Ok(path::extname(&filepath)))?,
        ),
        (
            "is_absolute",
            f(lua, |_, filepath: String| Ok(path::is_absolute(&filepath)))?,
        ),
        (
            "is_descendant",
            f(lua, |_, (from, to): (String, String)| {
                Ok(path::is_descendant(&from, &to))
            })?,
        ),
        (
            "is_dirpath",
            f(lua, |_, filepath: String| Ok(path::is_dirpath(&filepath)))?,
        ),
        (
            "join",
            f(
                lua,
                |_, (from, to, keep_trailing_slash, sep): (String, String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::join(&from, &to, keep_trailing_slash, sep))
                },
            )?,
        ),
        (
            "relative",
            f(
                lua,
                |_, (from, to, keep_trailing_slash, sep): (String, String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::relative(&from, &to, keep_trailing_slash, sep))
                },
            )?,
        ),
        (
            "resolve",
            f(
                lua,
                |_, (from, to, keep_trailing_slash, sep): (String, String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::resolve(&from, &to, keep_trailing_slash, sep))
                },
            )?,
        ),
        (
            "get_cwd",
            f(lua, |_, ()| {
                let cwd = path::get_cwd();
                Ok(cwd.as_ref().to_owned())
            })?,
        ),
        (
            "set_cwd",
            f(lua, |_, cwd: String| {
                path::set_cwd(&cwd);
                Ok(())
            })?,
        ),
        (
            "normalize",
            f(
                lua,
                |_, (filepath, keep_trailing_slash, sep): (String, bool, String)| {
                    let sep = sep.chars().next().unwrap_or(path::SEP);
                    Ok(path::normalize(&filepath, keep_trailing_slash, sep))
                },
            )?,
        ),
        (
            "split",
            f(
                lua,
                |lua, (filepath, keep_trailing_slash): (String, bool)| {
                    let segments = path::split(&filepath, keep_trailing_slash);
                    segments.into_lua(lua)
                },
            )?,
        ),
        (
            "is_exist",
            f(lua, |_, input: String| Ok(path::is_exist(&input)))?,
        ),
        (
            "is_exist_directory",
            f(lua, |_, input: String| Ok(path::is_exist_directory(&input)))?,
        ),
        (
            "is_exist_file",
            f(lua, |_, input: String| Ok(path::is_exist_file(&input)))?,
        ),
        (
            "mkdirs",
            f(lua, |_, dirpath: String| {
                path::mkdirs(&dirpath).map_err(LuaError::RuntimeError)?;
                Ok(())
            })?,
        ),
        (
            "locate_nearest",
            f(
                lua,
                |_, (start_dirpath, filenames): (String, Vec<String>)| {
                    Ok(path::locate_nearest(&start_dirpath, &filenames))
                },
            )?,
        ),
    ])?;
    table.set("SEP", path::SEP.to_string())?;
    Ok(table)
}

fn fs_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "collect_files",
            f(
                lua,
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
            f(lua, |lua, filepath: String| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, dirpath: String| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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

fn replace_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "replace_file",
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, params: LuaValue| -> LuaResult<LuaMultiValue> {
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

fn find_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([(
        "find_files",
        f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
            let options = find::IFindFilesOptions::from_lua(options, lua)?;
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

fn search_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "search_in_files",
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInFilesOptions::from_lua(options, lua)?;
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
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
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
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInLinesLiteralOptions::from_lua(options, lua)?;
                match search::search_in_lines(
                    &options.pattern,
                    &options.lines,
                    options.flag_fuzzy,
                    false,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = LuaValue::String(lua.create_string(&error)?);
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
        (
            "search_in_lines_regex",
            f(lua, |lua, options: LuaValue| -> LuaResult<LuaMultiValue> {
                let options = search::ISearchInLinesRegexOptions::from_lua(options, lua)?;
                match search::search_in_lines(
                    &options.pattern,
                    &options.lines,
                    false,
                    true,
                    options.flag_case_sensitive,
                ) {
                    Ok(result) => {
                        let data = result.into_lua(lua)?;
                        Ok(LuaMultiValue::from_vec(vec![data, LuaValue::Nil]))
                    }
                    Err(error) => {
                        let err = LuaValue::String(lua.create_string(&error)?);
                        Ok(LuaMultiValue::from_vec(vec![LuaValue::Nil, err]))
                    }
                }
            })?,
        ),
    ])
}

fn uri_module(lua: &Lua) -> LuaResult<LuaTable> {
    lua.create_table_from([
        (
            "basename",
            f(lua, |_, uri: String| Ok(uri::basename(&uri)))?,
        ),
        (
            "build",
            f(
                lua,
                |_, (protocol, path, hash): (String, String, Option<String>)| {
                    Ok(uri::build(&protocol, &path, hash.as_deref()))
                },
            )?,
        ),
        (
            "decode",
            f(lua, |_, src: String| Ok(uri::decode(&src)))?,
        ),
        (
            "encode",
            f(lua, |_, src: String| Ok(uri::encode(&src)))?,
        ),
        (
            "extname",
            f(lua, |_, uri: String| Ok(uri::extname(&uri)))?,
        ),
        ("hash", f(lua, |_, uri: String| Ok(uri::hash(&uri)))?),
        (
            "is_data_uri",
            f(lua, |_, src: String| Ok(uri::is_data_uri(&src)))?,
        ),
        (
            "join",
            f(lua, |_, (from_uri, to_path): (String, String)| {
                Ok(uri::join(&from_uri, &to_path))
            })?,
        ),
        (
            "normalize",
            f(lua, |_, uri: String| Ok(uri::normalize(&uri)))?,
        ),
        (
            "parent",
            f(lua, |_, uri: String| Ok(uri::parent(&uri)))?,
        ),
        (
            "parse",
            f(lua, |lua, uri: String| {
                match uri::parse(&uri) {
                    Some(parts) => {
                        let table = lua.create_table()?;
                        table.set("protocol", parts.protocol)?;
                        table.set("path", parts.path)?;
                        if let Some(hash) = parts.hash {
                            table.set("hash", hash)?;
                        }
                        Ok(LuaValue::Table(table))
                    }
                    None => Ok(LuaValue::Nil),
                }
            })?,
        ),
        (
            "pathname",
            f(lua, |_, uri: String| Ok(uri::pathname(&uri)))?,
        ),
        (
            "protocol",
            f(lua, |_, uri: String| Ok(uri::protocol(&uri)))?,
        ),
        (
            "relative",
            f(lua, |_, (from_uri, to_uri): (String, String)| {
                Ok(uri::relative(&from_uri, &to_uri))
            })?,
        ),
        (
            "split",
            f(lua, |lua, path: String| {
                let segments = uri::split(&path);
                segments.into_lua(lua)
            })?,
        ),
        (
            "validate",
            f(lua, |_, uri: String| Ok(uri::validate(&uri)))?,
        ),
    ])
}

#[mlua::lua_module]
fn yoz(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;
    exports.set("dict", dict_module(lua)?)?;
    exports.set("string", string_module(lua)?)?;
    exports.set("fn", fn_module(lua)?)?;
    exports.set("path", path_module(lua)?)?;
    exports.set("fs", fs_module(lua)?)?;
    exports.set("replace", replace_module(lua)?)?;
    exports.set("find", find_module(lua)?)?;
    exports.set("search", search_module(lua)?)?;
    exports.set("uri", uri_module(lua)?)?;
    Ok(exports)
}
