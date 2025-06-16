local __module_name__ = "fml.action.toggle.theme" ---@type string

local themes = eve.command.definitions.toggle.theme.candidates ---@type string[]

---@param theme                         string
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
    eve.ux.fn.select({
      title = "Select theme",
      flag_fuzzy = true,
      flag_regex = false,
      input = std.Observable.from_value(theme_name),
      dimension = {
        row = 5,
        width = 50,
      },
      multiple = false,
      get_present = function()
        local theme = eve.context.theme.theme:snapshot() ---@type std.e.Theme
        return theme
      end,
      fetch_items = function()
        local items = {} ---@type eve.ux.select.IItem[]
        for _, theme in ipairs(themes) do
          items[#items + 1] = { uuid = theme, text = theme }
        end
        return items
      end,
      on_confirm = function(widget, items)
        if #items == 1 then
          local item = items[1] ---@type eve.ux.select.IItem
          widget:close()
          apply_theme(item.uuid)
        end
      end,
    })
  end
end

return M
