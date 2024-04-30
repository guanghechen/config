local icons = require("ghc.core.setting.icons")
local ui = require("ghc.core.setting.ui")

--- @class ghc.ui.statusline.component.git
local M = {
  name = "ghc_statusline_git",
}

M.color = {
  icon = {
    fg = "white",
    bg = "lightbg",
  },
  separator = {
    fg = "lightbg",
    bg = "lightbg",
  },
  separator_rightest = {
    fg = "lightbg",
    bg = ui.transparency and "none" or "statusline_bg",
  },
  text = {
    fg = "white",
    bg = "lightbg",
  },
}

---@return boolean
function M.condition()
  local bufnr_status_line = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  local buffer_status_line = vim.b[bufnr_status_line]
  return buffer_status_line and buffer_status_line.gitsigns_status_dict
end

---@param opts { is_rightest: boolean }
function M.renderer_left(opts)
  local is_rightest = opts.is_rightest

  local bufnr_status_line = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  local buffer_status_line = vim.b[bufnr_status_line]
  local git_status = buffer_status_line.gitsigns_status_dict
  local branch_name = git_status.head

  local color_separator = "%#" .. M.name .. (is_rightest and "_separator_rightest#" or "_separator#")
  local color_icon = "%#" .. M.name .. "_icon#"
  local color_text = "%#" .. M.name .. "_text#"

  local separator = is_rightest and "" or ui.statusline.symbol.separator.right
  local icon = " " .. icons.git.Branch .. " "
  local text = branch_name
  return color_icon .. icon .. color_text .. text .. color_separator .. separator
end

return M
