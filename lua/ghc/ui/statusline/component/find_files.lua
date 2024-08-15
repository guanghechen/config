local session = require("ghc.context.session")

---@type string
local fn_toggle_scope = fml.G.register_anonymous_fn(function()
  local next_scope = session.get_find_scope_carousel_next() ---@type ghc.enums.context.FindScope
  session.find_scope:next(next_scope)
end) or ""

---@type string
local fn_toggle_flag_case_sensitive = fml.G.register_anonymous_fn(function()
  local flag = session.find_flag_case_sensitive:snapshot() ---@type boolean
  session.find_flag_case_sensitive:next(not flag)
end) or ""

---@type string
local fn_toggle_flag_gitignore = fml.G.register_anonymous_fn(function()
  local flag = session.find_flag_gitignore:snapshot() ---@type boolean
  session.find_flag_gitignore:next(not flag)
end) or ""

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "find_files",
  render = function()
    local flag_case_sensitive_enabled = session.find_flag_case_sensitive:snapshot() ---@type boolean
    local flag_gitignore_enabled = session.find_flag_gitignore:snapshot() ---@type boolean

    local text_scope = " " .. session.find_scope:snapshot() .. " " ---@type string
    local text_flag_case_sensitive = " " .. fml.ui.icons.symbols.flag_case_sensitive .. " " ---@type string
    local text_flag_gitignore = " " .. fml.ui.icons.symbols.flag_gitignore .. " " ---@type string

    local hl_text_scope = fml.nvimbar.txt(text_scope, "f_sl_flag_scope") ---@type string
    ---@type string
    local hl_text_flag_case_sensitive =
      fml.nvimbar.txt(text_flag_case_sensitive, flag_case_sensitive_enabled and "f_sl_flag_enabled" or "f_sl_flag")
    local hl_text_flag_gitignore =
      fml.nvimbar.txt(text_flag_gitignore, flag_gitignore_enabled and "f_sl_flag_enabled" or "f_sl_flag")

    local hl_text = fml.nvimbar.btn(hl_text_scope, fn_toggle_scope)
      .. fml.nvimbar.btn(hl_text_flag_gitignore, fn_toggle_flag_gitignore)
      .. fml.nvimbar.btn(hl_text_flag_case_sensitive, fn_toggle_flag_case_sensitive)
    local width = vim.fn.strwidth(text_scope)
      + vim.fn.strwidth(text_flag_case_sensitive)
      + vim.fn.strwidth(text_flag_gitignore)
    return hl_text, width
  end,
}

return M
