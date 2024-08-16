use nvim_tools::util::replace;

#[test]
fn test_replace() {
    let text = r#"require("node.path")"#.to_string();
    {
        let search_pattern = r#"require\(([\w\W]+?)\)"#.to_string();
        let replace_pattern = r#"import $1"#.to_string();
        println!(
            "text: {}, search: {}, replace: {}",
            text, search_pattern, replace_pattern
        );
        println!(
            "{:?}",
            replace::replace_text_preview_with_matches(
                &text,
                &search_pattern,
                &replace_pattern,
                true,
                true
            )
        );
        println!(
            "{:?}",
            replace::replace_text_preview_with_matches(
                &text,
                &search_pattern,
                &replace_pattern,
                false,
                true
            )
        );
    }

    {
        let search_pattern = r#"require("node.path")"#.to_string();
        let replace_pattern = r#"import $1"#.to_string();
        println!(
            "text: {}, search: {}, replace: {}",
            text, search_pattern, replace_pattern
        );
        println!(
            "{:?}",
            replace::replace_text_preview_with_matches(
                &text,
                &search_pattern,
                &replace_pattern,
                true,
                false
            )
        );
        println!(
            "{:?}",
            replace::replace_text_preview_with_matches(
                &text,
                &search_pattern,
                &replace_pattern,
                false,
                false
            )
        );
    }
}
