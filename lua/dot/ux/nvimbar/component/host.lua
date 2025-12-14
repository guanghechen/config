local txt = ark.nvim.txt

---@class dot.ux.nvimbar.component.host
local M = {}

---@param position                      dot.ux.nvimbar.PositionEnum
---@return dot.ux.nvimbar.IRawComponent
function M.username(position)
  local hln_text = position .. "_host_username_text" ---@type string
  local hln_sep = position .. "_host_username_sep" ---@type string

  local text_with_icon = " " .. dot.icon.os.current .. " " .. ark.env.USERNAME ---@type string
  local text_icon_only = dot.icon.os.current .. " " ---@type string

  ---@type dot.ux.nvimbar.IRawComponent
  local component = {
    name = "host:username",
    atomic = true,
    render = function()
      local show_username = dot.context.theme.username:snapshot() ---@type boolean
      if not show_username then
        local text = text_icon_only ---@type string
        local hl_text = txt(text, hln_text) ---@type string
        return text, hl_text, true
      end

      local text = text_with_icon ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      text = text .. dot.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(dot.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
