---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "find_file",
  condition = function()
    local filetype = vim.bo.filetype
    if filetype ~= "TelescopePrompt" then
      return false
    end

    local buftype_extra = ghc.context.session.buftype_extra:get_snapshot() ---@type guanghechen.core.types.enum.BUFTYPE_EXTRA
    return buftype_extra == "find_file"
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
    {
      hlname = function()
        local enabled = ghc.context.replace.flag_regex:get_snapshot() ---@type boolean
        return enabled and "f_sl_flag_enabled" or "f_sl_flag"
      end,
      text = function()
        return " " .. fml.ui.icons.flag.Regex .. " "
      end,
    },
    {
      hlname = function()
        local enabled = ghc.context.replace.flag_case_sensitive:get_snapshot() ---@type boolean
        return enabled and "f_sl_flag_enabled" or "f_sl_flag"
      end,
      text = function()
        return " " .. fml.ui.icons.flag.CaseSensitive .. " "
      end,
    },
  },
}

return M
