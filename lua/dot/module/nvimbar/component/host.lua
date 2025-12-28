local txt = ark.vim.fn.txt

---@class dot.module.nvimbar.component.host
local M = {}

---@param position                      ark.e.NvimbarPositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.username(position)
  local hln_text = position .. "_host_username_text" ---@type string
  local hln_sep = position .. "_host_username_sep" ---@type string

  local text_with_icon = " " .. ark.icon.os.current .. " " .. ark.env.USERNAME ---@type string
  local text_icon_only = ark.icon.os.current .. " " ---@type string

  ---@type dot.module.nvimbar.IRawComponent
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

      text = text .. ark.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(ark.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
