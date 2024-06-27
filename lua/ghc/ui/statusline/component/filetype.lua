---@type fml.types.core.statusline.IRawComponent
local M = {
  name = "filetype",
  will_change = function(context, prev_context)
    return prev_context == nil or context.filetype ~= prev_context.filetype
  end,
  condition = function(context)
    return context.filetype and #context.filetype > 0
  end,
  pieces = {
    {
      hlname = function()
        return "f_sl_text"
      end,
      text = function(context)
        return context.fileicon .. " " .. context.filetype
      end,
    },
  },
}

return M
