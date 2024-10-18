---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup>
local function gen_hlgroup_map(params)
  local m = params.scheme.mode ---@type fml.enums.theme.Mode
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette

  return {
    ["@event"] = { fg = c.red },
    ["@lsp.type.class"] = { link = "Structure" },
    ["@lsp.type.decorator"] = { link = "Function" },
    ["@lsp.type.enum"] = { link = "Type" },
    ["@lsp.type.enumMember"] = { link = "Constant" },
    ["@lsp.type.function"] = { link = "@function" },
    ["@lsp.type.interface"] = { link = "Structure" },
    ["@lsp.type.macro"] = { link = "@macro" },
    ["@lsp.type.method"] = { link = "@function.method" },
    ["@lsp.type.namespace"] = { link = "@module" },
    ["@lsp.type.parameter"] = { link = "@variable.parameter" },
    ["@lsp.type.property"] = { link = "@property" },
    ["@lsp.type.struct"] = { link = "Structure" },
    ["@lsp.type.type"] = { link = "@type" },
    ["@lsp.type.typeParamater"] = { link = "TypeDef" },
    ["@lsp.type.variable"] = { link = "@variable" },
    ["@modifier"] = { fg = c.red },
    ["@regexp"] = { fg = c.dark_red },
    DiagnosticHint = { fg = c.purple },
    DiagnosticError = { fg = c.red },
    DiagnosticInfo = { fg = c.green },
    DiagnosticWarn = { fg = c.yellow },
    LspInlayHint = { bg = eve.color.change_hex_lightness(c.black, m == "darken" and 0 or 3), fg = c.grey },
    LspReferenceRead = { fg = c.dark_black, bg = c.white },
    LspReferenceText = { fg = c.dark_black, bg = c.white },
    LspReferenceWrite = { fg = c.dark_black, bg = c.white },
    LspSignatureActiveParameter = { fg = c.black, bg = c.green },
    RenamerBorder = { fg = c.red },
    RenamerTitle = { fg = c.black, bg = c.red },
  }
end

return gen_hlgroup_map
