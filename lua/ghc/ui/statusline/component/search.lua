local context = {
  repo = require("ghc.core.context.repo"),
}

---@type boolean
local transparency = context.repo.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.search
local M = {
  name = "ghc_statusline_search",
}

M.color = {
  flag = {
    fg = "white",
    bg = transparency and "none" or "statusline_bg",
  },
  flag_enabled = {
    fg = "black",
    bg = "baby_pink",
  },
}

function M.condition()
  local filetype = vim.bo.filetype
  return filetype == "TelescopePrompt"
end

function M.renderer()
  ---@type boolean
  local enable_regex = context.repo.flag_enable_regex:get_snapshot()

  ---@type boolean
  local enable_case_sensitive = context.repo.flag_case_sensitive:get_snapshot()

  local color_enable_regex = enable_regex and "%#" .. M.name .. "_flag_enabled#" or "%#" .. M.name .. "_flag#"
  local color_enable_ignore_case = enable_case_sensitive and "%#" .. M.name .. "_flag#" or "%#" .. M.name .. "_flag_enabled#"
  local text_enable_regex = " r "
  local text_enable_ignore_case = " i "

  return color_enable_regex .. text_enable_regex .. color_enable_ignore_case .. text_enable_ignore_case
end

return M
