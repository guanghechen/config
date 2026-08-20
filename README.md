# Lazygit configuration

## Requirements

1. Merge the base config with the generated active theme.

   ```zsh
   export LG_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml,${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/local/theme.yml"
   ```

2. Install delta: https://github.com/dandavison/delta

   ```zsh
   cargo install git-delta
   ```

3. Generate and apply themes from the source template.

   Source of truth: `~/.config/guanghechen/asset/theme/app/lazygit.hbs`.

   ```zsh
   node ~/.config/guanghechen/cli/theme.mjs gen
   node ~/.config/guanghechen/cli/theme.mjs apply
   ```

4. Enable whitespace diff: Press `<c-w>`
