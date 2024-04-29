--- @class ghc.ui.statusline.component.username
local M = {
  name = "ghc_statusline_username",
}

M.color = {
  text = {
    fg = "#FFFFFF",
    bg = "baby_pink",
  },
}

function M.condition()
  return true
end

---@param opts { is_rightest: boolean }
---@diagnostic disable-next-line: unused-local
function M.renderer_left(opts)
  local username = os.getenv("USER") or os.getenv("USERNAME") or "unknown"

  local color_text = "%#" .. M.name .. "_text#"

  local text = " " .. username .. " "
  return color_text .. text
end

return M
