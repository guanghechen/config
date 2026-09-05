use super::super::input_locale_matches;
use super::parse_source_id;

#[test]
fn t_parses_decimal_input_locales() {
    assert_eq!(parse_source_id("1033", "test"), Ok(1033));
    assert_eq!(parse_source_id("2052", "test"), Ok(2052));
    assert_eq!(parse_source_id("67699721", "test"), Ok(67699721));
}

#[test]
fn t_rejects_invalid_input_locales() {
    assert!(parse_source_id("", "test").is_err());
    assert!(parse_source_id("0", "test").is_err());
    assert!(parse_source_id("english", "test").is_err());
}

#[test]
fn t_matches_language_ids_and_exact_layouts() {
    assert!(input_locale_matches(1033, 1033));
    assert!(input_locale_matches(67_699_721, 67_699_721));
    assert!(!input_locale_matches(67_699_721, 1033));
    assert!(!input_locale_matches(134_481_924, 2052));
    assert!(!input_locale_matches(67_699_721, 134_481_924));
}
