local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---@class era.m.nvimbar.component.picker
local M = {}

---@param position                      stl.e.NvimbarPositionEnum
---@param flags                         era.m.picker.result.IFlagItem[]
---@param flags_start_index             integer
---@return era.m.nvimbar.IRawComponent
function M.result_flags(position, flags, flags_start_index)
  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "picker:result_flags",
    atomic = true,
    condition = function()
      return #flags > 0
    end,
    render = function()
      local text = "" ---@type string
      local hl_text = "" ---@type string
      local index = flags_start_index ---@type integer
      for _, item in ipairs(flags) do
        if not item.disabled() then
          local digit = stl.icon.todigit_supscript(index) ---@type string
          local flag_text, flag_hln = item:snapshot() ---@type string, string
          local piece_text = " " .. flag_text .. digit ---@type string
          local piece_hln = string.format("%s_%s", position, flag_hln) ---@type string

          text = text .. piece_text ---@type string
          hl_text = hl_text .. btn(txt(piece_text, piece_hln), item.callback) ---@type string
        end
        index = index + 1 ---@type integer
      end
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@param result_lnum                   stl.c.Observable
---@param result_total                  stl.c.Observable
---@return era.m.nvimbar.IRawComponent
function M.result_pos(position, result_lnum, result_total)
  local hln_text = position .. "_picker_result_pos_text" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "picker:result_pos",
    atomic = true,
    render = function()
      local lnum = result_lnum:snapshot() ---@type number
      local total = result_total:snapshot() ---@type number

      local text = string.format("%s / %s", lnum, total) ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

return M
