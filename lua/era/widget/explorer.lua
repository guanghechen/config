local Widget = require("era.m.explorer.widget")

---@class era.widget.explorer
local M = {}

stl.fn.observe({
  dot.context.explorer.flag_foldempty,
  dot.context.explorer.flag_selected,
  dot.context.explorer.flag_show_hidden,
  dot.context.explorer.flag_viewtype,
}, function()
  if vim.o.showtabline ~= 0 then
    dot.state.status.dirtier_tabline:mark_dirty()
  elseif M.widget ~= nil and M.widget:isvisible() then
    M.widget:render_winbar()
  end
end, true)

---@type era.m.explorer.Widget|nil
M.widget = nil

---@return nil
function M.focus()
  local widget = M.get_widget() ---@type era.m.explorer.Widget
  widget:focus()
end

---@return nil
function M.focus_cwd()
  local cwd = dot.path.cwd() ---@type string
  M.set_root(cwd)
end

---@return nil
function M.focus_workspace()
  local workspace = dot.path.workspace() ---@type string
  M.set_root(workspace)
end

---@return era.m.explorer.Widget
function M.get_widget()
  if M.widget == nil then
    M.widget = Widget.new({
      name = "explorer.default",
      width = dot.context.explorer.width:snapshot(),
      o_flag_foldempty = dot.context.explorer.flag_foldempty,
      o_flag_hidden = dot.context.explorer.flag_show_hidden,
      o_width = dot.context.explorer.width,
      flags = M.__get_flags__(),
    })
  end
  return M.widget
end

---@return nil
function M.hide()
  local widget = M.get_widget() ---@type era.m.explorer.Widget
  widget:hide()
end

---@return nil
function M.refresh()
  local widget = M.get_widget() ---@type era.m.explorer.Widget
  widget:refresh()
end

---@param filepath                      string|nil
---@return nil
function M.reveal(filepath)
  if filepath == nil or #filepath == 0 then
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    filepath = vim.api.nvim_buf_get_name(bufnr)
    if #filepath == 0 then
      return
    end
  end

  filepath = dot.path.normalize(filepath)
  local uri = yoz.uri.from_filepath(filepath) ---@type string

  local widget = M.get_widget() ---@type era.m.explorer.Widget
  local was_visible = widget:isvisible() ---@type boolean
  widget:focus()
  if not was_visible then
    vim.schedule(function()
      widget:reveal(uri)
    end)
  else
    widget:reveal(uri)
  end
end

---@param root                          string|nil
---@return nil
function M.set_root(root)
  if root == nil then
    root = dot.path.cwd()
  end

  root = dot.path.normalize(root)
  local uri = yoz.uri.from_filepath(root .. "/") ---@type string

  local widget = M.get_widget() ---@type era.m.explorer.Widget
  widget:set_root(uri)
end

---@return nil
function M.toggle()
  local widget = M.get_widget() ---@type era.m.explorer.Widget
  widget:toggle()
end

----------------------------------------------------------------------------------------------------

---@return era.m.explorer.widget.IFlagItem[]
function M.__get_flags__()
  ---@type era.m.explorer.widget.IFlagItem[]
  return {
    {
      desc = "explorer: toggle selected only",
      callback = function()
        local enabled = dot.context.explorer.flag_selected:snapshot() ---@type boolean
        dot.context.explorer.flag_selected:next(not enabled)
      end,
      snapshot = function()
        local enabled = dot.context.explorer.flag_selected:snapshot() ---@type boolean
        return stl.icon.symbols.flag_selected, enabled and "picker_flag_orange" or "picker_flag_grey"
      end,
    },
    {
      desc = "explorer: toggle tree/list view",
      callback = function()
        local viewtype = dot.context.explorer.flag_viewtype:snapshot() ---@type dot.context.explorer.ViewtypeEnum
        local next_viewtype = viewtype == "tree" and "list" or "tree" ---@type dot.context.explorer.ViewtypeEnum
        dot.context.explorer.flag_viewtype:next(next_viewtype)
      end,
      snapshot = function()
        local viewtype = dot.context.explorer.flag_viewtype:snapshot() ---@type dot.context.explorer.ViewtypeEnum
        if viewtype == "tree" then
          return stl.icon.symbols.flag_tree, "picker_flag_blue"
        else
          return stl.icon.symbols.flag_list, "picker_flag_blue"
        end
      end,
    },
    {
      desc = "explorer: toggle fold empty",
      callback = function()
        local viewtype = dot.context.explorer.flag_viewtype:snapshot() ---@type dot.context.explorer.ViewtypeEnum
        if viewtype ~= "tree" then
          return
        end
        local enabled = dot.context.explorer.flag_foldempty:snapshot() ---@type boolean
        dot.context.explorer.flag_foldempty:next(not enabled)
      end,
      snapshot = function()
        local viewtype = dot.context.explorer.flag_viewtype:snapshot() ---@type dot.context.explorer.ViewtypeEnum
        if viewtype ~= "tree" then
          return "", ""
        end
        local enabled = dot.context.explorer.flag_foldempty:snapshot() ---@type boolean
        return stl.icon.symbols.flag_fold_empty_path, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
  }
end

return M
