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

  if eve.state.widget.resume() then
    local widget, widget_index = eve.state.widget.get_widget_visible() ---@type eve.t.ux.IWidget|nil
    if widget ~= nil and widget_index ~= nil then
      widget:focus()
      eve.state.widget.history:go(widget_index)
    else
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_fixed = eve.state.tab.get_winnr_fixed(tabnr) ---@type integer|nil

      if winnr_fixed ~= nil then
        vim.api.nvim_tabpage_set_win(tabnr, winnr_fixed)
      end
    end
  else
    eve.command.execute(eve.command.definitions.find.files.uuid)
  end
end

return M
