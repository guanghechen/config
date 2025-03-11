local command = require("eve.command")
local editor = require("eve.module.editor")
local state = require("eve.state")

---@class fml.action.ux
local M = {}

---@param context                       eve.command.IContext
---@param arg                           unknown|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.reload_theme(context, arg)
  local force = type(arg) == "string" and arg:lower() == "force" ---@type boolean
  state.theme.reload_theme(force, true)
end

---@param context                       eve.command.IContext
---@return nil
function M.resume_last_widget(context)
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  if state.status.maximized_winnrs[winnr_cur] then
    command.execute(command.definitions.toggle.maximize.uuid, context)
    return
  end

  if state.widget.resume() then
    local widget, widget_index = state.widget.get_widget_visible() ---@type eve.t.ux.IWidget|nil
    if widget ~= nil and widget_index ~= nil then
      widget:focus()
      state.widget.history:go(widget_index)
    else
      if editor.is_win_valid(context.winnr) then
        vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
      end
    end
  else
    command.execute(command.definitions.find.files.uuid, context)
  end
end

return M
