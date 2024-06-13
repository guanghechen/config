pub mod algorithm;
pub mod oxi;

#[macro_use]
extern crate lazy_static;

use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;

#[nvim_oxi::plugin]
fn nvim_tools() -> Dictionary {
    let oxi_search = Function::from_fn(
        |(search_pattern, search_paths): (String, String)| -> String {
            let s: Vec<&str> = vec![&search_paths];
            oxi::search::search(&search_pattern, &s)
        },
    );

    let oxi_replace_text = Function::from_fn(
        |(search_query, replace_query, text): (String, String, String)| {
            oxi::replace::replace_text(text, search_query, replace_query)
        },
    );

    let oxi_replace_file = Function::from_fn(
        |(file_path, lnum, search_query, replace_query): (String, i32, String, String)| {
            oxi::replace::replace_file(file_path, lnum, search_query, replace_query)
        },
    );

    Dictionary::from_iter([
        ("search", Object::from(oxi_search)),
        ("replace_text", Object::from(oxi_replace_text)),
        ("replace_file", Object::from(oxi_replace_file)),
    ])
}
