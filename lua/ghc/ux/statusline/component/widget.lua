---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "fml.ux.widget",
  condition = function()
    local widget = eve.widgets.get_current_widget() ---@type t.eve.ux.IWidget|nil
    return widget ~= nil and widget:status() == "visible"
  end,
  render = function()
    local widget = eve.widgets.get_current_widget() ---@type t.eve.ux.IWidget|nil
    if widget == nil then
      return "", 0
    end

    local items = widget.statusline_items ---@type t.eve.ux.widget.IStatuslineItem[]|nil
    if items == nil or #items < 1 then
      return "", 0
    end

    local hl_text = "" ---@type string
    local width = 0 ---@type integer

    for _, item in ipairs(items) do
      local fn = item.callback_fn ---@type string
      if item.type == "flag" then
        local flag = item.state:snapshot() ---@type boolean
        local text = " " .. item.symbol .. " " ---@type string
        local hlname = flag and "f_sl_flag_enabled" or "f_sl_flag" ---@type string
        width = width + vim.api.nvim_strwidth(text)
        hl_text = hl_text .. eve.nvimbar.btn(eve.nvimbar.txt(text, hlname), fn)
      elseif item.type == "enum" then
        local flag = item.state:snapshot() ---@type boolean
        local text = " " .. flag .. " " ---@type string
        local hlname = "f_sl_flag_scope"
        width = width + vim.api.nvim_strwidth(text)
        hl_text = hl_text .. eve.nvimbar.btn(eve.nvimbar.txt(text, hlname), fn)
      end
    end

    return hl_text, width
  end,
}

return M
