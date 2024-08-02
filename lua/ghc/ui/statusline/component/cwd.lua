---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "cwd",
  will_change = function(context, prev_context)
    return prev_context == nil or context.cwd ~= prev_context.cwd
  end,
  render = function(context)
    local cwd_name = (context.cwd:match("([^/\\]+)[/\\]*$") or context.cwd)
    local text = "󰉋 " .. cwd_name .. " " ---@type string
    local hl_text = fml.nvimbar.txt(text, "f_sl_text") ---@type string
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
