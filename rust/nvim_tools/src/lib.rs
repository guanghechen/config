pub mod algorithm;
pub mod oxi;

use nvim_oxi::Dictionary;
use nvim_oxi::Function;
use nvim_oxi::Object;
use oxi::search::search;

#[nvim_oxi::plugin]
fn nvim_tools() -> Dictionary {
    let oxi_search = Function::from_fn(
        |(search_pattern, search_paths): (String, String)| -> String {
            let s: Vec<&str> = vec![&search_paths];
            search(&search_pattern, &s)
        },
    );
    Dictionary::from_iter([("search", Object::from(oxi_search))])
}
