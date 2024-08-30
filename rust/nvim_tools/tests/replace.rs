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
            replace::replace_text_preview_advance(
                &text,
                &search_pattern,
                &replace_pattern,
                true,
                true
            )
        );
        println!(
            "{:?}",
            replace::replace_text_preview_advance(
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
            replace::replace_text_preview_advance(
                &text,
                &search_pattern,
                &replace_pattern,
                true,
                false
            )
        );
        println!(
            "{:?}",
            replace::replace_text_preview_advance(
                &text,
                &search_pattern,
                &replace_pattern,
                false,
                false
            )
        );
    }
}

#[test]
fn test_replace_text_preview_with_matches() {
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
    let result_with_regex = replace::replace_text_preview_advance(
        text,
        search_pattern,
        replace_pattern,
        true,
        true,
    );
    let result_without_regex = replace::replace_text_preview_advance(
        text,
        search_pattern,
        replace_pattern,
        true,
        false,
    );

    assert!(result_with_regex.is_ok());
    assert!(result_without_regex.is_ok());

    let result_with_regex = result_with_regex.unwrap();
    let result_without_regex = result_without_regex.unwrap();
    assert_eq!(result_with_regex.text, result_without_regex.text);
    assert_eq!(result_with_regex.matches, result_without_regex.matches);
}
