---@class era.action.toggle.maximize
local M = {}

---@return nil
function M.maximize()
  local winnr = dot.state.status.get_winnr_command() ---@type integer|nil
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local original_normal = dot.state.maximized.get_original_normal() ---@type dot.state.maximized.IOriginalNormalWindow|nil
  if original_normal ~= nil and original_normal.float_winnr == winnr then
    require("era.action.toggle.maximize.normal").close()
    return
  end

  if stl.nvim.win.is_float(winnr) then
    require("era.action.toggle.maximize.float").maximize(winnr)
  else
    require("era.action.toggle.maximize.normal").maximize(winnr)
  end
end

return M
