local context_config = require("ghc.core.context.config")
local icons = require("ghc.core.setting.icons")
local util_filetype = require("ghc.core.util.filetype")
local util_path = require("guanghechen.util.path")

---@type boolean
local transparency = context_config.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.filepath
local M = {
  name = "ghc_statusline_filepath",
  color = {
    text = {
      fg = "white",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  local filepath = vim.fn.expand("%:p")
  if not filepath or #filepath == 0 then
    return false
  end

  local relative_path = util_path.relative(util_path.cwd(), filepath)
  return relative_path ~= "."
end

function M.renderer()
  local filepath = vim.fn.expand("%:p")
  local relative_path = util_path.relative(util_path.cwd(), filepath)

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

  local color_text = "%#" .. M.name .. "_text#"

  local icon = " " .. util_filetype.calc_fileicon(filepath) .. " "
  local text = icon .. relative_path .. added .. removed .. changed .. " "
  return color_text .. text
end

return M
