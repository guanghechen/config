## Requirements

1. Install `bat`

   ```zsh
   brew install bat
   ```

## Usage

1. Put below config into the **base/zsh** config

   ```zsh
    alias fvim='FZF_DEFAULT_OPTS_FILE=~/.config/fzf/nvim.fzfrc fzf --print0 | xargs -0 -o nvim'
   ```
