local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@class eve.ux.nvimbar.component.widget
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.flags(position)
  local hln_flag = position .. "_widget_flag" ---@type string
  local hln_flag_sep = position .. "_widget_flag_sep" ---@type string
  local hln_flag_enabled = position .. "_widget_flag_enabled" ---@type string
  local hln_flag_enabled_sep = position .. "_widget_flag_enabled_sep" ---@type string
  local hln_flag_scope = position .. "_widget_flag_scope" ---@type string
  local hln_flag_scope_sep = position .. "_widget_flag_scope_sep" ---@type string
  local hln_flag_popup = position .. "_widget_flag_popup" ---@type string
  local hln_flag_popup_sep = position .. "_widget_flag_popup_sep" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "widget",
    atomic = true,
    render = function()
      local widget = eve.widget.get_widget_visible() ---@type std.t.ux.IWidget|nil
      if widget == nil then
        return "", "", true
      end

      local items = widget.statusline_items ---@type std.t.ux.widget.IStatuslineItem[]|nil
      if items == nil or #items < 1 then
        return "", "", true
      end

      local text = "" ---@type string
      local hl_text = "" ---@type string
      local index = #items > 0 and items[1].type == "popup" and 0 or 1 ---@type integer
      for _, item in ipairs(items) do
        local callback = item.callback_fn ---@type string
        local digit = eve.icon.todigit_supscript(index) ---@type string
        local text_sep = index > 1 and "▏" or " " ---@type string
        if item.type == "enum" then
          local flag = item.state:snapshot() ---@type boolean
          local text_flag = flag .. digit ---@type string
          text = text .. text_sep .. text_flag ---@type string
          hl_text = hl_text
            .. txt(text_sep, flag and hln_flag_scope_sep or hln_flag_sep)
            .. btn(txt(text_flag, hln_flag_scope), callback)
        elseif item.type == "flag" then
          local flag = item.state:snapshot() ---@type boolean
          local text_flag = item.symbol .. digit ---@type string
          text = text .. text_sep .. text_flag ---@type string
          hl_text = hl_text
            .. txt(text_sep, flag and hln_flag_enabled_sep or hln_flag_sep)
            .. btn(txt(text_flag, flag and hln_flag_enabled or hln_flag), callback)
        elseif item.type == "popup" then
          local flag = item.state:snapshot() ---@type boolean
          local text_flag = item.symbol .. digit ---@type string
          text = text .. text_sep .. text_flag ---@type string
          hl_text = hl_text
            .. txt(text_sep, flag and hln_flag_popup_sep or hln_flag_sep)
            .. btn(txt(text_flag, hln_flag_popup), callback)
        end
        index = index + 1
      end
      return text, hl_text, true
    end,
  }
  return component
end

return M
