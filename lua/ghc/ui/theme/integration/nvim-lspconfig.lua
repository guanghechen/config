---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors

  return {
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
    LspReferenceText = { fg = c.darker_black, bg = c.white },
    LspReferenceRead = { fg = c.darker_black, bg = c.white },
    LspReferenceWrite = { fg = c.darker_black, bg = c.white },
    DiagnosticHint = { fg = c.purple },
    DiagnosticError = { fg = c.red },
    DiagnosticWarn = { fg = c.yellow },
    DiagnosticInfo = { fg = c.green },
    LspSignatureActiveParameter = { fg = c.black, bg = c.green },
    RenamerTitle = { fg = c.black, bg = c.red },
    RenamerBorder = { fg = c.red },
    --LspInlayHint = { bg = fml.color.change_hex_lightness("black2", vim.o.bg == c.dark and 0 or 3), fg = c.light_grey },
  }
end

return gen_hlgroup
