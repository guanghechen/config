local txt = std.nvim.txt

---@class ux.nvimbar.component.host
local M = {}

---@param position                      ux.nvimbar.PositionEnum
---@return ux.nvimbar.IRawComponent
function M.username(position)
  local hln_text = position .. "_host_username_text" ---@type string
  local hln_sep = position .. "_host_username_sep" ---@type string

  local text_with_icon = " " .. std.icon.os.current .. " " .. dot.env.USERNAME ---@type string
  local text_icon_only = std.icon.os.current .. " " ---@type string

  ---@type ux.nvimbar.IRawComponent
  local component = {
    name = "host:username",
    atomic = true,
    render = function()
      local show_username = eve.context.theme.username:snapshot() ---@type boolean
      if not show_username then
        local text = text_icon_only ---@type string
        local hl_text = txt(text, hln_text) ---@type string
        return text, hl_text, true
      end

      local text = text_with_icon ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      text = text .. std.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(std.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
