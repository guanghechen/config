pub mod algorithm;
pub mod types;
pub mod util;

#[macro_use]
extern crate lazy_static;

use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;

#[nvim_oxi::plugin]
fn nvim_tools() -> Dictionary {
    let oxi_search = Function::from_fn(|options_json_str: String| -> String {
        if let Ok(options) = serde_json::from_str::<util::search::SearchOptions>(&options_json_str)
        {
            let result = util::search::search(&options);
            match result {
                Ok((data, _)) => serde_json::to_string(&data).unwrap(),
                Err(err) => serde_json::to_string(&err).unwrap(),
            }
        } else {
            "null".to_string()
        }
    });

    let oxi_replace_text = Function::from_fn(
        |(text, search_query, replace_query): (String, String, String)| {
            util::replace::replace_text(&text, &search_query, &replace_query)
        },
    );

    let oxi_replace_file = Function::from_fn(
        |(file_path, lnum, search_query, replace_query): (String, i32, String, String)| {
            util::replace::replace_file(&file_path, lnum, &search_query, &replace_query)
        },
    );

    Dictionary::from_iter([
        ("search", Object::from(oxi_search)),
        ("replace_text", Object::from(oxi_replace_text)),
        ("replace_file", Object::from(oxi_replace_file)),
    ])
}
