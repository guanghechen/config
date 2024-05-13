local context = {
  repo = require("ghc.core.context.repo"),
}

---@type boolean
local transparency = context.repo.transparency:get_snapshot()

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
  local buftype_extra = context.repo.buftype_extra:get_snapshot()
  return filetype == "TelescopePrompt" and buftype_extra == "find_recent"
end

function M.renderer()
  ---@type ghc.core.types.enum.SEARCH_SCOPE
  local scope = context.repo.find_recent_scope:get_snapshot()

  -- ---@type boolean
  -- local enable_case_sensitive = context.repo.find_recent_enable_case_sensitive:get_snapshot()
  --
  local color_scope = "%#" .. M.name .. "_flag_scope#"
  -- local color_enable_case_sensitive = enable_case_sensitive and "%#" .. M.name .. "_flag_enabled#" or "%#" .. M.name .. "_flag#"
  local text_scope = " " .. scope .. " "
  -- local text_enable_ignore_case = "  "
  --
  -- return color_scope .. text_scope .. color_enable_case_sensitive .. text_enable_ignore_case
  return color_scope .. text_scope
end

return M
