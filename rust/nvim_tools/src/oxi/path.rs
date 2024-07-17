use crate::util;

pub fn collect_file_paths((cwd, exclude_patterns): (String, String)) -> String {
    let exclude_patterns: Vec<String> = util::string::parse_comma_list(&exclude_patterns);
    let paths: Vec<String> = util::path::collect_file_paths(&cwd, &exclude_patterns);
    paths.join(",")
}
