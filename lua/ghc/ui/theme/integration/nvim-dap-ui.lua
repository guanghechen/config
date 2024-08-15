---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    DapUIBreakPointsCurrentLine = { fg = c.green, bold = true },
    DapUIBreakpointsDisabledLine = { fg = c.grey_fg2 },
    DapUIBreakpointsInfo = { fg = c.green },
    DapUIBreakpointsPath = { fg = c.cyan },
    DapUIDecoration = { fg = c.cyan },
    DapUIFloatBorder = { fg = c.cyan },
    DapUILineNumber = { fg = c.cyan },
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
    DapUIStoppedThread = { fg = c.cyan },
    DapUIThread = { fg = c.green },
    DAPUIType = { fg = c.darker_purple },
    DapUIUnavailable = { fg = c.grey_fg },
    DapUIUnavailableNC = { fg = c.grey_fg },
    DAPUIValue = { fg = c.cyan },
    DAPUIVariable = { fg = c.white },
    DapUIWatchesEmpty = { fg = c.baby_pink },
    DapUIWatchesError = { fg = c.baby_pink },
    DapUIWatchesValue = { fg = c.green },
    DAPUIScope = { fg = c.cyan },
  }
end

return gen_hlgroup_map
