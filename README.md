# Lazygit configuration

## Requirements

Themes target Lazygit 0.66.0 or newer. Each generated theme declares its
dark/light appearance and uses the `gui.theme` color settings.

1. Merge the base config with the generated active theme.

   ```zsh
   export LG_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml,${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/local/theme.yml"
   ```

2. Install delta: https://github.com/dandavison/delta

   ```zsh
   cargo install git-delta
   ```

3. Generate and apply themes from the source template.

   Source of truth: `~/.config/guanghechen/asset/theme/template/lazygit/`.
   `default.hbs` is the fallback; each family template replaces it completely.

   ```zsh
   node ~/.config/guanghechen/cli/theme.mjs gen
   node ~/.config/guanghechen/cli/theme.mjs apply
   ```

4. Toggle ignoring whitespace in diffs: Press `<c-w>`.

Delta line numbers link directly to the configured Lazygit editor through
`lazygit-edit://{path}:{line}`.
