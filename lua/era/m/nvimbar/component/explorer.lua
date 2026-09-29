---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.explorer" ---@type string

local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt
local path_display = require("era.m.explorer.path_display")

---@return integer|nil
local function get_explorer_winnr()
  if era.widget.explorer.widget == nil then
    return nil
  end

  if not era.widget.explorer.widget:has_win_in_tab() then
    return nil
  end

  local winnr = era.widget.explorer.widget:get_winnr() ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  return winnr
end

---@class era.m.nvimbar.component.explorer
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.tabline(position)
  local hln_blank = position .. "_sidebar_blank" ---@type string
  local hln_split = position .. "_sidebar_split" ---@type string
  local hln_path = position .. "_explorer_path" ---@type string
  local hln_path_detached = position .. "_explorer_path_detached" ---@type string

  ---@param index                       integer
  ---@param observable                  stl.c.Observable
  ---@return nil
  local function toggle_flag(index, observable)
    local widget = era.widget.explorer.widget
    if widget then
      widget:toggle_flag(index)
    else
      local value = observable:snapshot()
      observable:next(index == 2 and (value == "tree" and "list" or "tree") or not value)
    end
  end

  -- Register callbacks once at component creation, not on every render
  local cb_flag_selected = dot.G.register_anonymous_fn(function()
    toggle_flag(1, dot.context.explorer.flag_selected)
  end) or "dot.G.noop"

  local cb_flag_viewtype = dot.G.register_anonymous_fn(function()
    toggle_flag(2, dot.context.explorer.flag_viewtype)
  end) or "dot.G.noop"

  local cb_flag_foldempty = dot.G.register_anonymous_fn(function()
    toggle_flag(3, dot.context.explorer.flag_foldempty)
  end) or "dot.G.noop"

  local cb_flag_hidden = dot.G.register_anonymous_fn(function()
    toggle_flag(4, dot.context.explorer.flag_show_hidden)
  end) or "dot.G.noop"

  ---@return string, string, string, string
  local function get_path_text()
    local widget = era.widget.explorer.widget
    return path_display.format(widget and widget:get_root_filepath(), position, widget and widget:status_text() or "")
  end

  ---@return string, string
  local function get_flags_text()
    local widget = era.widget.explorer.widget
    local display = widget and widget:get_display()
      or {
        selected_only = dot.context.explorer.flag_selected:snapshot(),
        mode = dot.context.explorer.flag_viewtype:snapshot(),
        compress = dot.context.explorer.flag_foldempty:snapshot(),
        show_hidden = dot.context.explorer.flag_show_hidden:snapshot(),
      }
    local show_hidden = display.show_hidden

    local text = "" ---@type string
    local hl_text = "" ---@type string
    local index = 1 ---@type integer

    local flag_selected = display.selected_only ---@type boolean
    local flag_selected_icon = stl.icon.symbols.flag_selected ---@type string
    local flag_selected_hln = flag_selected and "explorer_flag_orange" or "explorer_flag_grey" ---@type string
    local flag_selected_piece_hln = string.format("%s_%s", position, flag_selected_hln) ---@type string
    local flag_selected_digit = stl.icon.todigit_supscript(index) ---@type string
    local flag_selected_piece_text = " " .. flag_selected_icon .. flag_selected_digit ---@type string
    text = text .. flag_selected_piece_text
    hl_text = hl_text .. btn(txt(flag_selected_piece_text, flag_selected_piece_hln), cb_flag_selected)
    index = index + 1

    local flag_viewtype = display.mode ---@type dot.context.explorer.ViewtypeEnum
    local flag_viewtype_icon = flag_viewtype == "tree" and stl.icon.symbols.flag_tree or stl.icon.symbols.flag_list ---@type string
    local flag_viewtype_hln = "explorer_flag_blue" ---@type string
    local flag_viewtype_piece_hln = string.format("%s_%s", position, flag_viewtype_hln) ---@type string
    local flag_viewtype_digit = stl.icon.todigit_supscript(index) ---@type string
    local flag_viewtype_piece_text = " " .. flag_viewtype_icon .. flag_viewtype_digit ---@type string
    text = text .. flag_viewtype_piece_text
    hl_text = hl_text .. btn(txt(flag_viewtype_piece_text, flag_viewtype_piece_hln), cb_flag_viewtype)
    index = index + 1

    if flag_viewtype == "tree" then
      local flag_foldempty = display.compress ---@type boolean
      local flag_foldempty_icon = stl.icon.symbols.flag_fold_empty_path ---@type string
      local flag_foldempty_hln = flag_foldempty and "explorer_flag_blue" or "explorer_flag_grey" ---@type string
      local flag_foldempty_piece_hln = string.format("%s_%s", position, flag_foldempty_hln) ---@type string
      local flag_foldempty_digit = stl.icon.todigit_supscript(index) ---@type string
      local flag_foldempty_piece_text = " " .. flag_foldempty_icon .. flag_foldempty_digit ---@type string
      text = text .. flag_foldempty_piece_text
      hl_text = hl_text .. btn(txt(flag_foldempty_piece_text, flag_foldempty_piece_hln), cb_flag_foldempty)
    end
    index = index + 1

    local flag_hidden_icon = stl.icon.symbols.flag_hidden ---@type string
    local flag_hidden_hln = show_hidden and "explorer_flag_blue" or "explorer_flag_grey" ---@type string
    local flag_hidden_piece_hln = string.format("%s_%s", position, flag_hidden_hln) ---@type string
    local flag_hidden_digit = stl.icon.todigit_supscript(index) ---@type string
    local flag_hidden_piece_text = " " .. flag_hidden_icon .. flag_hidden_digit ---@type string
    text = text .. flag_hidden_piece_text
    hl_text = hl_text .. btn(txt(flag_hidden_piece_text, flag_hidden_piece_hln), cb_flag_hidden)

    return text, hl_text
  end

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "explorer:tabline",

    refresh = function()
      local path_text, path_hl_text, detached_text, detached_hl_text = get_path_text()
      local flags_text, flags_hl_text = get_flags_text()
      return {
        winnr = get_explorer_winnr(),
        path_text = path_text,
        path_hl_text = path_hl_text,
        detached_text = detached_text,
        detached_hl_text = detached_hl_text,
        flags_text = flags_text,
        flags_hl_text = flags_hl_text,
      }
    end,
    render = function(snapshot, context, remain_width)
      local winnr = snapshot.winnr
      if
        winnr == nil
        or not vim.api.nvim_win_is_valid(winnr)
        or vim.api.nvim_win_get_tabpage(winnr) ~= context.tabnr
      then
        return "", ""
      end
      local width = math.min(remain_width, vim.api.nvim_win_get_width(winnr))
      if width < 1 then
        return "", ""
      end
      local path_text, path_hl_text = snapshot.path_text, snapshot.path_hl_text
      local detached_text, detached_hl_text = snapshot.detached_text, snapshot.detached_hl_text
      local flags_text, flags_hl_text = snapshot.flags_text, snapshot.flags_hl_text

      local path_width = vim.api.nvim_strwidth(path_text) + vim.api.nvim_strwidth(detached_text) ---@type integer
      local flags_width = vim.api.nvim_strwidth(flags_text) ---@type integer
      local content_width = path_width + flags_width + 1 ---@type integer

      if width < content_width then
        local available = width - flags_width - vim.api.nvim_strwidth(detached_text) - 1 ---@type integer
        if available > 3 then
          path_text = vim.fn.strcharpart(path_text, 0, available - 1)
          while vim.api.nvim_strwidth(path_text) > available - 1 do
            path_text = vim.fn.strcharpart(path_text, 0, vim.fn.strchars(path_text) - 1)
          end
          path_text = path_text .. "…"
        else
          path_text = string.rep(" ", math.max(0, available))
        end
        path_hl_text = txt(path_text, detached_text == "" and hln_path or hln_path_detached)
        path_width = vim.api.nvim_strwidth(path_text) + vim.api.nvim_strwidth(detached_text)
        content_width = path_width + flags_width + 1
      end

      local padding_width = math.max(0, width - content_width) ---@type integer
      local padding = string.rep(" ", padding_width) ---@type string
      local right_split = " " ---@type string

      local text = path_text .. detached_text .. padding .. flags_text .. right_split ---@type string
      local hl_text = path_hl_text
        .. detached_hl_text
        .. txt(padding, hln_blank)
        .. flags_hl_text
        .. txt(right_split, hln_split)

      return text, hl_text
    end,
  }
  return component
end

return M
