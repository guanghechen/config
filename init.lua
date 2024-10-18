if not vim.g.vscode then
  require("eve.autocmd")
end
_G.eve = require("eve")

if not vim.g.vscode then
  require("fml.autocmd")
end
_G.fml = require("fml")

if not vim.g.vscode then
  require("ghc.autocmd")
  require("ghc.dressing.select")
end
_G.ghc = require("ghc")

if vim.g.vscode then
  pcall(require, "integration.vscode")
  pcall(require, "integration.local")
else
  require("guanghechen.option")
  require("guanghechen.keymap-bootstrap")
  require("guanghechen.keymap")
  pcall(require, "integration.neovide")
  pcall(require, "integration.local")

  ghc.command.theme.reload_theme({ force = false })

  ---! Reload session if not specify file and current directory is a git repository.
  if ghc.context.session.flight_autoload_session:snapshot() and vim.fn.argc() < 1 and eve.path.is_git_repo() then
    vim.schedule(function()
      local ok_load_session, error_load_session = pcall(ghc.command.session.load_autosaved)
      if not ok_load_session then
        eve.reporter.error({
          from = "init",
          subject = "auto reload session",
          message = "Failed to load autosaved session",
          details = { error = error_load_session },
        })
      end
    end)
  end
end

require("guanghechen.plugin.bootstrap")
