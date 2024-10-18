---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    DapUIBreakPointsCurrentLine = { fg = c.green, bold = true },
    DapUIBreakpointsDisabledLine = { fg = c.grey },
    DapUIBreakpointsInfo = { fg = c.green },
    DapUIBreakpointsPath = { fg = c.cyan },
    DapUIDecoration = { fg = c.cyan },
    DapUIFloatBorder = { fg = c.cyan },
    DapUILineNumber = { fg = c.cyan },
    DapUIModifiedValue = { fg = c.pink },
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
    DapUIStoppedThread = { fg = c.cyan },
    DapUIThread = { fg = c.green },
    DAPUIType = { fg = c.dark_purple },
    DapUIUnavailable = { fg = c.grey },
    DapUIUnavailableNC = { fg = c.grey },
    DAPUIValue = { fg = c.cyan },
    DAPUIVariable = { fg = c.fg0 },
    DapUIWatchesEmpty = { fg = c.pink },
    DapUIWatchesError = { fg = c.pink },
    DapUIWatchesValue = { fg = c.green },
    DAPUIScope = { fg = c.cyan },
  }
end

return gen_hlgroup_map
