---@param context                       t.ghc.ux.IThemeContext
---@return table<string, t.fml.ux.theme.IHlgroup>
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette

  return {
    TroubleCode = { fg = c.fg0 },
    TroubleCount = { fg = c.orange },
    TroubleError = { fg = c.red },
    TroubleFile = { fg = c.yellow },
    TroubleFoldIcon = { link = "Folded" },
    TroubleHint = { fg = c.purple },
    TroubleIndent = { link = "Comment" },
    TroubleInformation = { fg = c.fg0 },
    TroubleLocation = { fg = c.red },
    TroubleNormal = { fg = c.fg0 },
    TroublePreview = { fg = c.red },
    TroubleSignError = { link = "DiagnosticError" },
    TroubleSignHint = { link = "DiagnosticHint" },
    TroubleSignInformation = { fg = c.fg0 },
    TroubleSignOther = { link = "DiagnosticNormal" },
    TroubleSignWarning = { link = "DiagnosticWarn" },
    TroubleSource = { fg = c.aqua },
    TroubleText = { fg = c.fg0 },
    TroubleTextError = { fg = c.fg0 },
    TroubleTextHint = { fg = c.fg0 },
    TroubleTextInformation = { fg = c.fg0 },
    TroubleTextWarning = { fg = c.fg0 },
    TroubleWarning = { fg = c.yellow },
  }
end

return gen_hlgroup_map
