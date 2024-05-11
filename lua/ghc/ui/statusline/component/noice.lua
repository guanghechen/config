local context = {
  repo = require("ghc.core.context.repo"),
}

---@type boolean
local transparency = context.repo.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.noice
local M = {
  name = "ghc_statusline_noice",
}

M.color = {
  text_command = {
    fg = "white",
    bg = transparency and "none" or "statusline_bg",
  },
  text_mode = {
    fg = "yellow",
    bg = transparency and "none" or "statusline_bg",
  },
}

function M.condition()
  local ok, _ = pcall(require, "noice")
  return ok
end

function M.renderer()
  local status = require("noice").api.status
  local color_text_command = "%#" .. M.name .. "_text_comand#"
  local color_text_mode = "%#" .. M.name .. "_text_mode#"

  local pieces = {}

  -- status.message

  if status.command.has() then
    local text_command = status.command.get()
    table.insert(pieces, color_text_command .. text_command)
  end

  if status.mode.has() then
    local text_mode = status.mode.get()
    table.insert(pieces, color_text_mode .. text_mode)
  end

  -- status.search
  local result = table.concat(pieces, " ")
  return #result > 0 and result .. " " or ""
end

return M
