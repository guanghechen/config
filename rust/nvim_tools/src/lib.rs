pub mod algorithm;
pub mod oxi;
pub mod types;
pub mod util;

#[macro_use]
extern crate lazy_static;

use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;
use types::r#match::LineMatch;

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
            Object::from(Function::from_fn(oxi::fs::collect_files)),
        ),
        ////
        (
            "find_files",
            Object::from(Function::from_fn(oxi::finder::find_files)),
        ),
        ////
        (
            "search",
            Object::from(Function::from_fn(oxi::searcher::search)),
        ),
        (
            "search_in_lines",
            Object::from(Function::<
                (String, Vec<String>, bool, bool),
                Result<Vec<LineMatch>, String>,
            >::from_fn(oxi::searcher::search_in_lines)),
        ),
        (
            "search_in_text",
            Object::from(Function::<
                (String, String, bool, bool),
                Result<Vec<LineMatch>, String>,
            >::from_fn(oxi::searcher::search_in_text)),
        ),
        ////
        (
            "get_filesize",
            Object::from(Function::from_fn(oxi::fs::get_filesize)),
        ),
        ("now", Object::from(Function::from_fn(oxi::date::now))),
        (
            "replace_file",
            Object::from(Function::from_fn(oxi::replacer::replace_file)),
        ),
        (
            "replace_file_by_matches",
            Object::from(Function::from_fn(oxi::replacer::replace_file_by_matches)),
        ),
        (
            "replace_file_advance_by_matches",
            Object::from(Function::from_fn(
                oxi::replacer::replace_file_advance_by_matches,
            )),
        ),
        (
            "replace_file_preview",
            Object::from(Function::from_fn(oxi::replacer::replace_file_preview)),
        ),
        (
            "replace_file_preview_advance",
            Object::from(Function::from_fn(
                oxi::replacer::replace_file_preview_advance,
            )),
        ),
        (
            "replace_file_preview_advance_by_matches",
            Object::from(Function::from_fn(
                oxi::replacer::replace_file_preview_advance_by_matches,
            )),
        ),
        (
            "replace_text_preview",
            Object::from(Function::from_fn(oxi::replacer::replace_text_preview)),
        ),
        (
            "replace_text_preview_by_matches",
            Object::from(Function::from_fn(
                oxi::replacer::replace_text_preview_by_matches,
            )),
        ),
        (
            "replace_text_preview_advance",
            Object::from(Function::from_fn(
                oxi::replacer::replace_text_preview_advance,
            )),
        ),
        (
            "replace_text_preview_advance_by_matches",
            Object::from(Function::from_fn(
                oxi::replacer::replace_text_preview_advance_by_matches,
            )),
        ),
        ("readdir", Object::from(Function::from_fn(oxi::fs::readdir))),
        (
            "rename_path",
            Object::from(Function::from_fn(oxi::fs::rename_path)),
        ),
        ("uuid", Object::from(Function::from_fn(oxi::string::uuid))),
        ("md5", Object::from(Function::from_fn(oxi::string::md5))),
    ])
}
