---@return nil
local function resume_last_widget()
  if dot.state.widget.resume() then
    local widget, widget_index = dot.state.widget.get_widget_visible() ---@type dot.t.IWidget|nil
    if widget ~= nil and widget_index ~= nil then
      widget:focus()
      dot.state.widget.history:go(widget_index)
    else
      local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
      if winnr_command ~= nil then
        vim.api.nvim_set_current_win(winnr_command)
      end
    end
  else
    era.fn.find_files()
  end
end

return resume_last_widget
