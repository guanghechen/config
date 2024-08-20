---@param name "keymap"|"option"|"autocmd"|"keymap-bootstrap"|"option-bootstrap"|"autocmd-bootstrap"
local function _load_config(name)
  require("guanghechen." .. name)

  if vim.g.neovide then
    pcall(require, "neovide." .. name)
  end

  pcall(require, "local." .. name)
end

---@return nil
local function bootstrap()
  _G.fml = require("fml")
  _G.ghc = require("ghc")

  ---! Load options
  _load_config("option-bootstrap")

  ---! Load theme
  ghc.context.client.reload_theme({ force = false })

  ---! Load autocmd
  _load_config("autocmd-bootstrap")

  ---! Load keymap
  _load_config("keymap-bootstrap")
end

---! bootstrap lazy and all plugins
---@return nil
local function load_plugins()
  local lazypath = fml.path.locate_data_filepath("/lazy/lazy.nvim")
  if not fml.path.is_exist(lazypath) then
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

  _load_config("option")
  _load_config("keymap")
  _load_config("autocmd")
end

---@return nil
local function load_autosave_session()
  ---! Reload session if not specify file and current directory is a git repository.
  if ghc.context.session.flight_autoload_session:snapshot() and vim.fn.argc() < 1 and fml.path.is_git_repo() then
    vim.schedule(function()
      local ok_load_session, error_load_session = pcall(ghc.command.session.load_autosaved)
      if not ok_load_session then
        fml.reporter.error({
          from = "init",
          subject = "auto reload session",
          message = "Failed to load autosaved session",
          details = { error = error_load_session },
        })
      end
    end)
  end
end

bootstrap()
pcall(load_plugins)
pcall(load_autosave_session)
