local State = require("era.m.plugin.state")
local Widget = require("era.m.plugin.widget")

---@class era.m.plugin.View : dot.t.IWidget
---@field public name                   string
---@field public bufnr                  ?integer
---@field public winnr                  ?integer
---@field public win_opts               vim.api.keyset.win_config
---@field public widget                 era.m.plugin.Widget
---@field protected _augroup            ?integer
---@field protected _disposed           boolean
---@field protected _update_scheduled   boolean
local M = {}
M.__index = M

---@type era.m.plugin.View|nil
local _instance = nil

---@return boolean
function M.visible()
  return _instance ~= nil and _instance:isvisible()
end

---@return nil
function M.show()
  if _instance ~= nil and not _instance._disposed then
    local was_visible = _instance:isvisible() ---@type boolean
    _instance:focus()
    if was_visible then
      _instance.widget:update()
    end
    return
  end

  _instance = setmetatable({}, M)
  _instance.name = "plugin"
  _instance._augroup = nil
  _instance._disposed = false
  _instance._update_scheduled = false
  _instance.bufnr = nil
  _instance.winnr = nil
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

  if self.winnr ~= nil and vim.api.nvim_win_is_valid(self.winnr) then
    vim.api.nvim_set_current_win(self.winnr)
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

  local bufnr = self.bufnr ---@type integer|nil
  local winnr = self.winnr ---@type integer|nil

  self.bufnr = nil
  self.winnr = nil

  vim.schedule(function()
    if winnr and vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.diagnostic.reset(State.ns, bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  if self.winnr == nil or not vim.api.nvim_win_is_valid(self.winnr) then
    return false
  end
  return vim.api.nvim_get_current_win() == self.winnr
end

---@return boolean
function M:isvisible()
  return self.winnr ~= nil and vim.api.nvim_win_is_valid(self.winnr)
end

---@return nil
function M:resize()
  if not self:isvisible() then
    return
  end
  self:__layout__()
  vim.api.nvim_win_set_config(self.winnr, {
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
  self.bufnr = vim.api.nvim_create_buf(false, true)
  self.winnr = vim.api.nvim_open_win(self.bufnr, true, self.win_opts)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = self.bufnr })
  vim.api.nvim_set_option_value("filetype", "dot_plugin", { buf = self.bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self.bufnr })

  vim.api.nvim_set_option_value("conceallevel", 3, { win = self.winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldenable", false, { win = self.winnr, scope = "local" })
  vim.api.nvim_set_option_value("spell", false, { win = self.winnr, scope = "local" })
  vim.api.nvim_set_option_value("wrap", true, { win = self.winnr, scope = "local" })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:m_pl_normal,FloatBorder:FloatActiveBorder,FloatTitle:m_pl_title",
    { win = self.winnr, scope = "local" }
  )
  vim.api.nvim_set_option_value("colorcolumn", "", { win = self.winnr, scope = "local" })
  vim.api.nvim_set_option_value("winbar", "", { win = self.winnr, scope = "local" })

  self._augroup = vim.api.nvim_create_augroup("dot_plugin_view_" .. self.winnr, { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = self._augroup,
    pattern = tostring(self.winnr),
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

  vim.api.nvim_create_autocmd("User", {
    group = self._augroup,
    pattern = "PluginLoad",
    callback = function()
      if self:isvisible() then
        self:__request_update__()
      end
    end,
  })
end

---@return nil
function M:__request_update__()
  if self._update_scheduled or not self:isvisible() then
    return
  end
  self._update_scheduled = true
  vim.schedule(function()
    self._update_scheduled = false
    if self:isvisible() then
      self.widget:update()
    end
  end)
end

---@param action                        era.m.plugin.ActionEnum
---@return nil
function M:__run_action__(action)
  local Action = require("era.m.plugin.action")
  if Action.is_running() then
    return
  end

  local function update()
    self:__request_update__()
  end

  if action == "install" then
    Action.install(update):finally(update)
  elseif action == "sync" then
    Action.sync(update):finally(update)
  elseif action == "update" then
    Action.update(update):finally(update)
  else
    Action.clean(update):finally(update)
  end
  self.widget:update()
end

---@return nil
function M:__setup_keymaps__()
  local bufnr = self.bufnr ---@type integer

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

  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "I",
      callback = function()
        self:__run_action__("install")
      end,
      desc = "Install",
    },
    {
      modes = { "n" },
      key = "S",
      callback = function()
        self:__run_action__("sync")
      end,
      desc = "Sync",
    },
    {
      modes = { "n" },
      key = "U",
      callback = function()
        self:__run_action__("update")
      end,
      desc = "Update",
    },
    {
      modes = { "n" },
      key = "X",
      callback = function()
        self:__run_action__("clean")
      end,
      desc = "Clean",
    },
    {
      modes = { "n" },
      key = "gb",
      callback = function()
        local Action = require("era.m.plugin.action")
        if Action.is_running() then
          return
        end

        local cursor = vim.api.nvim_win_get_cursor(self.winnr) ---@type integer[]
        local line = cursor[1] ---@type integer
        local name = self.widget:get_plugin_at_line(line) ---@type string|nil
        if not name then
          return
        end

        Action.build(name, function()
          self:__request_update__()
        end):finally(function()
          self:__request_update__()
        end)
        self.widget:update()
      end,
      desc = "Build",
    },
    {
      modes = { "n" },
      key = "q",
      callback = function()
        self:close()
      end,
      desc = "Close",
    },
  }

  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, nowait = true })
end

return M
