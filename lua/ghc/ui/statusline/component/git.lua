---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "git",
  condition = function(context)
    local buffer_status_line = vim.b[context.bufnr]
    return buffer_status_line and buffer_status_line.gitsigns_status_dict
  end,
  render = function(context)
    local buffer_status_line = vim.b[context.bufnr]
    local git_status = buffer_status_line.gitsigns_status_dict
    local branch_name = git_status.head
    local text = fml.ui.icons.git.Branch .. " " .. branch_name
    local width = vim.fn.strwidth(text)
    return fml.nvimbar.txt(text, "f_sl_text"), width
  end
}

return M
