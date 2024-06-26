---@class ghc.ui.hlconfig.IGenHighlightConfigMapParams
---@field public transparency           boolean

---@param params                        ghc.ui.hlconfig.IGenHighlightConfigMapParams
---@return table<string, fml.types.ui.theme.IHighlightConfig>
local function gen_hlconfig_map(params)
  local transparency = params.transparency ---@type boolean

  ---@type table<string, fml.types.ui.theme.IHighlightConfig>
  local hlconfig_map = {
    ---override
    CursorLine = { bg = "one_bg2" },
    Visual = { bg = "light_grey" },

    ---flash
    FlashBackdrop = { fg = "grey_fg", bg = "none", italic = true },
    FlashCursor = { fg = "red", bg = transparency and "none" or "grey" },
    FlashLabel = { fg = "white", bg = transparency and "none" or "grey" },
    FlashMatch = { fg = "cyan", bg = transparency and "none" or "grey" },

    ---ghc-replace
    GhcReplaceFilepath = { fg = "blue", bg = "none" },
    GhcReplaceFlag = { fg = "white", bg = "grey" },
    GhcReplaceFlagEnabled = { fg = "black", bg = "baby_pink" },
    GhcReplaceFence = { fg = "grey", bg = "none" },
    GhcReplaceInvisible = { fg = "none", bg = "none" },
    GhcReplaceOptName = { fg = "blue", bg = "none", bold = true },
    GhcReplaceOptReplacePattern = { fg = "diff_add_hl", bg = "none" },
    GhcReplaceOptSearchPattern = { fg = "diff_delete_hl", bg = "none" },
    GhcReplaceOptValue = { fg = "yellow", bg = "none" },
    GhcReplaceTextAdded = { fg = "diff_add_hl", bg = "none" },
    GhcReplaceTextDeleted = { fg = "diff_delete_hl", strikethrough = true },
    GhcReplaceUsage = { fg = "grey_fg2", bg = "none" },

    ---trouble
    TroubleCount = { fg = "pink" },
    TroubleCode = { fg = "white" },
    TroubleWarning = { fg = "orange" },
    TroubleSignWarning = { link = "DiagnosticWarn" },
    TroubleTextWarning = { fg = "white" },
    TroublePreview = { fg = "red" },
    TroubleSource = { fg = "cyan" },
    TroubleSignHint = { link = "DiagnosticHint" },
    TroubleTextHint = { fg = "white" },
    TroubleHint = { fg = "orange" },
    TroubleSignOther = { link = "DiagnosticNormal" },
    TroubleSignInformation = { fg = "white" },
    TroubleTextInformation = { fg = "white" },
    TroubleInformation = { fg = "white" },
    TroubleError = { fg = "red" },
    TroubleTextError = { fg = "white" },
    TroubleSignError = { link = "DiagnosticError" },
    TroubleText = { fg = "white" },
    TroubleFile = { fg = "yellow" },
    TroubleFoldIcon = { link = "Folded" },
    TroubleNormal = { fg = "white" },
    TroubleLocation = { fg = "red" },
    TroubleIndent = { link = "Comment" },

    ---vim-notify
    NotifyERRORBorder = { fg = "red" },
    NotifyERRORIcon = { fg = "red" },
    NotifyERRORTitle = { fg = "red" },
    NotifyWARNBorder = { fg = "orange" },
    NotifyWARNIcon = { fg = "orange" },
    NotifyWARNTitle = { fg = "orange" },
    NotifyINFOBorder = { fg = "green" },
    NotifyINFOIcon = { fg = "green" },
    NotifyINFOTitle = { fg = "green" },
    NotifyDEBUGBorder = { fg = "grey" },
    NotifyDEBUGIcon = { fg = "grey" },
    NotifyDEBUGTitle = { fg = "grey" },
    NotifyTRACEBorder = { fg = "purple" },
    NotifyTRACEIcon = { fg = "purple" },
    NotifyTRACETitle = { fg = "purple" },
  }

  return hlconfig_map
end

return gen_hlconfig_map
