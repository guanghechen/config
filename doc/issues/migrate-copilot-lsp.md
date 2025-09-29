# Migrate to Copilot LSP

Although this is a deeply-customized Neovim configuration that doesn't use LazyVim, I still want to extract proven effective solutions and apply them to my own configurations. My Neovim config is located at `~/.config/nvim`.

## Migration Steps

1. **Add LSP configuration**: Create `lsp/copilot.lua`, referencing other existing LSP configs and following their conventions, patterns, and common methods. Then combine the LazyVim recommended Copilot LSP settings to refine ours.

2. **Enable Copilot LSP**: Add the Copilot LSP to the `vim.lsp.enable` list inside `lua/eve/init.lua` (don't forget to check if `eve.context.flight.ai:snapshot()` returns `true`).

3. **Mason integration**: Add the Copilot LSP to the Mason ensure-installed list, as we maintain the Copilot LSP through Mason.

4. **Update completion provider**: Remove the `copilot.lua` dependencies and rewrite the Copilot provider source for `blink.cmp` inside `lua/ghc/cmp/copilot.lua` to use the native Copilot LSP. 

