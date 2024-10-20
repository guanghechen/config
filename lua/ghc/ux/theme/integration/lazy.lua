---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local m = context.scheme.mode ---@type t.eve.e.ThemeMode
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    LazyButton = { bg = c.bg1, fg = eve.color.change_hex_lightness(c.grey, m == "dark" and 10 or -20) },
    LazyCommit = { fg = c.green },
    LazyCommitIssue = { fg = c.orange },
    LazyDir = { fg = c.fg0 },
    LazyH1 = { bg = c.green, fg = c.bg0_s },
    LazyH2 = { fg = c.red, bold = true, underline = true },
    LazyNoCond = { fg = c.red },
    LazyOperator = { fg = c.fg0 },
    LazyProgressDone = { fg = c.green },
    LazyReasonCmd = { fg = c.yellow },
    LazyReasonEvent = { fg = c.yellow },
    LazyReasonFt = { fg = c.purple },
    LazyReasonImport = { fg = c.fg0 },
    LazyReasonKeys = { fg = c.neutral_aqua },
    LazyReasonPlugin = { fg = c.red },
    LazyReasonRuntime = { fg = c.lavender },
    LazyReasonSource = { fg = c.aqua },
    LazyReasonStart = { fg = c.fg0 },
    LazySpecial = { fg = c.blue },
    LazyTaskOutput = { fg = c.fg0 },
    LazyUrl = { fg = c.fg0 },
    LazyValue = { fg = c.neutral_aqua },
  }
end

return gen_hlgroup_map
