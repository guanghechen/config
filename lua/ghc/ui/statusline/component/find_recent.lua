local context_config = require("ghc.core.context.config")
local context_session = require("ghc.core.context.session")

---@type boolean
local transparency = context_config.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.find_recent
local M = {
  name = "ghc_statusline_find_recent",
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
  return filetype == "TelescopePrompt" and buftype_extra == "find_recent"
end

function M.renderer()
  ---@type ghc.core.types.enum.SEARCH_SCOPE
  local scope = context_session.find_recent_scope:get_snapshot()
  local color_scope = "%#" .. M.name .. "_flag_scope#"
  local text_scope = " " .. scope .. " "
  return color_scope .. text_scope
end

return M
