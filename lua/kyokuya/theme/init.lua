local util_reporter = require("guanghechen.util.reporter")
local Highlighter = require("kyokuya.theme.highlighter")

local current_nsnr = 0 ---@type integer
local current_scheme = "darken" ---@type kyokuya.theme.palette.IPaletteScheme
local highlighter_map = { ---@type table<string, kyokuya.theme.Highlighter>
  [current_scheme] = Highlighter.new_with_integrations({
    palette = require("kyokuya.theme.palette." .. current_scheme),
  }),
}

---@class kyokuya.theme
local M = {}

---@param scheme kyokuya.theme.palette.IPaletteScheme
---@return kyokuya.theme.Highlighter
function M.get_highlighter(scheme)
  local highlighter = highlighter_map[scheme]
  if highlighter == nil then
    local present, palette = pcall(require, "kyokuya.theme.palette." .. scheme)
    if not present then
      util_reporter.error({
        from = "kyokuya.theme",
        subject = "toggle_theme",
        message = "Cannot find palette",
        details = { scheme = scheme },
      })
      highlighter = highlighter_map[current_scheme]
    else
      highlighter = Highlighter.new_with_integrations({ palette = palette })
      highlighter_map[scheme] = highlighter
    end
  end
  return highlighter
end

---@param scheme kyokuya.theme.palette.IPaletteScheme
---@param nsnr integer|nil
---@return kyokuya.theme.Highlighter
function M.apply(scheme, nsnr)
  local highlighter = M.get_highlighter(scheme)
  if current_scheme ~= scheme or current_nsnr ~= nil then
    current_scheme = scheme
    current_nsnr = nsnr or current_nsnr
    highlighter:apply(current_nsnr)
  end
  return highlighter
end

return M
