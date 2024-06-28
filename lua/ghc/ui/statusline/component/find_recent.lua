---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "find_recent",
  condition = function()
    local filetype = vim.bo.filetype
    if filetype ~= "TelescopePrompt" then
      return false
    end

    local buftype_extra = ghc.context.session.buftype_extra:get_snapshot() ---@type guanghechen.core.types.enum.BUFTYPE_EXTRA
    return buftype_extra == "find_recent"
  end,
  render = function()
    local text = " " .. ghc.context.session.find_recent_scope:get_snapshot() .. " "
    return fml.nvimbar.add_highlight(text, "f_sl_flag_scope")
  end
}

return M
