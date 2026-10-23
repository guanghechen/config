use crate::search::ISearchInLinesMatchPoint;
use crate::search::matcher;
use crate::types::replace::IReplacePreviewResult;
use regex::Captures;

pub fn replace_text_preview_advance(
    text: &str,
    search_pattern: &str,
    replace_pattern: &str,
    keep_search_pieces: bool,
    flag_regex: bool,
    flag_case_sensitive: bool,
) -> Result<IReplacePreviewResult, String> {
    let mut matches: Vec<ISearchInLinesMatchPoint> = vec![];
    let regex = matcher(search_pattern, flag_regex, flag_case_sensitive)?;
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
                matches.push(ISearchInLinesMatchPoint {
                    start: search_start,
                    end: search_end,
                });
                matches.push(ISearchInLinesMatchPoint {
                    start: replace_start,
                    end: replace_end,
                });
                format!("{}{}", m.as_str(), replacement)
            } else {
                let replace_start: usize = m.start() + total_replace_len - total_search_len;
                let replace_end: usize = replace_start + replacement.len();
                total_search_len += m.len();
                total_replace_len += replacement.len();
                matches.push(ISearchInLinesMatchPoint {
                    start: replace_start,
                    end: replace_end,
                });
                replacement
            }
        })
        .to_string();
    Ok(IReplacePreviewResult {
        text: next_text,
        matches,
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn t_case_insensitive_literal_ranges_are_in_the_preview() {
        let result =
            super::replace_text_preview_advance("İab", "a", "XY", false, false, false).unwrap();
        assert_eq!(result.text, "İXYb");
        assert_eq!((result.matches[0].start, result.matches[0].end), (2, 4));
    }

    #[test]
    fn t_literal_pattern_previews_the_same_with_and_without_regex() {
        // Spell out the whitespace-only line so formatters preserve the fixture.
        let text: &str = concat!(
            r#"
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
"#,
            "  \n",
            r#"  https://doc.rust-lang.org/book/ch01-01-installation.html#installing-rustup-on-linux-or-macos

  - macos
    ```zsh
    curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
    ```

### FAQ

* multiple configs

  ```zsh
  alias nvchad='NVIM_APPNAME=nvim-nvchad nvim'
  ```
    "#,
        );

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
