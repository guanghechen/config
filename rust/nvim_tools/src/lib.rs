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
            "collect_file_paths",
            Object::from(Function::from_fn(oxi::path::collect_file_paths)),
        ),
        (
            "find_match_points",
            Object::from(Function::from_fn(oxi::string::find_match_points)),
        ),
        (
            "normalize_comma_list",
            Object::from(Function::from_fn(oxi::list::normalize_comma_list)),
        ),
        (
            "replace_entire_file",
            Object::from(Function::from_fn(oxi::replace::replace_entire_file)),
        ),
        (
            "replace_text_preview",
            Object::from(Function::from_fn(oxi::replace::replace_text_preview)),
        ),
        (
            "search",
            Object::from(Function::from_fn(oxi::search::search)),
        ),
        ("uuid", Object::from(Function::from_fn(oxi::string::uuid))),
    ])
}
