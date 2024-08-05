local session = require("ghc.context.session")

local fn_toggle_find_scope = fml.G.register_anonymous_fn(function()
  local next_scope = session.get_find_scope_carousel_next() ---@type ghc.enums.context.FindScope
  session.find_scope:next(next_scope)
end) or ""

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "find_files",
  render = function()
    local text = " " .. ghc.context.session.find_scope:snapshot() .. " " ---@type string
    local hl_text_inner = fml.nvimbar.txt(text, "f_sl_flag_scope") ---@type string
    local hl_text = fml.nvimbar.btn(hl_text_inner, fn_toggle_find_scope)
    local width = vim.fn.strwidth(text) ---@type integer
    return hl_text, width
  end,
}

return M
