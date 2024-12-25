local command = require("eve.lib.command")
local path = require("eve.lib.path")
local state = require("eve.state")

local theme_cache_path = path.locate_context_filepath("theme")

---@class fml.action.ux
local M = {}

---@param context                       eve.lib.command.IContext
---@param arg                           unknown|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.reload_theme(context, arg)
  local force = type(arg) == "string" and arg:lower() == "force" ---@type boolean
  local theme = state.theme.theme:snapshot() ---@type eve.e.Theme
  local transparency = state.theme.transparency:snapshot() ---@type boolean

  if force or not path.is_exist(theme_cache_path) then
    require("fml.ux.theme").apply_theme({
      theme = theme,
      transparency = transparency,
      persistent = true,
      filepath = theme_cache_path,
    })
  else
    dofile(theme_cache_path)

    local scheme = require("fml.ux.theme").get_scheme(theme) ---@type eve.lib.collection.theme.IScheme|nil
    if scheme ~= nil then
      require("fml.ux.theme").set_term_colors(scheme)
    end
  end

  ---! Reload the plugins to trigger it to apply the new highlights.
  pcall(function()
    ---! Reload the indent-blankline.nvim plugin.
    vim.cmd("Lazy reload indent-blankline.nvim")
  end)
end

---@param context                       eve.lib.command.IContext
---@return nil
function M.resume_last_widget(context)
  if not state.widget.resume() then
    command.execute(command.definitions.find.files.uuid, context)
  end
end

return M
