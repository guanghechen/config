use super::{first_english_input_locale, input_locale_matches, is_english};

#[test]
fn t_classifies_english_language_ids_and_full_input_locales() {
    assert!(is_english("1033"));
    assert!(is_english("2057"));
    assert!(is_english("67699721"));
    assert!(is_english(
        &((u64::from(2057_u16) << 16) | u64::from(2057_u16)).to_string()
    ));
    assert!(!is_english("1041"));
    assert!(!is_english("2052"));
    assert!(!is_english("invalid"));
}

#[test]
fn t_matches_language_ids_and_exact_input_locales() {
    assert!(input_locale_matches(1033, 1033));
    assert!(input_locale_matches(67_699_721, 67_699_721));
    assert!(!input_locale_matches(67_699_721, 1033));
    assert!(!input_locale_matches(134_481_924, 2052));
    assert!(!input_locale_matches(67_699_721, 134_481_924));
}

#[test]
fn t_selects_an_available_english_variant() {
    assert_eq!(
        first_english_input_locale([134_481_924, 134_809_609]),
        Some(134_809_609)
    );
    assert_eq!(first_english_input_locale([134_481_924, 68_224_017]), None);
}
