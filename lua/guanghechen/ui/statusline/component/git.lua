---@type boolean
local transparency = ghc.context.theme.transparency:get_snapshot()

--- @class guanghechen.ui.statusline.component.git
local M = {
  name = "ghc_statusline_git",
}

M.color = {
  text = {
    fg = "white",
    bg = transparency and "none" or "statusline_bg",
  },
}

---@return boolean
function M.condition()
  local bufnr_status_line = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  local buffer_status_line = vim.b[bufnr_status_line]
  return buffer_status_line and buffer_status_line.gitsigns_status_dict
end

function M.renderer()
  local bufnr_status_line = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  local buffer_status_line = vim.b[bufnr_status_line]
  local git_status = buffer_status_line.gitsigns_status_dict
  local branch_name = git_status.head

  local color_text = "%#" .. M.name .. "_text#"
  local text = " " .. ghc.ui.icons.git.Branch .. " " .. branch_name .. " "
  return color_text .. text
end

return M
