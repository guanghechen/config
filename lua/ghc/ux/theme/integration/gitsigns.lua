---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    DiffAdd = { fg = c.blue },
    DiffAdded = { fg = c.green },
    DiffChange = { fg = c.grey },
    DiffChangeDelete = { fg = c.red },
    DiffDelete = { fg = c.red },
    DiffModified = { fg = c.yellow },
    diffNewFile = { fg = c.blue },
    diffOldFile = { fg = c.orange },
    DiffRemoved = { fg = c.red },
    DiffText = { fg = c.fg0, bg = c.bg1 },
    gitcommitBranch = { fg = c.orange, bold = true },
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
