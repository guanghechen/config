---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "filetype",
  will_change = function(context, prev_context)
    return prev_context == nil or context.filetype ~= prev_context.filetype
  end,
  condition = function(context)
    return context.filetype and #context.filetype > 0
  end,
  render = function(context)
    local text = context.fileicon .. " " .. context.filetype ---@type string
    return fml.nvimbar.txt(text, "f_sl_text")
  end
}

return M
