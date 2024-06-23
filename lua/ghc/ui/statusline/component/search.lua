local context_session = require("ghc.core.context.session")

---@type boolean
local transparency = fml.context.shared.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.search
local M = {
  name = "ghc_statusline_search",
}

M.color = {
  flag = {
    fg = "white",
    bg = transparency and "none" or "grey",
  },
  flag_enabled = {
    fg = "black",
    bg = "nord_blue",
  },
  flag_scope = {
    fg = "black",
    bg = "baby_pink",
  },
}

---@return boolean
function M.condition()
  local filetype = vim.bo.filetype
  ---@type ghc.core.types.enum.BUFTYPE_EXTRA
  local buftype_extra = context_session.buftype_extra:get_snapshot()
  return filetype == "TelescopePrompt" and buftype_extra == "search"
end

function M.renderer()
  ---@type ghc.core.types.enum.SEARCH_SCOPE
  local scope = context_session.search_scope:get_snapshot()

  ---@type boolean
  local enable_regex = context_session.search_enable_regex:get_snapshot()

  ---@type boolean
  local enable_case_sensitive = context_session.search_enable_case_sensitive:get_snapshot()

  local color_scope = "%#" .. M.name .. "_flag_scope#"
  local color_enable_regex = enable_regex and "%#" .. M.name .. "_flag_enabled#" or "%#" .. M.name .. "_flag#"
  local color_enable_case_sensitive = enable_case_sensitive and "%#" .. M.name .. "_flag_enabled#" or "%#" .. M.name .. "_flag#"
  local text_scope = " " .. scope .. " "
  local text_enable_regex = " 󰑑 "
  local text_enable_ignore_case = "  "

  return color_scope .. text_scope .. color_enable_regex .. text_enable_regex .. color_enable_case_sensitive .. text_enable_ignore_case
end

return M
