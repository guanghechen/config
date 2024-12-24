local path = require("eve.lib.path")
local widgets = require("eve.builtin.widgets")
local state = require("eve.state")
local find_files = require("ghc.action.find.files")

local theme_cache_path = path.locate_context_filepath("theme")

---@class ghc.action.ux
local M = {}

---@param arg                           unknown|nil
---@return nil
function M.reload_theme(arg)
  local force = type(arg) == "string" and arg:lower() == "force" ---@type boolean
  local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
  local transparency = state.theme.transparency:snapshot() ---@type boolean

  if force or not path.is_exist(theme_cache_path) then
    fml.ux.theme.apply_theme({
      theme = theme,
      transparency = transparency,
      persistent = true,
      filepath = theme_cache_path,
    })
  else
    dofile(theme_cache_path)

    local scheme = fml.ux.theme.get_scheme(theme) ---@type eve.lib.collection.theme.IScheme|nil
    if scheme ~= nil then
      fml.ux.theme.set_term_colors(scheme)
    end
  end

  ---! Reload the plugins to trigger it to apply the new highlights.
  pcall(function()
    ---! Reload the indent-blankline.nvim plugin.
    vim.cmd("Lazy reload indent-blankline.nvim")
  end)
end

---@return nil
function M.resume_last_widget()
  if not widgets.resume() then
    find_files.find_files()
  end
end

return M
