local txt = eve.nvim.txt

---@class eve.ux.nvimbar.component.devmode
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.devmode(position)
  local hln_devmode = position .. "_devmode_text" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "devmode:devmode",
    atomic = true,
    condition = function()
      local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
      return devmode
    end,
    render = function()
      local text = "  devmode " ---@type string
      local hl_text = txt(text, hln_devmode) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.render_count(position)
  local hln_text = position .. "_devmode_render_count_text" ---@type string
  local hln_sep = position .. "_devmode_render_count_sep" ---@type string
  local count = 0 ---@type integer

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "debug_render_count",
    atomic = true,
    condition = function()
      local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
      return devmode
    end,
    render = function()
      count = count + 1

      local text = " " .. eve.string.pad_start(tostring(count % 100000), 5, "0") ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      text = eve.icon.symbols.sep_left .. text ---@type string
      hl_text = txt(eve.icon.symbols.sep_left, hln_sep) .. hl_text ---@type string

      text = text .. eve.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(eve.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
