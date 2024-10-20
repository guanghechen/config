---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "cwd",
  will_change = function(context, prev_context)
    return prev_context == nil or context.cwd ~= prev_context.cwd
  end,
  render = function(context)
    local cwd_name = (context.cwd:match("([^/\\]+)[/\\]*$") or context.cwd)
    local text = " 󰉋 " .. cwd_name .. " " ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_tl_cwd") ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
