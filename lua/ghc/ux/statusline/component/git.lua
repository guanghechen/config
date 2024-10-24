---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "git",
  tight = true,
  condition = function(context)
    local buffer_status_line = vim.b[context.bufnr]
    return buffer_status_line and buffer_status_line.gitsigns_status_dict
  end,
  render = function(context)
    local buffer_status_line = vim.b[context.bufnr]
    local git_status = buffer_status_line.gitsigns_status_dict
    local branch_name = git_status.head ---@type string
    local text = " " .. eve.icons.git.Branch .. " " .. branch_name ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_sl_text") ---@type string
    local width = vim.api.nvim_strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
