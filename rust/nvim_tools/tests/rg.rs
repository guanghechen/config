#[cfg(test)]
mod tests {
    use std::process::Command;

    fn escape_special_characters(s: &str) -> String {
        let mut escaped = String::new();
        for c in s.chars() {
            match c {
                ' ' => escaped.push_str("\\ "),   // Escape spaces
                '"' => escaped.push_str("\\\""),  // Escape double quotes
                '\'' => escaped.push_str("\\\'"), // Escape single quotes
                '$' => escaped.push_str("\\$"),   // Escape dollar signs
                _ => escaped.push(c),
            }
        }
        escaped
    }

    fn stringify_vector(string_vec: &[&str]) -> String {
        string_vec
            .iter()
            .map(|s| escape_special_characters(s))
            .collect::<Vec<String>>()
            .join(" ")
    }

    #[test]
    fn test_rg() {
        let search_pattern = "mod";
        let search_paths = vec!["src", "tests"];

        let output = {
            let mut args: Vec<&str> = vec![
                "--color=never",
                "--no-heading",
                "--no-filename",
                "--line-number",
                "--column",
                "--text",
                "--multiline",
                "--hidden",
                "--files-with-matches",
            ];

            // set search pattern
            args.push("--regexp");
            args.push(search_pattern);

            // set search paths
            for search_path in &search_paths {
                args.push(search_path);
            }

            let mut cmd = Command::new("rg");
            for arg in &args {
                cmd.arg(*arg);
            }

            println!("executing: rg {}", stringify_vector(&args));

            cmd.output().expect("failed to execute ripgrep")
        };

        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            println!("\n-----stdout-----\n{}----------------\n", stdout);
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            eprintln!("stderr:\n{}", stderr);
        }
    }
}
