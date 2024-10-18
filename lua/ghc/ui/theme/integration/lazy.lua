---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local m = params.scheme.mode ---@type fml.enums.theme.Mode
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    LazyButton = { bg = c.bg1, fg = eve.color.change_hex_lightness(c.grey, m == "darken" and 10 or -20) },
    LazyCommit = { fg = c.green },
    LazyCommitIssue = { fg = c.pink },
    LazyDir = { fg = c.fg0 },
    LazyH1 = { bg = c.green, fg = c.black },
    LazyH2 = { fg = c.red, bold = true, underline = true },
    LazyNoCond = { fg = c.red },
    LazyOperator = { fg = c.fg0 },
    LazyProgressDone = { fg = c.green },
    LazyReasonCmd = { fg = c.yellow },
    LazyReasonEvent = { fg = c.yellow },
    LazyReasonFt = { fg = c.purple },
    LazyReasonImport = { fg = c.fg0 },
    LazyReasonKeys = { fg = c.dark_cyan },
    LazyReasonPlugin = { fg = c.red },
    LazyReasonRuntime = { fg = c.lavender },
    LazyReasonSource = { fg = c.cyan },
    LazyReasonStart = { fg = c.fg0 },
    LazySpecial = { fg = c.blue },
    LazyTaskOutput = { fg = c.fg0 },
    LazyUrl = { fg = c.fg0 },
    LazyValue = { fg = c.dark_cyan },
  }
end

return gen_hlgroup_map
