use nvim_tools::types::dto::SearchInFilesParams;
use nvim_tools::util::search;

#[test]
fn test_rg() {
    let cwd: String = match std::fs::canonicalize(".") {
        Ok(path) => path.to_string_lossy().to_string(),
        Err(err) => {
            eprintln!("Error getting absolute path: {}", err);
            return;
        }
    };

    let replace_options = SearchInFilesParams {
        cwd: Some(cwd),
        flag_case_sensitive: true,
        flag_gitignore: true,
        flag_regex: true,
        max_matches: Some(300),
        max_filesize: Some("1M".to_string()),
        search_pattern: r#"Hello, (world|世界)!\n"#.to_string(),
        search_paths: "tests/fixtures".to_string(),
        include_patterns: "*.txt".to_string(),
        exclude_patterns: ".git, c.txt".to_string(),
        specified_filepath: None,
    };
    let result = search::search_in_files(&replace_options);

    match result {
        Ok(data) => {
            let serialized_result: String = serde_json::to_string_pretty(&data.items).unwrap();
            let formatted_output: String = data.stdout.trim().to_string();

            println!(
                "\n{}\n-----stdout-----\n{}\n----------------\n{}\n----------------",
                data.cmd, serialized_result, formatted_output,
            );
        }
        Err(data) => {
            eprintln!("\n{}\nstderr:\n{}", data.cmd, data.error);
        }
    };
}
