local txt = eve.nvim.txt

---@class eve.ux.nvimbar.component.host
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.username(position)
  local hln_text = position .. "_host_username_text" ---@type string
  local hln_sep = position .. "_host_username_sep" ---@type string

  local text_with_icon = " " .. eve.icon.os.current .. " " .. std.env.USERNAME ---@type string
  local text_icon_only = eve.icon.os.current .. " " ---@type string

  local invalid = false ---@type boolean
  eve.fn.observe({ eve.context.theme.username }, function()
    invalid = true
  end, true)

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "host:username",
    atomic = true,
    will_change = function()
      return invalid
    end,
    render = function()
      invalid = false
      local show_username = eve.context.theme.username:snapshot() ---@type boolean
      if not show_username then
        local text = text_icon_only ---@type string
        local hl_text = txt(text, hln_text) ---@type string
        return text, hl_text, true
      end

      local text = text_with_icon ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      text = text .. eve.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(eve.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
