local context_config = require("ghc.core.context.config")
local icons = require("ghc.core.setting.icons")
local guanghechen = require("guanghechen")

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

  local relative_path = guanghechen.util.path.relative(guanghechen.util.path.cwd(), filepath)
  return relative_path ~= "."
end

function M.renderer()
  local filepath = vim.fn.expand("%:p")
  local cwd = guanghechen.util.path.cwd()
  local relative_to_cwd = guanghechen.util.path.relative(cwd, filepath)
  if string.sub(relative_to_cwd, 1, 1) == "." and guanghechen.util.path.is_absolute(filepath) then
    local workspace = guanghechen.util.path.workspace()
    if cwd ~= workspace then
      local relative_to_workspace = guanghechen.util.path.relative(workspace, filepath)
      if string.sub(relative_to_workspace, 1, 1) == "." then
        relative_to_cwd = guanghechen.util.path.normalize(filepath)
      end
    end
  end

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

  local icon = " " .. guanghechen.util.filetype.calc_fileicon(filepath) .. " "
  local text = icon .. relative_to_cwd .. added .. removed .. changed .. " "
  return color_text .. text
end

return M

