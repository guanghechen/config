---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    DiffAdd = { fg = c.blue },
    DiffAdded = { fg = c.green },
    DiffChange = { fg = c.light_grey },
    DiffChangeDelete = { fg = c.red },
    DiffDelete = { fg = c.red },
    DiffModified = { fg = c.orange },
    diffNewFile = { fg = c.blue },
    diffOldFile = { fg = c.baby_pink },
    DiffRemoved = { fg = c.red },
    DiffText = { fg = c.white, bg = c.black2 },
    gitcommitBranch = { fg = c.base09, bold = true },
    gitcommitComment = { fg = c.base03 },
    gitcommitDiscarded = { fg = c.base03 },
    gitcommitDiscardedFile = { fg = c.base08, bold = true },
    gitcommitDiscardedType = { fg = c.base0D },
    gitcommitHeader = { fg = c.base0E },
    gitcommitOverflow = { fg = c.base08 },
    gitcommitSelected = { fg = c.base03 },
    gitcommitSelectedFile = { fg = c.base0B, bold = true },
    gitcommitSelectedType = { fg = c.base0D },
    gitcommitSummary = { fg = c.base0B },
    gitcommitUnmergedFile = { fg = c.base08, bold = true },
    gitcommitUnmergedType = { fg = c.base0D },
    gitcommitUntracked = { fg = c.base03 },
    gitcommitUntrackedFile = { fg = c.base0A },
  }
end

return gen_hlgroup
