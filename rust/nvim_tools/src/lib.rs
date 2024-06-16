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
    let oxi_replace = Function::from_fn(|options_json_str: String| -> String {
        if let Ok(options) =
            serde_json::from_str::<util::replace::ReplaceOptions>(&options_json_str)
        {
            let result = util::replace::replace(options);
            match result {
                Ok((data, _)) => serde_json::to_string(&data).unwrap(),
                Err(err) => serde_json::to_string(&err).unwrap(),
            }
        } else {
            "null".to_string()
        }
    });

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
        ("replace", Object::from(oxi_replace)),
        ("replace_text", Object::from(oxi_replace_text)),
        ("replace_file", Object::from(oxi_replace_file)),
    ])
}
