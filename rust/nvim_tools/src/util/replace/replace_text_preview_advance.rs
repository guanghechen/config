use crate::algorithm::kmp::find_all_matched_points;
use crate::types::dto::MatchPoint;
use crate::types::dto::ReplacePreviewResult;
use crate::util::regex::compile_regex;
use regex::Captures;

pub fn replace_text_preview_advance(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<ReplacePreviewResult, String> {
    let mut matches: Vec<MatchPoint> = vec![];
    if flag_regex {
        let result: Result<ReplacePreviewResult, String> = match compile_regex(search_pattern) {
            Ok(r) => {
                let regex = r;
                let mut total_search_len: usize = 0;
                let mut total_replace_len: usize = 0;

                let next_text: String = regex
                    .replace_all(text, |caps: &Captures| {
                        let mut replacement = replace_pattern.to_string();
                        for i in 1..caps.len() {
                            if let Some(cap) = caps.get(i) {
                                let placeholder = format!("${}", i);
                                replacement = replacement.replace(&placeholder, cap.as_str());
                            }
                        }

                        let m = caps.get(0).unwrap();
                        if keep_search_pieces {
                            let search_start: usize = m.start() + total_replace_len;
                            let search_end: usize = search_start + m.len();
                            let replace_start: usize = search_end;
                            let replace_end: usize = replace_start + replacement.len();
                            total_search_len += m.len();
                            total_replace_len += replacement.len();
                            matches.push(MatchPoint {
                                start: search_start,
                                end: search_end,
                            });
                            matches.push(MatchPoint {
                                start: replace_start,
                                end: replace_end,
                            });
                            format!("{}{}", m.as_str(), replacement)
                        } else {
                            let replace_start: usize =
                                m.start() + total_replace_len - total_search_len;
                            let replace_end: usize = replace_start + replacement.len();
                            total_search_len += m.len();
                            total_replace_len += replacement.len();
                            matches.push(MatchPoint {
                                start: replace_start,
                                end: replace_end,
                            });
                            replacement
                        }
                    })
                    .to_string();
                Ok(ReplacePreviewResult {
                    text: next_text,
                    matches,
                })
            }
            Err(error) => Err(error),
        };
        return result;
    }

    let match_points: Vec<usize> = if flag_case_sensitive {
        find_all_matched_points(text.as_bytes(), search_pattern.as_bytes(), None)
    } else {
        let text_lower = text.to_lowercase();
        let pattern_lower = search_pattern.to_lowercase();
        find_all_matched_points(text_lower.as_bytes(), pattern_lower.as_bytes(), None)
    };
    let len_of_search: usize = search_pattern.len();
    let len_of_replace: usize = replace_pattern.len();
    let mut total_search_len: usize = 0;
    let mut total_replace_len: usize = 0;
    let mut pieces: Vec<&str> = vec![];
    let mut i: usize = 0;
    for m in match_points {
        let j: usize = m + len_of_search;
        if keep_search_pieces {
            let search_start: usize = m + total_replace_len;
            let search_end: usize = search_start + len_of_search;
            let replace_start: usize = search_end;
            let replace_end: usize = replace_start + len_of_replace;
            total_search_len += len_of_search;
            total_replace_len += len_of_replace;
            matches.push(MatchPoint {
                start: search_start,
                end: search_end,
            });
            matches.push(MatchPoint {
                start: replace_start,
                end: replace_end,
            });
            pieces.push(&text[i..j]);
            pieces.push(replace_pattern);
        } else {
            let replace_start: usize = m + total_replace_len - total_search_len;
            let replace_end: usize = replace_start + len_of_replace;
            total_search_len += len_of_search;
            total_replace_len += len_of_replace;
            matches.push(MatchPoint {
                start: replace_start,
                end: replace_end,
            });
            pieces.push(&text[i..m]);
            pieces.push(replace_pattern);
        }
        i = j;
    }
    pieces.push(&text[i..]);
    let next_text: String = pieces.join("");
    Ok(ReplacePreviewResult {
        text: next_text,
        matches,
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_replace_text_preview_advance_1() {
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
                super::replace_text_preview_advance(
                    &text,
                    &search_pattern,
                    &replace_pattern,
                    true,
                    true,
                    true
                )
            );
            println!(
                "{:?}",
                super::replace_text_preview_advance(
                    &text,
                    &search_pattern,
                    &replace_pattern,
                    false,
                    true,
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
                super::replace_text_preview_advance(
                    &text,
                    &search_pattern,
                    &replace_pattern,
                    true,
                    false,
                    true
                )
            );
            println!(
                "{:?}",
                super::replace_text_preview_advance(
                    &text,
                    &search_pattern,
                    &replace_pattern,
                    false,
                    false,
                    true
                )
            );
        }
    }

    #[test]
    fn test_replace_text_preview_advance_2() {
        let text: &str = r#"
### Requirements

* fd: https://github.com/sharkdp/fd?tab=readme-ov-file#installation
  - homebrew
    ```zsh
    brew install fd
    ```

* fzf: https://github.com/junegunn/fzf#installation
  - homebrew
    ```zsh
    brew install fzf
    ```

* lazygit: https://github.com/jesseduffield/lazygit#installation
  - homebrew
    ```zsh
    brew install lazygit
    ```

* rg: https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation
  - homebrew
    ```zsh
    brew install ripgrep
    ```

* rust: **install use rustup instead of homebrew**
  
  https://doc.rust-lang.org/book/ch01-01-installation.html#installing-rustup-on-linux-or-macos

  - macos
    ```zsh
    curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
    ```

### FAQ

* multiple configs

  ```zsh
  alias nvchad='NVIM_APPNAME=nvim-nvchad nvim'
  ```
    "#;

        let search_pattern: &str = "lazygit";
        let replace_pattern: &str = "__waw__";
        let result_with_regex = super::replace_text_preview_advance(
            text,
            search_pattern,
            replace_pattern,
            true,
            true,
            true,
        );
        let result_without_regex = super::replace_text_preview_advance(
            text,
            search_pattern,
            replace_pattern,
            true,
            false,
            true,
        );

        assert!(result_with_regex.is_ok());
        assert!(result_without_regex.is_ok());

        let result_with_regex = result_with_regex.unwrap();
        let result_without_regex = result_without_regex.unwrap();
        assert_eq!(result_with_regex.text, result_without_regex.text);
        assert_eq!(result_with_regex.matches, result_without_regex.matches);
    }
}
