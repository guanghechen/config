pub mod algorithm;
pub mod oxi;
pub mod types;
pub mod util;

#[macro_use]
extern crate lazy_static;

use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;
use types::dto::LineMatch;
use types::dto::RenameParams;

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
                Result<util::file::ReadAllFilesSucceedResult, String>,
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
                (String, Vec<String>, bool, bool),
                Result<Vec<LineMatch>, String>,
            >::from_fn(oxi::search::search_in_lines)),
        ),
        (
            "search_in_text",
            Object::from(Function::<
                (String, String, bool, bool),
                Result<Vec<LineMatch>, String>,
            >::from_fn(oxi::search::search_in_text)),
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
            "replace_file_advance_by_matches",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_advance_by_matches,
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
            "replace_file_preview_advance_by_matches",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_preview_advance_by_matches,
            )),
        ),
        (
            "replace_text_preview",
            Object::from(Function::from_fn(oxi::replace::replace_text_preview)),
        ),
        (
            "replace_text_preview_by_matches",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_by_matches,
            )),
        ),
        (
            "replace_text_preview_advance",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_advance,
            )),
        ),
        (
            "replace_text_preview_advance_by_matches",
            Object::from(Function::from_fn(
                oxi::replace::replace_text_preview_advance_by_matches,
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
            Object::from(Function::<
                String,
                Result<util::file::ReaddirSucceedResult, String>,
            >::from_fn(oxi::fs::readdir)),
        ),
        (
            "rename_path",
            Object::from(Function::<
                RenameParams,
                Result<util::file::RenameSucceedResult, String>,
            >::from_fn(oxi::fs::rename_path)),
        ),
        ////
        ("now", Object::from(Function::from_fn(oxi::date::now))),
        ("md5", Object::from(Function::from_fn(oxi::string::md5))),
        ("uuid", Object::from(Function::from_fn(oxi::string::uuid))),
    ])
}
