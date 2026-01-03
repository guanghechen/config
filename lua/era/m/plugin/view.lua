local State = require("era.m.plugin.state")
local Widget = require("era.m.plugin.widget")

---@class era.m.plugin.IViewState
---@field public mode                   era.m.plugin.ViewModeEnum

---@class era.m.plugin.View : dot.t.IWidget
---@field public name                   string
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil
---@field public win_opts               vim.api.keyset.win_config
---@field public state                  era.m.plugin.IViewState
---@field public widget                 era.m.plugin.Widget
---@field protected _augroup            integer|nil
---@field protected _disposed           boolean
local M = {}
M.__index = M

---@type era.m.plugin.View|nil
local _instance = nil

---@return boolean
function M.visible()
  return _instance ~= nil and _instance:isvisible()
end

---@param mode                          era.m.plugin.ViewModeEnum|nil
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
  _instance.bufnr = nil
  _instance.winnr = nil
  _instance.win_opts = {}
  _instance:focus()

  -- Auto-detect missing plugins and show install mode
  if not mode then
    local State = require("era.m.plugin.state")
    local has_missing = false ---@type boolean
    for _, spec in ipairs(State.specs) do
      local path = dot.path.join(State.options.root, spec.name) ---@type string
      if not yoz.path.is_exist(path) then
        has_missing = true
        break
      end
    end
    if has_missing then
      _instance.state.mode = "install"
      _instance.widget:update()
    end
  end
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

  vim.bo[self.bufnr].buftype = "nofile"
  vim.bo[self.bufnr].filetype = "dot_plugin"
  vim.bo[self.bufnr].bufhidden = "wipe"

  vim.wo[self.winnr].conceallevel = 3
  vim.wo[self.winnr].foldenable = false
  vim.wo[self.winnr].spell = false
  vim.wo[self.winnr].wrap = true
  vim.wo[self.winnr].winhighlight = "Normal:m_pl_normal,FloatBorder:FloatActiveBorder,FloatTitle:m_pl_title"
  vim.wo[self.winnr].colorcolumn = ""
  vim.wo[self.winnr].winbar = ""

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
        self.widget:update()
      end
    end,
  })
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
      key = "H",
      callback = function()
        self.state.mode = "home"
        self.widget:update()
      end,
      desc = "Home",
    },
    {
      modes = { "n" },
      key = "I",
      callback = function()
        local Action = require("era.m.plugin.action")
        self.state.mode = "install"
        self.widget:update()
        if not Action.is_running() then
          Action.install(function()
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
      end,
      desc = "Install",
    },
    {
      modes = { "n" },
      key = "P",
      callback = function()
        self.state.mode = "profile"
        self.widget:update()
      end,
      desc = "Profile",
    },
    {
      modes = { "n" },
      key = "U",
      callback = function()
        local Action = require("era.m.plugin.action")
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
      end,
      desc = "Update",
    },
    {
      modes = { "n" },
      key = "X",
      callback = function()
        local Action = require("era.m.plugin.action")
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
          if self:isvisible() then
            self.widget:update()
          end
        end, function()
          if self:isvisible() then
            self.widget:update()
          end
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
