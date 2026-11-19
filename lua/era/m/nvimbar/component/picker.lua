---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.picker" ---@type string

local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---@class era.m.nvimbar.component.picker
local M = {}

---Shows the flags marked with their keys: the numbered ones in ascending order, then the lettered ones as given.
---@param position                      stl.t.NvimbarPositionEnum
---@param flags                         era.view.picker.result.IFlagItem[]
---@return era.m.nvimbar.IRawComponent
function M.result_flags(position, flags)
  local ordered = vim.list_slice(flags) ---@type era.view.picker.result.IFlagItem[]
  local positions = {} ---@type table<era.view.picker.result.IFlagItem, integer>
  for index, item in ipairs(ordered) do
    positions[item] = (tonumber(item.key:sub(2)) or 10) * #ordered + index
  end
  table.sort(ordered, function(a, b)
    return positions[a] < positions[b]
  end)

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "picker:result_flags",

    condition = function()
      return #flags > 0
    end,
    refresh = function()
      local text = "" ---@type string
      local hl_text = "" ---@type string
      for _, item in ipairs(ordered) do
        if not item.disabled() then
          local mark = stl.icon.toggle_supscript(item.key) ---@type string
          local flag_text, flag_hln = item:snapshot() ---@type string, string
          local piece_text = " " .. flag_text .. mark ---@type string
          local piece_hln = string.format("%s_%s", position, flag_hln) ---@type string

          text = text .. piece_text ---@type string
          hl_text = hl_text .. btn(txt(piece_text, piece_hln), item.callback) ---@type string
        end
      end
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@param result_lnum                   stl.c.Observable
---@param result_total                  stl.c.Observable
---@return era.m.nvimbar.IRawComponent
function M.result_pos(position, result_lnum, result_total)
  local hln_text = position .. "_picker_result_pos_text" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "picker:result_pos",

    refresh = function()
      local lnum = result_lnum:snapshot() ---@type number
      local total = result_total:snapshot() ---@type number

      local text = string.format("%s / %s", lnum, total) ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@param snapshot                      era.view.picker.result.IStatusSnapshot
---@return era.m.nvimbar.IRawComponent
function M.result_status(position, snapshot)
  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "picker:result_status",

    condition = function()
      local text = snapshot()
      return type(text) == "string" and text ~= ""
    end,
    refresh = function()
      local text, hln = snapshot()
      text = string.format(" %s ", text or "")
      local hl_text = txt(text, string.format("%s_%s", position, hln or "picker_result_pos_text"))
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

return M
