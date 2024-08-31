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
        (
            "count_lines",
            Object::from(Function::from_fn(oxi::string::count_lines)),
        ),
        ("find", Object::from(Function::from_fn(oxi::find::find))),
        (
            "find_match_points_line_by_line",
            Object::from(Function::from_fn(
                oxi::string::find_match_points_line_by_line,
            )),
        ),
        (
            "get_line_widths",
            Object::from(Function::from_fn(oxi::string::get_line_widths)),
        ),
        (
            "get_locations",
            Object::from(Function::from_fn(oxi::string::get_locations)),
        ),
        (
            "normalize_comma_list",
            Object::from(Function::from_fn(oxi::string::normalize_comma_list)),
        ),
        ("now", Object::from(Function::from_fn(oxi::time::now))),
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
            "replace_file_preview_by_matches",
            Object::from(Function::from_fn(
                oxi::replace::replace_file_preview_by_matches,
            )),
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
        (
            "readdir",
            Object::from(Function::from_fn(oxi::file::readdir)),
        ),
        (
            "search",
            Object::from(Function::from_fn(oxi::search::search)),
        ),
        ("uuid", Object::from(Function::from_fn(oxi::string::uuid))),
    ])
}
