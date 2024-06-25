local context_session = require("guanghechen.core.context.session")

---@type boolean
local transparency = ghc.context.theme.transparency:get_snapshot()

--- @class guanghechen.ui.statusline.component.copilot
local M = {
  name = "ghc_statusline_copilot",
  color = {
    status_ = {
      fg = "white",
      bg = transparency and "none" or "statusline_bg",
    },
    status_Noraml = {
      fg = "blue",
      bg = transparency and "none" or "statusline_bg",
    },
    status_Warning = {
      fg = "yellow",
      bg = transparency and "none" or "statusline_bg",
    },
    status_InProgress = {
      fg = "cyan",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  if not package.loaded["copilot"] then
    return false
  end

  local enabled = context_session.flight_copilot:get_snapshot() ---@type boolean
  return enabled
end

function M.renderer()
  local status = require("copilot.api").status.data
  local color = "%#" .. M.name .. "_status_" .. status.status .. "#"
  return color .. " " .. ghc.ui.icons.cmp.copilot .. " "
end

return M
