pub fn parse_comma_list(input: &str) -> Vec<String> {
    input
        .split(',')
        .map(|segment| segment.trim())
        .filter(|segment| !segment.is_empty())
        .map(|segment| segment.to_string())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::parse_comma_list;

    #[test]
    fn test_splits_and_trims_segments() {
        let items = parse_comma_list("foo, bar , ,baz,,");
        assert_eq!(items, vec!["foo", "bar", "baz"]);
    }
}
