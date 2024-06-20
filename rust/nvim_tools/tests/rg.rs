use nvim_tools::util::search;
use regex::Regex;

#[test]
fn test_rg() {
    let line_separator_regex = Regex::new(r"\s*(?:\r|\r\n|\n)\s*").unwrap();

    let cwd: String = match std::fs::canonicalize(".") {
        Ok(path) => path.to_string_lossy().to_string(),
        Err(err) => {
            eprintln!("Error getting absolute path: {}", err);
            return;
        }
    };

    let replace_options = search::SearchOptions {
        cwd: Some(cwd),
        flag_regex: true,
        flag_case_sensitive: true,
        search_pattern: r#"Hello, (world|世界)!\nH"#.to_string(),
        search_paths: "tests/fixtures".to_string(),
        include_patterns: "*.txt".to_string(),
        exclude_patterns: ".git, c.txt".to_string(),
    };
    let result = search::search(&replace_options);

    match result {
        Ok((data, stdout, cmd)) => {
            let serialized_result = serde_json::to_string_pretty(&data).unwrap();
            println!(
                "\n{}\n-----stdout-----\n{}\n----------------\n{:?}\n----------------",
                cmd,
                serialized_result,
                line_separator_regex
                    .split(&stdout)
                    .filter(|&x| !x.is_empty())
                    .collect::<Vec<_>>()
            );
        }
        Err((stderr, cmd)) => {
            eprintln!("\n{}\nstderr:\n{}", cmd, stderr.error);
        }
    };
}
