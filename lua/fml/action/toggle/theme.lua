local __module_name__ = "fml.action.toggle.theme" ---@type string

local themes = eve.command.definitions.toggle.theme.candidates ---@type string[]
local o_theme = eve.context.theme.theme ---@type std.collection.IObservable

---@param theme                          string
---@return nil
local function apply_theme(theme)
  if not vim.list_contains(themes, theme) then
    std.reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Unknown theme.",
      details = { theme = theme },
    })
    return
  end

  local app_home = std.path.locate_app_config_home("guanghechen")
  local script_path = std.path.join(app_home, "config/theme/apply_theme.mjs")
  local ok, error = pcall(function()
    vim.fn.system({ "node", script_path, theme })
  end)
  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "apply_theme",
      message = "Failed to toggle theme.",
      details = { theme = theme, app_home = app_home, script_path = script_path, error = error },
    })
  end
end

---@class fml.action.toggle.theme
local M = {}

---@param arg                           unknown|nil
---@return nil
function M.theme(arg)
  local theme_name = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(themes, theme_name) then
    apply_theme(theme_name)
  else
    local current_theme = o_theme:snapshot() ---@type std.e.Theme
    vim.ui.select(themes, {
      name = __module_name__,
      prompt = "Select theme: ",
      uuid_current = current_theme,
      dimension = {
        row = 5,
        width = 50,
      },
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice then
        apply_theme(choice)
      end
    end)
  end
end

return M
