use nvim_tools::util::replace;
use regex::Regex;

#[test]
fn test_rg() {
    let line_separator_regex = Regex::new(r"\s*(?:\r|\r\n|\n)\s*").unwrap();

    let cwd: String = match std::fs::canonicalize("../../") {
        Ok(path) => path.to_string_lossy().to_string(),
        Err(err) => {
            eprintln!("Error getting absolute path: {}", err);
            return;
        }
    };

    let replace_options = replace::ReplaceOptions {
        cwd: Some(cwd),
        flag_regex: true,
        flag_case_sensitive: false,
        search_pattern: r#"require\("(guanghechen\.util\.(?:os|clipboard))"\)"#.to_string(),
        replace_pattern: r#"import "$1""#.to_string(),
        search_paths: vec!["lua".to_string()],
        include_patterns: vec!["*.lua".to_string()],
        exclude_patterns: vec!["".to_string()],
    };
    let result = replace::replace(replace_options);

    match result {
        Ok((data, stdout)) => {
            let serialized_result = serde_json::to_string_pretty(&data).unwrap();
            println!(
                "\n-----stdout-----\n{:?}\n----------------\n{:?}\n----------------",
                serialized_result,
                line_separator_regex
                    .split(&stdout)
                    .filter(|&x| !x.is_empty())
                    .collect::<Vec<_>>()
            );
        }
        Err(stderr) => {
            eprintln!("stderr:\n{}", stderr.error);
        }
    };
}
