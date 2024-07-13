---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "search",
  condition = function()
    local filetype = vim.bo.filetype
    if filetype ~= "TelescopePrompt" then
      return false
    end

    local buftype_extra = ghc.context.transient.buftype_extra:snapshot() ---@type guanghechen.core.types.enum.BUFTYPE_EXTRA
    return buftype_extra == "search"
  end,
  render = function()
    local text_scope = " " .. ghc.context.session.search_scope:snapshot() .. " " ---@type string
    local text_flag_regex = " " .. fml.ui.icons.symbols.flag_regex .. " " ---@type string
    local text_flag_case_sensitive = " " .. fml.ui.icons.symbols.flag_case_sensitive .. " " ---@type string

    local flag_regex_enabled = ghc.context.session.search_flag_regex:snapshot() ---@type boolean
    local flag_case_sensitive_enabled = ghc.context.session.search_flag_case_sensitive:snapshot() ---@type boolean

    local hlname_scope = "f_sl_flag_scope"
    local hlname_flag_regex = flag_regex_enabled and "f_sl_flag_enabled" or "f_sl_flag"
    local hlname_flag_case_sensitive = flag_case_sensitive_enabled and "f_sl_flag_enabled" or "f_sl_flag"

    local text_hl = fml.nvimbar.txt(text_scope, hlname_scope)
        .. fml.nvimbar.txt(text_flag_regex, hlname_flag_regex)
        .. fml.nvimbar.txt(text_flag_case_sensitive, hlname_flag_case_sensitive)
    local width = vim.fn.strwidth(text_scope)
        + vim.fn.strwidth(text_flag_regex)
        + vim.fn.strwidth(text_flag_case_sensitive)

    return text_hl, width
  end,
}

return M
