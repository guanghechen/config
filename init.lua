require("eve.autocmd")
_G.eve = require("eve")

require("fml.autocmd")
_G.fml = require("fml")

require("ghc.autocmd")
require("ghc.dressing.select")
_G.ghc = require("ghc")

require("guanghechen.autocmd")
require("guanghechen.option")
require("guanghechen.keymap-bootstrap")
require("guanghechen.keymap")
pcall(require, "integration.neovide")
pcall(require, "integration.local")

ghc.context.client.reload_theme({ force = false })

---! bootstrap lazy and all plugins
local lazypath = eve.path.locate_data_filepath("/lazy/lazy.nvim")
if not eve.path.is_exist(lazypath) then
  local repo = "https://github.com/guanghechen/mirror"
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    repo,
    "--single-branch",
    "--branch=nvim@ghc-lazy.nvim",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
vim.env.LAZY_PATH = lazypath
require("lazy").setup({
  spec = require("guanghechen.plugin.bootstrap"),
  defaults = {
    lazy = true,
  },
  install = {
    colorscheme = {},
  },
  checker = {
    enabled = false, -- set true to automatically check for plugin updates
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "2html_plugin",
        "bugreport",
        "compiler",
        "ftplugin",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "matchit",
        "matchparen",
        "netrw",
        "netrwFileHandlers",
        "netrwPlugin",
        "netrwSettings",
        "optwin",
        "rplugin",
        "rrhelper",
        "spellfile_plugin",
        "synmenu",
        "syntax",
        "tar",
        "tarPlugin",
        "tohtml",
        "tutor",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
      },
    },
  },
  ui = {
    icons = {
      ft = "",
      lazy = "󰂠 ",
      loaded = "",
      not_loaded = "",
    },
  },
})

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
