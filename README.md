## Requirements

1. Install lazygit, see https://github.com/jesseduffield/lazygit

   - macos

     ```zsh
     brew install lazygit
     ```

2. Install fd (for lazygit), see https://github.com/sharkdp/fd

   - macos

     ```zsh
     brew install fd
     ```

3. Install fzf, see https://github.com/junegunn/fzf?tab=readme-ov-file

   - windows

     ```powershell
     winget install fzf
     ```

   - wsl / ubuntu
     ```zsh
     sudo apt install fzf
     ```

4. Install rustc/cargo

   - wsl

     ```zsh
     # cargo is distributed by default with Rust.
     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
     ```
