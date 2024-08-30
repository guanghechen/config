use std::str::FromStr;

pub fn normalize_comma_list(input: &str) -> String {
    let parts: Vec<String> = parse_comma_list(input);
    parts.join(", ")
}

pub fn parse_comma_list(input: &str) -> Vec<String> {
    input
        //-
        .split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect()
}

pub fn parse_comma_list_as_nums<T>(input: &str) -> Result<Vec<T>, String>
where
    T: FromStr,
    T::Err: ToString,
{
    input
        .split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.parse::<T>().map_err(|e| e.to_string()))
        .collect()
}
