local session = require("ghc.context.session")

local fn_toggle_search_scope = fml.G.register_anonymous_fn(function()
  local next_scope = session.get_search_scope_carousel_next() ---@type ghc.enums.context.SearchScope
  session.search_scope:next(next_scope)
end) or ""

local fn_toggle_search_mode = fml.G.register_anonymous_fn(function()
  local mode = session.search_mode:snapshot() ---@type ghc.enums.context.SearchMode
  local next_mode = mode == "replace" and "search" or "replace" ---@type ghc.enums.context.SearchMode
  session.search_mode:next(next_mode)
end) or ""

local fn_toggle_search_flag_regex = fml.G.register_anonymous_fn(function()
  local flag = session.search_flag_regex:snapshot() ---@type boolean
  session.search_flag_regex:next(not flag)
end) or ""

local fn_toggle_search_flag_case_sensitive = fml.G.register_anonymous_fn(function()
  local flag = session.search_flag_case_sensitive:snapshot() ---@type boolean
  session.search_flag_case_sensitive:next(not flag)
end) or ""

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "search_files",
  render = function()
    local mode = ghc.context.session.search_mode:snapshot() ---@type ghc.enums.context.SearchMode
    local flag_regex_enabled = ghc.context.session.search_flag_regex:snapshot() ---@type boolean
    local flag_case_sensitive_enabled = ghc.context.session.search_flag_case_sensitive:snapshot() ---@type boolean
    local flag_replace = mode == "replace" ---@type boolean

    local text_scope = " " .. ghc.context.session.search_scope:snapshot() .. " " ---@type string
    local text_flag_replace = " " .. fml.ui.icons.symbols.flag_replace .. " " ---@type string
    local text_flag_regex = " " .. fml.ui.icons.symbols.flag_regex .. " " ---@type string
    local text_flag_case_sensitive = " " .. fml.ui.icons.symbols.flag_case_sensitive .. " " ---@type string

    local hl_text_scope = fml.nvimbar.txt(text_scope, "f_sl_flag_scope") ---@type string
    ---@type string
    local hl_text_mode = fml.nvimbar.txt(text_flag_replace, flag_replace and "f_sl_flag_enabled" or "f_sl_flag")
    ---@type string
    local hl_text_flag_regex =
      fml.nvimbar.txt(text_flag_regex, flag_regex_enabled and "f_sl_flag_enabled" or "f_sl_flag")
    ---@type string
    local hl_text_case_sensitive =
      fml.nvimbar.txt(text_flag_case_sensitive, flag_case_sensitive_enabled and "f_sl_flag_enabled" or "f_sl_flag")

    local text_hl = fml.nvimbar.btn(hl_text_scope, fn_toggle_search_scope)
      .. fml.nvimbar.btn(hl_text_mode, fn_toggle_search_mode)
      .. fml.nvimbar.btn(hl_text_flag_regex, fn_toggle_search_flag_regex)
      .. fml.nvimbar.btn(hl_text_case_sensitive, fn_toggle_search_flag_case_sensitive)
    local width = vim.fn.strwidth(text_scope)
      + vim.fn.strwidth(text_flag_replace)
      + vim.fn.strwidth(text_flag_regex)
      + vim.fn.strwidth(text_flag_case_sensitive)
    return text_hl, width
  end,
}

return M
