---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    DapUIBreakPointsCurrentLine = { fg = c.green, bold = true },
    DapUIBreakpointsDisabledLine = { fg = c.grey },
    DapUIBreakpointsInfo = { fg = c.green },
    DapUIBreakpointsPath = { fg = c.aqua },
    DapUIDecoration = { fg = c.aqua },
    DapUIFloatBorder = { fg = c.aqua },
    DapUILineNumber = { fg = c.aqua },
    DapUIModifiedValue = { fg = c.orange },
    DapUIPlayPause = { fg = c.green },
    DapUIPlayPauseNC = { fg = c.green },
    DapUIRestart = { fg = c.green },
    DapUIRestartNC = { fg = c.green },
    DapUISource = { fg = c.lavender },
    DapUIStepBack = { fg = c.blue },
    DapUIStepBackNC = { fg = c.blue },
    DapUIStepInto = { fg = c.blue },
    DapUIStepIntoNC = { fg = c.blue },
    DapUIStepOut = { fg = c.blue },
    DapUIStepOutNC = { fg = c.blue },
    DapUIStepOver = { fg = c.blue },
    DapUIStepOverNC = { fg = c.blue },
    DapUIStop = { fg = c.red },
    DapUIStopNC = { fg = c.red },
    DapUIStoppedThread = { fg = c.aqua },
    DapUIThread = { fg = c.green },
    DAPUIType = { fg = c.neutral_purple },
    DapUIUnavailable = { fg = c.grey },
    DapUIUnavailableNC = { fg = c.grey },
    DAPUIValue = { fg = c.aqua },
    DAPUIVariable = { fg = c.fg0 },
    DapUIWatchesEmpty = { fg = c.orange },
    DapUIWatchesError = { fg = c.orange },
    DapUIWatchesValue = { fg = c.green },
    DAPUIScope = { fg = c.aqua },
  }
end

return gen_hlgroup_map
