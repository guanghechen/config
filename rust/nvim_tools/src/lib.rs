pub mod algorithm;
pub mod oxi;
pub mod types;
pub mod util;

#[macro_use]
extern crate lazy_static;

use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;

#[nvim_oxi::plugin]
fn nvim_tools() -> Dictionary {
    Dictionary::from_iter([
        ("now", Object::from(Function::from_fn(oxi::date::now))),
        (
            "collect_files",
            Object::from(Function::from_fn(oxi::fs::collect_files)),
        ),
        (
            "count_lines",
            Object::from(Function::from_fn(oxi::string::count_lines)),
        ),
        ("find", Object::from(Function::from_fn(oxi::finder::find))),
        (
            "find_match_points_line_by_line",
            Object::from(Function::from_fn(
                oxi::string::find_match_points_line_by_line,
            )),
        ),
        (
            "get_filesize",
            Object::from(Function::from_fn(oxi::fs::get_filesize)),
        ),
        (
            "get_line_widths",
            Object::from(Function::from_fn(oxi::string::get_line_widths)),
        ),
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
        (
            "search",
            Object::from(Function::from_fn(oxi::searcher::search)),
        ),
        ("uuid", Object::from(Function::from_fn(oxi::string::uuid))),
        ("md5", Object::from(Function::from_fn(oxi::string::md5))),
    ])
}
