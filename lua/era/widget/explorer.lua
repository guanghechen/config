---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.widget.explorer" ---@type string

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
    M.widget = era.m.explorer.Widget.new({
      name = "explorer.default",
      o_flag_foldempty = dot.context.explorer.flag_foldempty,
      o_flag_hidden = dot.context.explorer.flag_show_hidden,
      o_width = dot.context.explorer.width,
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

  filepath = dot.path.normalize(filepath, false, "/")

  local widget = M.get_widget() ---@type era.m.explorer.Widget
  widget:reveal(filepath)
end

---@param root                          string|nil
---@return nil
function M.set_root(root)
  if root == nil then
    root = dot.path.cwd()
  end

  root = dot.path.normalize(root, true, "/")
  local filepath = root:sub(-1) == "/" and root or (root .. "/") ---@type string

  local widget = M.get_widget() ---@type era.m.explorer.Widget
  widget:set_root(filepath)
end

---@return nil
function M.toggle()
  local widget = M.get_widget() ---@type era.m.explorer.Widget
  widget:toggle()
end

----------------------------------------------------------------------------------------------------

return M
