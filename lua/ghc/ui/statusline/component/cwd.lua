---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "cwd",
  will_change = function(context, prev_context)
    return prev_context == nil or context.cwd ~= prev_context.cwd
  end,
  render = function(context)
    local cwd_name = (context.cwd:match("([^/\\]+)[/\\]*$") or context.cwd)
    local text = "󰉋 " .. cwd_name .. " "
    return fml.nvimbar.txt(text, "f_sl_text")
  end
}

return M
