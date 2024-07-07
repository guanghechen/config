pub mod algorithm;
pub mod types;
pub mod util;

#[macro_use]
extern crate lazy_static;

use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;
use uuid::Uuid;

#[nvim_oxi::plugin]
fn nvim_tools() -> Dictionary {
    let oxi_normalize_comma_list =
        Function::from_fn(|input: String| util::string::normalize_comma_list(&input));

    let oxi_search = Function::from_fn(|options_json_str: String| -> (String, String) {
        if let Ok(options) = serde_json::from_str::<util::search::SearchOptions>(&options_json_str)
        {
            let result = util::search::search(&options);
            match result {
                Ok((data, _, cmd)) => (serde_json::to_string(&data).unwrap(), cmd),
                Err((err, cmd)) => (serde_json::to_string(&err).unwrap(), format!("\n{:?}", cmd)),
            }
        } else {
            ("null".to_string(), "null".to_string())
        }
    });

    let oxi_replace_text_preview = Function::from_fn(
        |(text, search_pattern, replace_pattern, keep_search_pieces, flag_regex): (
            String,
            String,
            String,
            bool,
            bool,
        )|
         -> String {
            let result = util::replace::replace_text_preview(
                &text,
                &search_pattern,
                &replace_pattern,
                keep_search_pieces,
                flag_regex,
            );
            serde_json::to_string(&result).unwrap()
        },
    );

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

    let oxi_uuid = Function::from_fn(|_: String| -> String {
        let uuid = Uuid::new_v4();
        uuid.to_string()
    });

    Dictionary::from_iter([
        (
            "normalize_comma_list",
            Object::from(oxi_normalize_comma_list),
        ),
        ("replace_file", Object::from(oxi_replace_file)),
        (
            "replace_text_preview",
            Object::from(oxi_replace_text_preview),
        ),
        ("replace_text", Object::from(oxi_replace_text)),
        ("search", Object::from(oxi_search)),
        ("uuid", Object::from(oxi_uuid)),
    ])
}
