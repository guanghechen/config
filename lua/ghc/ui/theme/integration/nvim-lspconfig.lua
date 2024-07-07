---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local m = params.scheme.mode ---@type fml.enums.theme.Mode
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
    ["@event"] = { fg = c.base08 },
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
    ["@modifier"] = { fg = c.base08 },
    ["@regexp"] = { fg = c.base0F },
    DiagnosticHint = { fg = c.purple },
    DiagnosticError = { fg = c.red },
    DiagnosticInfo = { fg = c.green },
    DiagnosticWarn = { fg = c.yellow },
    LspInlayHint = { bg = fml.color.change_hex_lightness(c.black2, m == "darken" and 0 or 3), fg = c.light_grey },
    LspReferenceRead = { fg = c.darker_black, bg = c.white },
    LspReferenceText = { fg = c.darker_black, bg = c.white },
    LspReferenceWrite = { fg = c.darker_black, bg = c.white },
    LspSignatureActiveParameter = { fg = c.black, bg = c.green },
    RenamerBorder = { fg = c.red },
    RenamerTitle = { fg = c.black, bg = c.red },
  }
end

return gen_hlgroup
