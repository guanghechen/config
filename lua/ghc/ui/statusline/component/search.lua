---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "fml.ui.search",
  condition = function()
    local search = fml.ui.search.get_current_instance() ---@type fml.types.ui.search.ISearch|nil
    return search ~= nil and search.state.visible:snapshot()
  end,
  render = function()
    local search = fml.ui.search.get_current_instance() ---@type fml.types.ui.search.ISearch|nil
    if search == nil then
      return "", 0
    end

    local hl_text = "" ---@type string
    local width = 0 ---@type integer

    local items = search.statusline_items ---@type fml.types.ui.search.IStatuslineItem[]
    for _, item in ipairs(items) do
      local fn = item.callback_fn ---@type string
      if item.type == "flag" then
        local flag = item.state:snapshot() ---@type boolean
        local text = " " .. item.symbol .. " " ---@type string
        local hlname = flag and "f_sl_flag_enabled" or "f_sl_flag" ---@type string
        width = width + vim.fn.strwidth(text)
        hl_text = hl_text .. fml.nvimbar.btn(fml.nvimbar.txt(text, hlname), fn)
      elseif item.type == "enum" then
        local flag = item.state:snapshot() ---@type boolean
        local text = " " .. flag .. " " ---@type string
        local hlname = "f_sl_flag_scope"
        width = width + vim.fn.strwidth(text)
        hl_text = hl_text .. fml.nvimbar.btn(fml.nvimbar.txt(text, hlname), fn)
      end
    end

    return hl_text, width
  end,
}

return M
