local icons = require("ghc.core.setting.icons")
local ui = require("ghc.core.setting.ui")
local path = require("ghc.core.util.path")
local calc_fileicon = require("ghc.core.util.filetype").calc_fileicon

--- @class ghc.ui.statusline.component.filepath
local M = {
  name = "ghc_statusline_filepath",
}

M.color = {
  icon = {
    fg = "white",
    bg = ui.transparency and "none" or "statusline_bg",
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
    bg = ui.transparency and "none" or "statusline_bg",
  },
}

function M.condition()
  local filepath = vim.fn.expand("%:p")
  if not filepath or #filepath == 0 then
    return false
  end

  local relative_path = path.relative(path.cwd(), filepath)
  return relative_path ~= "."
end

---@param opts { is_rightest: boolean }
function M.renderer_left(opts)
  local is_rightest = opts.is_rightest
  local filepath = vim.fn.expand("%:p")
  local relative_path = path.relative(path.cwd(), filepath)

  ---@type string
  local added = ""

  ---@type string
  local removed = ""

  ---@type string
  local changed = ""

  --Try git status.
  local bufnr_status_line = vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
  local buffer_status_line = vim.b[bufnr_status_line]
  if buffer_status_line and buffer_status_line.gitsigns_head and not buffer_status_line.gitsigns_git_status then
    local git_status = buffer_status_line.gitsigns_status_dict

    if git_status.added and git_status.added > 0 then
      added = " " .. icons.git.Add .. " " .. git_status.added
    end

    if git_status.changed and git_status.changed > 0 then
      changed = " " .. icons.git.Mod_alt .. " " .. git_status.changed
    end

    if git_status.removed and git_status.removed > 0 then
      removed = " " .. icons.git.Remove .. " " .. git_status.removed
    end
  end

  local color_separator = "%#" .. M.name .. (is_rightest and "_separator_rightest#" or "_separator#")
  local color_icon = "%#" .. M.name .. "_icon#"
  local color_text = "%#" .. M.name .. "_text#"

  local separator = is_rightest and "" or ui.statusline.symbol.separator.right
  local icon = " " .. calc_fileicon(filepath) .. " "
  local text = relative_path .. added .. removed .. changed .. " "
  return color_icon .. icon .. color_text .. text .. color_separator .. separator
end

return M
