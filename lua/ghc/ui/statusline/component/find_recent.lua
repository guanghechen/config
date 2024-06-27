---@type fml.types.core.statusline.IRawComponent
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
  pieces = {
    {
      hlname = function()
        return "f_sl_flag_scope"
      end,
      text = function()
        return " " .. ghc.context.session.find_recent_scope:get_snapshot() .. " "
      end,
    },
  },
}

return M
