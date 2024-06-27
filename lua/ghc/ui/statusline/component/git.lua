---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "git",
  condition = function(context)
    local buffer_status_line = vim.b[context.bufnr]
    return buffer_status_line and buffer_status_line.gitsigns_status_dict
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_text"
      end,
      text = function(context)
        local buffer_status_line = vim.b[context.bufnr]
        local git_status = buffer_status_line.gitsigns_status_dict
        local branch_name = git_status.head
        return fml.ui.icons.git.Branch .. " " .. branch_name
      end,
    },
  },
}

return M
