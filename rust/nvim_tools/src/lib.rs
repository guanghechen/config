pub mod algorithm;
pub mod oxi;
pub mod types;
pub mod util;

use crate::types::dto::LineMatch;
use crate::types::dto::MoveParams;
use crate::types::dto::ReadAllFilesSucceedResult;
use crate::types::dto::ReaddirSucceedResult;
use crate::types::dto::SearchInBufferParams;
use crate::types::dto::SearchInBufferResult;
use crate::types::dto::SearchInLinesParams;
use crate::types::dto::SearchInTextParams;
use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;

#[nvim_oxi::plugin]
fn nvim_tools() -> Dictionary {
    Dictionary::from_iter([
        (
            "calc_linewidths",
            Object::from(Function::from_fn(oxi::string::calc_linewidths)),
        ),
        (
            "count_lines",
            Object::from(Function::from_fn(oxi::string::count_lines)),
        ),
        ////
        (
            "collect_files",
            Object::from(Function::<
                (String, bool),
                Result<ReadAllFilesSucceedResult, String>,
            >::from_fn(oxi::fs::collect_files)),
        ),
        ////
        (
            "find_files",
            Object::from(Function::from_fn(oxi::find::find_files)),
        ),
        ////
        (
            "search_in_files",
            Object::from(Function::from_fn(oxi::search::search_in_files)),
        ),
        (
            "search_in_lines",
            Object::from(Function::<
                SearchInLinesParams,
                Result<Vec<LineMatch>, String>,
            >::from_fn(oxi::search::search_in_lines)),
        ),
        (
            "search_in_text",
            Object::from(
                Function::<SearchInTextParams, Result<Vec<LineMatch>, String>>::from_fn(
                    oxi::search::search_in_text,
                ),
            ),
        ),
        (
            "search_in_buffer",
            Object::from(
                Function::<SearchInBufferParams, SearchInBufferResult>::from_fn(
                    oxi::search::search_in_buffer,
                ),
            ),
        ),
        ////
        (
            "replace_file",
            Object::from(Function::from_fn(oxi::replace::replace_file)),
        ),
        (
            "replace_file_by_matches",
            Object::from(Function::from_fn(oxi::replace::replace_file_by_matches)),
        ),
        (
            "replace_file_by_matches_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_by_matches_advance,
            )),
        ),
        (
            "replace_file_preview",
            Object::from(Function::from_fn(oxi::replace::replace_file_preview)),
        ),
        (
            "replace_file_preview_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_preview_advance,
            )),
        ),
        (
            "replace_file_preview_by_matches_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_preview_by_matches_advance,
            )),
        ),
        (
            "replace_text_preview",
            Object::from(Function::from_fn(oxi::replace::replace_text_preview)),
        ),
        (
            "replace_text_preview_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_advance,
            )),
        ),
        (
            "replace_text_preview_by_matches",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_by_matches,
            )),
        ),
        (
            "replace_text_preview_by_matches_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_by_matches_advance,
            )),
        ),
        ////
        (
            "get_filesize",
            Object::from(Function::<String, Result<String, String>>::from_fn(
                oxi::fs::get_filesize,
            )),
        ),
        (
            "readdir",
            Object::from(
                Function::<String, Result<ReaddirSucceedResult, String>>::from_fn(oxi::fs::readdir),
            ),
        ),
        (
            "move",
            Object::from(Function::<MoveParams, Result<bool, String>>::from_fn(
                oxi::fs::r#move,
            )),
        ),
        ////
        ("now", Object::from(Function::from_fn(oxi::date::now))),
        ("md5", Object::from(Function::from_fn(oxi::string::md5))),
        ("uuid", Object::from(Function::from_fn(oxi::string::uuid))),
    ])
}
