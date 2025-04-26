---@class fml.action.ux
local M = {}

---@param arg                           unknown|nil
---@return nil
function M.reload_theme(arg)
  local force = type(arg) == "string" and arg:lower() == "force" ---@type boolean
  eve.state.theme.reload_theme(force, true)
end

---@return nil
function M.resume_last_widget()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  if eve.state.status.maximized_winnrs[winnr_cur] then
    eve.command.execute(eve.command.definitions.toggle.maximize.uuid)
    return
  end

  if eve.widget.resume() then
    local widget, widget_index = eve.widget.get_widget_visible() ---@type eve.t.ux.IWidget|nil
    if widget ~= nil and widget_index ~= nil then
      widget:focus()
      eve.widget.history:go(widget_index)
    else
      local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
      if winnr_command ~= nil then
        vim.api.nvim_set_current_win(winnr_command)
      end
    end
  else
    eve.command.execute(eve.command.definitions.find.files.uuid)
  end
end

return M
