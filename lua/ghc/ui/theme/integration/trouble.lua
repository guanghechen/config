---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    TroubleCode = { fg = c.white },
    TroubleCount = { fg = c.pink },
    TroubleError = { fg = c.red },
    TroubleFile = { fg = c.yellow },
    TroubleFoldIcon = { link = "Folded" },
    TroubleHint = { fg = c.orange },
    TroubleIndent = { link = "Comment" },
    TroubleInformation = { fg = c.white },
    TroubleLocation = { fg = c.red },
    TroubleNormal = { fg = c.white },
    TroublePreview = { fg = c.red },
    TroubleSignError = { link = "DiagnosticError" },
    TroubleSignHint = { link = "DiagnosticHint" },
    TroubleSignInformation = { fg = c.white },
    TroubleSignOther = { link = "DiagnosticNormal" },
    TroubleSignWarning = { link = "DiagnosticWarn" },
    TroubleSource = { fg = c.cyan },
    TroubleText = { fg = c.white },
    TroubleTextError = { fg = c.white },
    TroubleTextHint = { fg = c.white },
    TroubleTextInformation = { fg = c.white },
    TroubleTextWarning = { fg = c.white },
    TroubleWarning = { fg = c.orange },
  }
end

return gen_hlgroup
