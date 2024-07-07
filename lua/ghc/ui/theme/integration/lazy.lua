---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local m = params.scheme.mode ---@type fml.enums.theme.Mode
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    LazyButton = { bg = c.one_bg, fg = fml.color.change_hex_lightness(c.light_grey, m == "darken" and 10 or -20) },
    LazyCommit = { fg = c.green },
    LazyCommitIssue = { fg = c.pink },
    LazyDir = { fg = c.base05 },
    LazyH1 = { bg = c.green, fg = c.black },
    LazyH2 = { fg = c.red, bold = true, underline = true },
    LazyNoCond = { fg = c.red },
    LazyOperator = { fg = c.white },
    LazyProgressDone = { fg = c.green },
    LazyReasonCmd = { fg = c.sun },
    LazyReasonEvent = { fg = c.yellow },
    LazyReasonFt = { fg = c.purple },
    LazyReasonImport = { fg = c.white },
    LazyReasonKeys = { fg = c.teal },
    LazyReasonPlugin = { fg = c.red },
    LazyReasonRuntime = { fg = c.nord_blue },
    LazyReasonSource = { fg = c.cyan },
    LazyReasonStart = { fg = c.white },
    LazySpecial = { fg = c.blue },
    LazyTaskOutput = { fg = c.white },
    LazyUrl = { fg = c.base05 },
    LazyValue = { fg = c.teal },
  }
end

return gen_hlgroup
