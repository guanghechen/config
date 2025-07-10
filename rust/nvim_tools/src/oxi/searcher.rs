use crate::types::r#match::LineMatch;
use crate::types::CmdResult;
use crate::util;
use nvim_oxi::conversion::{Error as ConversionError, FromObject, ToObject};
use nvim_oxi::serde::{Deserializer, Serializer};
use nvim_oxi::{lua, Object};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct SearchInFilesParams {
    pub cwd: Option<String>,
    pub max_matches: Option<i32>,
    pub flag_case_sensitive: bool,
    pub flag_gitignore: bool,
    pub flag_regex: bool,
    pub max_filesize: Option<String>,
    pub search_pattern: String,
    pub search_paths: String,
    pub include_patterns: String,
    pub exclude_patterns: String,
    pub specified_filepath: Option<String>,
}

impl FromObject for SearchInFilesParams {
    fn from_object(obj: Object) -> Result<Self, ConversionError> {
        Self::deserialize(Deserializer::new(obj)).map_err(Into::into)
    }
}

impl ToObject for SearchInFilesParams {
    fn to_object(self) -> Result<Object, ConversionError> {
        self.serialize(Serializer::new()).map_err(Into::into)
    }
}

impl lua::Poppable for SearchInFilesParams {
    unsafe fn pop(lstate: *mut lua::ffi::lua_State) -> Result<Self, lua::Error> {
        unsafe {
            let obj = Object::pop(lstate)?;
            Self::from_object(obj).map_err(lua::Error::pop_error_from_err::<Self, _>)
        }
    }
}

impl lua::Pushable for SearchInFilesParams {
    unsafe fn push(self, lstate: *mut lua::ffi::lua_State) -> Result<std::ffi::c_int, lua::Error> {
        unsafe {
            self.to_object()
                .map_err(lua::Error::push_error_from_err::<Self, _>)?
                .push(lstate)
        }
    }
}

pub fn search_in_lines(
    (pattern, lines, flag_fuzzy, flag_regex): (String, Vec<String>, bool, bool),
) -> Result<Vec<LineMatch>, String> {
    util::searcher::search_in_lines(&pattern, &lines, flag_fuzzy, flag_regex)
}

pub fn search_in_text(
    (pattern, text, flag_fuzzy, flag_regex): (String, String, bool, bool),
) -> Result<Vec<LineMatch>, String> {
    util::searcher::search_in_text(&pattern, &text, flag_fuzzy, flag_regex)
}

pub fn search_in_files(params: SearchInFilesParams) -> CmdResult<util::searcher::ISearchInFilesSucceedResult> {
    let options = util::searcher::ISearchInFilesParams {
        cwd: params.cwd,
        max_matches: params.max_matches,
        flag_case_sensitive: params.flag_case_sensitive,
        flag_gitignore: params.flag_gitignore,
        flag_regex: params.flag_regex,
        max_filesize: params.max_filesize,
        search_pattern: params.search_pattern,
        search_paths: params.search_paths,
        include_patterns: params.include_patterns,
        exclude_patterns: params.exclude_patterns,
        specified_filepath: params.specified_filepath,
    };

    let cmd_result: CmdResult<util::searcher::ISearchInFilesSucceedResult> = {
        let result = util::searcher::search_in_files(&options);
        match result {
            Ok(data) => CmdResult {
                cmd: data.cmd.to_owned(),
                error: None,
                data: Some(data),
            },
            Err(data) => CmdResult {
                cmd: data.cmd.to_owned(),
                error: Some(data.error),
                data: None,
            },
        }
    };
    cmd_result
}
