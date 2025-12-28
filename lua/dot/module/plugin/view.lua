local State = require("dot.module.plugin.state")
local Widget = require("dot.module.plugin.widget")

---@class dot.module.plugin.IViewState
---@field public mode                   dot.module.plugin.ViewModeEnum

---@class dot.module.plugin.View : dot.t.IWidget
---@field public name                   string
---@field public buf                    integer|nil
---@field public win                    integer|nil
---@field public win_opts               vim.api.keyset.win_config
---@field public state                  dot.module.plugin.IViewState
---@field public widget                 dot.module.plugin.Widget
---@field protected _augroup            integer|nil
---@field protected _disposed           boolean
local M = {}
M.__index = M

---@type dot.module.plugin.View|nil
local _instance = nil

---@return boolean
function M.visible()
  return _instance ~= nil and _instance:isvisible()
end

---@param mode                          dot.module.plugin.ViewModeEnum|nil
---@return nil
function M.show(mode)
  if _instance ~= nil and not _instance._disposed then
    _instance:focus()
    if mode then
      _instance.state.mode = mode
      _instance.widget:update()
    end
    return
  end

  _instance = setmetatable({}, M)
  _instance.name = "plugin"
  _instance.state = { mode = mode or "home" }
  _instance._augroup = nil
  _instance._disposed = false
  _instance.buf = nil
  _instance.win = nil
  _instance.win_opts = {}
  _instance:focus()
end

---@return nil
function M.close_view()
  if _instance then
    _instance:close()
  end
end

----------------------------------------------------------------------------------------------------
-- dot.t.IWidget interface implementation
----------------------------------------------------------------------------------------------------

---@return nil
function M:close()
  self:hide()
  self._disposed = true
  _instance = nil
end

---@return nil
function M:focus()
  dot.state.widget.push(self)

  if self.win ~= nil and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_set_current_win(self.win)
    return
  end

  self:__layout__()
  self:__mount__()

  if self.widget == nil then
    self.widget = Widget.new(self)
  end

  self:__setup_keymaps__()
  self.widget:update()
end

---@return nil
function M:hide()
  if self._augroup then
    vim.api.nvim_del_augroup_by_id(self._augroup)
    self._augroup = nil
  end

  local buf = self.buf
  local win = self.win

  self.buf = nil
  self.win = nil

  vim.schedule(function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.diagnostic.reset(State.ns, buf)
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  if self.win == nil or not vim.api.nvim_win_is_valid(self.win) then
    return false
  end
  return vim.api.nvim_get_current_win() == self.win
end

---@return boolean
function M:isvisible()
  return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

---@return nil
function M:resize()
  if not self:isvisible() then
    return
  end
  self:__layout__()
  vim.api.nvim_win_set_config(self.win, {
    relative = self.win_opts.relative,
    width = self.win_opts.width,
    height = self.win_opts.height,
    row = self.win_opts.row,
    col = self.win_opts.col,
  })
end

----------------------------------------------------------------------------------------------------

---@return nil
function M:__layout__()
  ---@param max integer
  ---@param value number
  ---@return integer
  local function size(max, value)
    return value > 1 and math.min(math.floor(value), max) or math.floor(max * value)
  end

  local width = size(vim.o.columns, State.options.ui.size.width) ---@type integer
  local height = size(vim.o.lines, State.options.ui.size.height) ---@type integer

  self.win_opts = {
    relative = "editor",
    style = "minimal",
    border = State.options.ui.border,
    title = State.options.ui.title,
    title_pos = "center",
    zindex = 50,
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

---@return nil
function M:__mount__()
  self.buf = vim.api.nvim_create_buf(false, true)
  self.win = vim.api.nvim_open_win(self.buf, true, self.win_opts)

  vim.bo[self.buf].buftype = "nofile"
  vim.bo[self.buf].filetype = "dot_plugin"
  vim.bo[self.buf].bufhidden = "wipe"

  vim.wo[self.win].conceallevel = 3
  vim.wo[self.win].foldenable = false
  vim.wo[self.win].spell = false
  vim.wo[self.win].wrap = true
  vim.wo[self.win].winhighlight = "Normal:m_pl_normal,FloatBorder:FloatActiveBorder,FloatTitle:m_pl_title"
  vim.wo[self.win].colorcolumn = ""
  vim.wo[self.win].winbar = ""

  self._augroup = vim.api.nvim_create_augroup("dot_plugin_view_" .. self.win, { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = self._augroup,
    pattern = tostring(self.win),
    once = true,
    callback = function()
      self:hide()
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = self._augroup,
    callback = function()
      if not self:isvisible() then
        return true
      end
      self:resize()
    end,
  })
end

---@return nil
function M:__setup_keymaps__()
  local bufnr = self.buf ---@type integer

  for _, keymap in ipairs(dot.state.widget.get_keymaps(self)) do
    local keys = { keymap.key }
    if keymap.aliases then
      vim.list_extend(keys, keymap.aliases)
    end
    for _, key in ipairs(keys) do
      vim.keymap.set(keymap.modes, key, keymap.callback, {
        buffer = bufnr,
        nowait = true,
        desc = keymap.desc,
      })
    end
  end

  vim.keymap.set("n", "<Esc>", function()
    self:close()
  end, { buffer = bufnr, nowait = true, desc = "Close" })

  vim.keymap.set("n", "H", function()
    self.state.mode = "home"
    self.widget:update()
  end, { buffer = bufnr, nowait = true, desc = "Home" })

  vim.keymap.set("n", "P", function()
    self.state.mode = "profile"
    self.widget:update()
  end, { buffer = bufnr, nowait = true, desc = "Profile" })

  vim.keymap.set("n", "U", function()
    local Action = require("dot.module.plugin.action")
    self.state.mode = "update"
    self.widget:update()
    if not Action.is_running() then
      Action.update(function()
        if self:isvisible() then
          self.widget:update()
        end
      end, function()
        if self:isvisible() then
          self.widget:update()
        end
      end)
      self.widget:update()
    end
  end, { buffer = bufnr, nowait = true, desc = "Update" })

  vim.keymap.set("n", "X", function()
    local Action = require("dot.module.plugin.action")
    self.state.mode = "clean"
    self.widget:update()
    if not Action.is_running() then
      Action.clean(function()
        if self:isvisible() then
          self.widget:update()
        end
      end)
      self.widget:update()
    end
  end, { buffer = bufnr, nowait = true, desc = "Clean" })
end

return M
