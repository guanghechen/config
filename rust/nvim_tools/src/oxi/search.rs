use std::process::Command;

pub fn search(search_pattern: &str, search_paths: &[&str]) -> String {
    let args: Vec<&str> = {
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
        for search_path in search_paths {
            args.push(search_path);
        }
        args
    };

    let output = {
        let mut cmd = Command::new("rg");
        for arg in &args {
            cmd.arg(*arg);
        }

        cmd //
            .output()
            .unwrap_or_else(|_| panic!("failed to execute ripgrep. args: {:?}", args))
    };

    if output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        stdout.to_string()
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        stderr.to_string()
    }
}
