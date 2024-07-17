use crate::util;

pub fn search(options_json_str: String) -> (String, String) {
    if let Ok(options) = serde_json::from_str::<util::search::SearchOptions>(&options_json_str) {
        let result = util::search::search(&options);
        match result {
            Ok((data, _, cmd)) => (serde_json::to_string(&data).unwrap(), cmd),
            Err((err, cmd)) => (serde_json::to_string(&err).unwrap(), format!("\n{:?}", cmd)),
        }
    } else {
        ("null".to_string(), "null".to_string())
    }
}
