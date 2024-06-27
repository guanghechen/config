---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "cwd",
  will_change = function(context, prev_context)
    return prev_context == nil or context.cwd ~= prev_context.cwd
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_text"
      end,
      text = function(context)
        local cwd_name = (context.cwd:match("([^/\\]+)[/\\]*$") or context.cwd)
        local text = "󰉋 " .. cwd_name .. " "
        return text
      end,
    },
  },
}

return M
