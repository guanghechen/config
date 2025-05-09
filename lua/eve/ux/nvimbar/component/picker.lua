local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@class eve.ux.nvimbar.component.picker
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@param flags                         eve.ux.picker.IInternalFlagItem[]
---@param flags_start_index             integer
---@return eve.ux.nvimbar.IRawComponent
function M.result_flags(position, flags, flags_start_index)
  local hln_flag_boolean = position .. "_picker_result_flag_boolean" ---@type string
  local hln_flag_boolean_active = position .. "_picker_result_flag_boolean_active" ---@type string
  local hln_flag_enum = position .. "_picker_result_flag_enum" ---@type string
  local hln_flag_enum_active = position .. "_picker_result_flag_enum_active" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
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
        local digit = eve.icon.todigit_supscript(index) ---@type string
        local text_sep = index > 1 and "▏" or " " ---@type string

        local active, text_flag = item:snapshot() ---@type boolean, string
        local text_piece = string.format("%s%s%s", text_sep, text_flag, digit) ---@type string

        ---@type string
        local hln_flag = active and (item.type == "enum" and hln_flag_enum_active or hln_flag_boolean_active)
          or (item.type == "enum" and hln_flag_enum or hln_flag_boolean)
        local hl_text_piece = btn(txt(text_flag, hln_flag), item.callback_fn)

        text = text .. text_piece ---@type string
        hl_text = hl_text .. hl_text_piece ---@type string
        index = index + 1
      end
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      eve.ux.nvimbar.PositionEnum
---@param result_lnum                   eve.std.collection.Observable
---@param result_total                  eve.std.collection.Observable
---@return eve.ux.nvimbar.IRawComponent
function M.result_pos(position, result_lnum, result_total)
  local hln_text = position .. "_picker_result_pos_text" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
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
