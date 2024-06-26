return string.dump(function()
  local hls = {
    GhcReplaceOptReplacePattern = { fg = "#A0EFA0", bg = "none" },
    GhcReplaceOptSearchPattern = { fg = "#FFC0C0", bg = "none" },
    GhcReplaceOptValue = { fg = "#e7c787", bg = "none" },
    GhcReplaceTextAdded = { fg = "#A0EFA0", bg = "none" },
    GhcReplaceTextDeleted = { fg = "#FFC0C0", strikethrough = true },
    GhcReplaceUsage = { fg = "#6f737b", bg = "none" },
    GhcReplaceFilepath = { fg = "#61afef", bg = "none" },
    GhcReplaceFlag = { fg = "#abb2bf", bg = "grey" },
    GhcReplaceFlagEnabled = { fg = "#1e222a", bg = "#DE8C92" },
    GhcReplaceFence = { fg = "#42464e", bg = "none" },
    GhcReplaceInvisible = { fg = "none", bg = "none" },
    GhcReplaceOptName = { bg = "none", fg = "#61afef", bold = true },
  }
  for k, v in pairs(hls) do
    vim.api.nvim_set_hl(0, k, v)
  end
end, true)
