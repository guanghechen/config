---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.view" ---@type string

local Future = require("stl.c.future")
local async = require("ux.treeview.async")
local surface = require("ux.treeview.surface")
local decorations = require("ux.treeview.decorations")

---@class ux.treeview.View
---@field bufnr                         integer
---@field winnr                         integer
---@field _state                        ux.treeview.State
---@field _native                       yoz.ux.treeview.View
---@field _options                      ux.treeview.IViewOptions
---@field _epoch                        integer
---@field _gesture_sequence             integer
---@field _action_sequence              integer
---@field _minimum_sequence             integer
---@field _minimum_commit               ?string
---@field _context                      {indent: integer, slots: integer, separator: string}
---@field _glyphs                       table<string, string>
---@field _closed                       boolean
---@field _desynced                     boolean
---@field _busy                         boolean
---@field _publishing                   boolean
---@field _window_options               table<string, any>
---@field _previous_bufnr               integer
---@field _group                        ?integer
---@field _frame                        ?yoz.ux.treeview.Frame
---@field _latest                       ?yoz.ux.treeview.Frame
---@field _header                       ?ux.treeview.IFrameHeader
---@field _publication                  ?table
---@field _decorations                  ?table
---@field _gesture                      ?table
---@field _submission                   ?table
---@field _program_cursor               ?integer[]
---@field _render_error                 any
---@field _projection_error             ?string
---@field _failed_target                ?string
---@field _resync_attempted             ?boolean
---@field _last_plan                    ?table
local M = {}
M.__index = M

---@return boolean
function M:_valid()
  return not self._closed
    and vim.api.nvim_buf_is_valid(self.bufnr)
    and vim.api.nvim_win_is_valid(self.winnr)
    and vim.api.nvim_win_get_buf(self.winnr) == self.bufnr
end

---@return string|nil
function M:_visual_mode()
  if vim.api.nvim_get_current_win() ~= self.winnr or vim.api.nvim_get_current_buf() ~= self.bufnr then
    return nil
  end
  local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
  return (mode == "v" or mode == "V") and mode or nil
end

---@return nil
function M:_sync_gesture()
  if self._publishing or self._desynced or not self._frame then
    return
  end
  local mode = self:_visual_mode()
  if mode and not self._gesture then
    self._gesture_sequence = self._gesture_sequence + 1
    self._gesture = { id = self._gesture_sequence, mode = mode, frame = self._frame }
  elseif not mode and self._gesture then
    self._gesture = nil
  elseif mode then
    self._gesture.mode = mode
  end
end

---@param error                         any
---@return nil
function M:_notify_error(error)
  if self._options.on_error then
    local ok, callback_error = pcall(self._options.on_error, error)
    if not ok then
      async.report(callback_error)
    end
  else
    async.report(error)
  end
end

---@return nil
function M:_redraw()
  if self:_valid() then
    vim.api.nvim__redraw({ win = self.winnr, valid = false })
  end
end

---@return nil
function M:_poll()
  if self._closed then
    return
  end
  if not self:_valid() then
    self:detach()
    return
  end
  self:_sync_gesture()
  local projection_error = self._state:status().projection_error
  if projection_error and projection_error.message ~= self._projection_error then
    self._projection_error = projection_error.message
    self:_notify_error(projection_error)
  elseif not projection_error then
    self._projection_error = nil
  end
  local latest = self._native:snapshot()
  if not self._frame or latest:id() ~= self._frame:id() then
    self._latest = latest
  end
  local target = self._latest
  if not target or self._busy or self._submission or self._failed_target == target:id() then
    return
  end
  if self._desynced and self._resync_attempted then
    return
  end
  if self._gesture and target:header().layout_revision ~= self._header.layout_revision then
    return
  end
  local ok, error = pcall(surface.request, self, target, self._desynced or self._frame == nil)
  if not ok then
    self._failed_target = target:id()
    surface.fail(self, error, false)
  end
end

---@return yoz.ux.treeview.Frame|nil
function M:frame()
  if self._desynced then
    return nil
  end
  return self._frame
end

---@return table
function M:status()
  return {
    closed = self._closed,
    desynced = self._desynced,
    preparing = self._busy,
    frame = self._header,
    publication = self._publication,
    error = self._render_error,
    last_plan = self._last_plan,
  }
end

---@return nil
function M:refresh()
  if not self:_valid() then
    return
  end
  self._resync_attempted = false
  self._failed_target = nil
  self._render_error = nil
  if self._state:status().projection_error then
    async.run(self._state._native:refresh()):finally(function()
      if not self._closed then
        self:_poll()
      end
    end)
    return
  end
  self._latest = self._native:snapshot()
  if not self._busy then
    surface.request(self, self._latest, true)
  end
end

---@param direction                     string
---@return nil
function M:navigate(direction)
  if not self:_valid() or self._desynced or self._publishing or not self._frame then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(self.winnr)
  local row = self._frame:navigate(cursor[1], direction)
  if not row then
    return
  end
  vim.api.nvim_win_set_cursor(self.winnr, { row, 0 })
  self._state:dispatch({ kind = "set_cursor", node = self._frame:node_at(row) }, { frame = self._frame })
end

---@return nil
function M:activate()
  if not self:_valid() or self._desynced or self._publishing or not self._frame then
    return
  end
  local row = vim.api.nvim_win_get_cursor(self.winnr)[1]
  local node = self._frame:node_at(row)
  if not node then
    return
  end
  local info = self._frame:rows(row, row)
  if info.can_expand[1] and self._header.mode == "tree" then
    self._state
      :dispatch({ kind = "toggle_expanded", node = node, recursive = false }, { frame = self._frame })
      :finally(function(_, result)
        if not self._closed and result.kind == "Rejected" then
          self:_notify_error(result.error)
        end
      end)
  elseif self._options.on_activate then
    self._options.on_activate(self._frame, node)
  end
end

---@param action                        string
---@param recursive                     boolean
---@return stl.c.Future
function M:select(action, recursive)
  if
    type(recursive) ~= "boolean" or (action ~= "select_node" and action ~= "deselect_node" and action ~= "toggle_node")
  then
    return Future.resolve(
      async.rejected("InvalidUpdate", "Selection requires an explicit action and boolean recursive")
    )
  end
  return self:range_action(function(frame, first, last)
    return self._state:dispatch({
      kind = action,
      range = { frame = frame, first = first, last = last },
      recursive = recursive,
    })
  end)
end

---@param submit                        fun(frame: yoz.ux.treeview.Frame, first: integer, last: integer, visual: boolean): stl.c.Future
---@return stl.c.Future
function M:range_action(submit)
  if not self:_valid() or self._desynced or self._publishing or not self._frame then
    return Future.resolve(async.rejected("Stale", "Treeview surface has no valid input frame"))
  end
  self:_sync_gesture()
  local frame = assert(self._frame)
  local row = vim.api.nvim_win_get_cursor(self.winnr)[1]
  local first, last = row, row
  local gesture = self._gesture and self._gesture.id or nil
  if gesture then
    local anchor = vim.fn.getpos("v")[2]
    first, last = math.min(anchor, row), math.max(anchor, row)
  end
  if not frame:node_at(first) then
    return Future.resolve({ kind = "NoChange" })
  end
  self._action_sequence = self._action_sequence + 1
  local submission = { gesture = gesture, sequence = self._action_sequence, epoch = self._epoch }
  self._submission = submission
  local future = submit(frame, first, last, gesture ~= nil)
  future:finally(function(ok, result)
    if self._closed or self._epoch ~= submission.epoch then
      return
    end
    if self._submission == submission then
      self._submission = nil
    end
    if ok and result.kind == "Applied" and submission.sequence >= self._minimum_sequence then
      self._minimum_sequence = submission.sequence
      self._minimum_commit = result.revisions.commit
    end
    if gesture and self._gesture and self._gesture.id == gesture then
      self._publishing = true
      if self:_visual_mode() then
        vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
      end
      self._gesture = nil
      self._publishing = false
    end
    if not ok or result.kind == "Rejected" then
      self:_notify_error(ok and result.error or result)
    end
    self:_poll()
  end)
  return future
end

---@return nil
function M:detach()
  if self._closed then
    return
  end
  self._closed = true
  self._epoch = self._epoch + 1
  self._state._data._views[self] = nil
  decorations.detach(self)
  self._native:detach()
  self._frame, self._latest, self._gesture, self._decorations = nil, nil, nil, nil
  if self._group then
    vim.api.nvim_del_augroup_by_id(self._group)
  end
  if vim.api.nvim_win_is_valid(self.winnr) and vim.api.nvim_win_get_buf(self.winnr) == self.bufnr then
    if vim.api.nvim_buf_is_valid(self._previous_bufnr) then
      vim.api.nvim_win_set_buf(self.winnr, self._previous_bufnr)
    end
    for name, value in pairs(self._window_options) do
      vim.api.nvim_set_option_value(name, value, { win = self.winnr })
    end
  end
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
end

---@param state                         ux.treeview.State
---@param options                       ?ux.treeview.IViewOptions
---@return ux.treeview.View
function M.new(state, options)
  options = options or {}
  if options.selection_recursive ~= nil and type(options.selection_recursive) ~= "boolean" then
    error("selection_recursive must be a boolean")
  end
  local winnr = options.winnr or vim.api.nvim_get_current_win()
  assert(vim.api.nvim_win_is_valid(winnr), "Treeview requires a live window")
  local native = state._native:attach()
  local self = setmetatable({
    _state = state,
    _native = native,
    _options = options,
    _epoch = 1,
    _gesture_sequence = 0,
    _action_sequence = 0,
    _minimum_sequence = 0,
    _context = { indent = 2, slots = 2, separator = "/" },
    _glyphs = vim.tbl_extend("force", {
      selected = "●",
      self_selected = "◐",
      expanded = "▾",
      collapsed = "▸",
      leaf = "",
      loading = "…",
      error = "!",
      branch = "├─",
      last = "╰─",
      guide = "│",
    }, options.glyphs or {}),
    _closed = false,
    _desynced = false,
    _busy = false,
    _publishing = false,
    _window_options = {},
    _previous_bufnr = vim.api.nvim_win_get_buf(winnr),
    winnr = winnr,
    bufnr = vim.api.nvim_create_buf(false, true),
  }, M)
  -- Renaming an already named buffer leaves an unloaded entry for its previous name.
  vim.api.nvim_buf_set_name(self.bufnr, options.bufname or "treeview://" .. native:id())
  for name, value in pairs({
    buftype = "nofile",
    bufhidden = "wipe",
    swapfile = false,
    modifiable = false,
    filetype = "treeview",
    undolevels = -1,
  }) do
    vim.api.nvim_set_option_value(name, value, { buf = self.bufnr })
  end
  vim.api.nvim_win_set_buf(winnr, self.bufnr)
  for name, value in pairs({
    wrap = false,
    foldenable = false,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    list = false,
  }) do
    self._window_options[name] = vim.api.nvim_get_option_value(name, { win = winnr })
    vim.api.nvim_set_option_value(name, value, { win = winnr })
  end
  self._group = vim.api.nvim_create_augroup("UxTreeview" .. native:id(), { clear = true })
  vim.api.nvim_buf_attach(self.bufnr, false, {
    on_lines = function()
      if not self._publishing and not self._closed then
        self._desynced = true
        vim.schedule(function()
          surface.fail(self, "Treeview buffer was modified outside publication", true)
        end)
      end
    end,
    on_detach = function()
      if not self._closed then
        vim.schedule(function()
          self:detach()
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = self._group,
    callback = function()
      if self:_valid() then
        self:_sync_gesture()
      end
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self._group,
    buffer = self.bufnr,
    callback = function()
      if not self:_valid() or self._publishing or self._desynced or not self._frame then
        return
      end
      local cursor = vim.api.nvim_win_get_cursor(self.winnr)
      if self._program_cursor and cursor[1] == self._program_cursor[1] and cursor[2] == self._program_cursor[2] then
        self._program_cursor = nil
        return
      end
      self._program_cursor = nil
      local node = self._frame:node_at(cursor[1])
      if node then
        self._state:dispatch({ kind = "set_cursor", node = node }, { frame = self._frame })
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = self._group,
    pattern = tostring(winnr),
    callback = function()
      self:detach()
    end,
  })
  if options.keymaps ~= false then
    ---@type stl.t.IKeymap[]
    local keymaps = {
      {
        modes = { "n", "x" },
        key = "[i",
        desc = "Treeview parent",
        callback = function()
          self:navigate("parent")
        end,
      },
      {
        modes = { "n", "x" },
        key = "]i",
        desc = "Treeview last child or sibling",
        callback = function()
          self:navigate("last_child_or_sibling")
        end,
      },
      {
        modes = { "n" },
        key = "<CR>",
        desc = "Treeview activate",
        callback = function()
          self:activate()
        end,
      },
    }
    if options.selection_recursive ~= nil then
      keymaps[#keymaps + 1] = {
        modes = { "n", "x" },
        key = "<Tab>",
        desc = "Treeview toggle selection",
        callback = function()
          self:select("toggle_node", options.selection_recursive)
        end,
      }
    end
    stl.nvim.fn.bindkeys(keymaps, { bufnr = self.bufnr, silent = true, noremap = true })
  end
  decorations.attach(self)
  state._data._views[self] = true
  async.watch(state._data)
  self._latest = native:snapshot()
  self:_poll()
  return self
end

return M
