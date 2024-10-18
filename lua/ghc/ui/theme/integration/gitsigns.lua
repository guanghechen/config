---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    DiffAdd = { fg = c.blue },
    DiffAdded = { fg = c.green },
    DiffChange = { fg = c.grey },
    DiffChangeDelete = { fg = c.red },
    DiffDelete = { fg = c.red },
    DiffModified = { fg = c.yellow },
    diffNewFile = { fg = c.blue },
    diffOldFile = { fg = c.pink },
    DiffRemoved = { fg = c.red },
    DiffText = { fg = c.fg0, bg = c.bg1 },
    gitcommitBranch = { fg = c.dark_yellow, bold = true },
    gitcommitComment = { fg = c.grey },
    gitcommitDiscarded = { fg = c.grey },
    gitcommitDiscardedFile = { fg = c.red, bold = true },
    gitcommitDiscardedType = { fg = c.blue },
    gitcommitHeader = { fg = c.purple },
    gitcommitOverflow = { fg = c.red },
    gitcommitSelected = { fg = c.grey },
    gitcommitSelectedFile = { fg = c.green, bold = true },
    gitcommitSelectedType = { fg = c.blue },
    gitcommitSummary = { fg = c.green },
    gitcommitUnmergedFile = { fg = c.red, bold = true },
    gitcommitUnmergedType = { fg = c.blue },
    gitcommitUntracked = { fg = c.grey },
    gitcommitUntrackedFile = { fg = c.yellow },
  }
end

return gen_hlgroup_map
