use globset::{Glob, GlobSetBuilder};
use walkdir::WalkDir;

pub fn collect_file_paths<S: AsRef<str>>(cwd: &str, exclude_patterns: &[S]) -> Vec<String> {
    let glob = {
        let mut builder = GlobSetBuilder::new();
        for pattern in exclude_patterns.iter() {
            builder.add(Glob::new(pattern.as_ref()).unwrap());
        }
        builder.build().unwrap()
    };

    let mut paths: Vec<String> = Vec::new();
    for entry in WalkDir::new(cwd).into_iter().filter_map(|e| e.ok()) {
        if entry.file_type().is_file() {
            if let Ok(relative_path) = entry.path().strip_prefix(cwd) {
                if !glob.is_match(relative_path) {
                    paths.push(relative_path.display().to_string());
                }
            }
        }
    }

    paths
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_glob() {
        let exclude_patterns = [".git/**", "target/**"];
        let glob = {
            let mut builder = GlobSetBuilder::new();
            for pattern in exclude_patterns.iter() {
                builder.add(Glob::new(pattern).unwrap());
            }
            builder.build().unwrap()
        };

        assert!(glob.is_match(".git/config"));
    }
}
