_G.fml = require("fml")
_G.ghc = require("ghc")

---load theme
ghc.context.client.reload_theme({ force = false })

---@param name "keymap"|"option"|"autocmd"|"keymap-bootstrap"|"option-bootstrap"|"autocmd-bootstrap"
local function load_config(name)
  require("guanghechen." .. name)

  if vim.g.neovide then
    pcall(require, "neovide." .. name)
  end

  pcall(require, "local." .. name)
end

load_config("option-bootstrap")
load_config("autocmd-bootstrap")
load_config("keymap-bootstrap")

-- bootstrap lazy and all plugins
local function load_plugins()
  local lazypath = fml.path.locate_data_filepath("/lazy/lazy.nvim")
  if not fml.path.is_exist(lazypath) then
    local repo = "https://github.com/folke/lazy.nvim.git"
    vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
  end
  vim.opt.rtp:prepend(lazypath)
  require("lazy").setup(require("guanghechen.plugin.lazy"))
end

local ok = pcall(load_plugins)
if ok then
  load_config("option")
  load_config("keymap")
  load_config("autocmd")
else
  load_config("option")
end

vim.schedule(function()
  ---reload session
  local ok_load_session, error_load_session = pcall(ghc.command.session.load_autosaved)
  if not ok_load_session then
    fml.reporter.error({
      from = "init",
      subject = "auto reload session",
      message = "Failed to load autosaved session",
      details = { error = error_load_session }
    })
  end

  ---reload theme
  ghc.context.client.reload_theme({ force = false })
end)
