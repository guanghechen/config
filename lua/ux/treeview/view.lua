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
---@field _detached                     boolean
---@field _desynced                     boolean
---@field _busy                         boolean
---@field _publishing                   boolean
---@field _window_options               table<string, any>
---@field _previous_bufnr               ?integer
---@field _group                        ?integer
---@field _frame                        ?yoz.ux.treeview.Frame
---@field _latest                       ?yoz.ux.treeview.Frame
---@field _header                       ?ux.treeview.IFrameHeader
---@field _publication                  ?table
---@field _decorations                  ?table
---@field _gesture                      ?table
---@field _submission                   ?table
---@field _observed_cursor              ?integer[]
---@field _render_error                 any
---@field _render_guard                 ?table
---@field _projection_error             ?string
---@field _failed_target                ?string
---@field _resync_attempted             ?boolean
---@field _last_plan                    ?table
---@field _source_after                 ?integer
---@field _source_timer                 ?uv.uv_timer_t
---@field _decoration_revision          ?integer
---@field _decoration_pending           ?boolean
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
  return (mode == "v" or mode == "V" or mode == "\22") and mode or nil
end

---@return nil
function M:_sync_gesture()
  if self._publishing or self._desynced or not self._frame then
    return
  end
  local mode = self:_visual_mode()
  if mode and not self._gesture then
    self._gesture_sequence = self._gesture_sequence + 1
    self._gesture = { id = self._gesture_sequence }
  elseif not mode and self._gesture then
    self._gesture = nil
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
function M:_cancel_source_timer()
  if self._source_timer then
    if not self._source_timer:is_closing() then
      self._source_timer:stop()
      self._source_timer:close()
    end
    self._source_timer = nil
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
  local latest, projection_error = self._native:poll_frame(self._latest or self._frame)
  if projection_error and projection_error.message ~= self._projection_error then
    self._projection_error = projection_error.message
    self:_notify_error(projection_error)
  elseif not projection_error then
    self._projection_error = nil
  end
  if latest then
    self._latest = latest
  end
  if projection_error then
    return
  end
  local target = self._latest or self._decoration_pending and self._frame
  if not target or self._busy or self._submission or self._failed_target == target:id() then
    return
  end
  if self._desynced and self._resync_attempted then
    return
  end
  local header = target:header()
  if self._gesture and header.layout_revision ~= self._header.layout_revision then
    return
  end
  if
    self._header
    and not self._desynced
    and not self._minimum_commit
    and not self._decoration_pending
    and header.data_revision ~= self._header.data_revision
    and header.cursor == self._header.cursor
    and header.mode == self._header.mode
    and header.root.kind == self._header.root.kind
    and header.root.node == self._header.root.node
    and self._source_after
  then
    local remaining = self._source_after - vim.uv.hrtime()
    if remaining > 0 then
      -- Bound continuous source publication without coalescing input dispatches or cursor changes.
      if not self._source_timer then
        local timer
        timer = vim.defer_fn(function()
          if self._source_timer ~= timer then
            return
          end
          self._source_timer = nil
          if not self._closed then
            async.watch(self._state._data)
          end
        end, math.max(1, math.ceil(remaining / 1000000)))
        self._source_timer = timer
      end
      return
    end
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
    preparing = self._busy or self._decoration_pending == true,
    frame = self._header,
    publication = self._publication,
    error = self._render_error,
    last_plan = self._last_plan,
  }
end

---@return nil
function M:refresh_decorations()
  if not self:_valid() then
    return
  end
  self._failed_target = nil
  self._render_error = nil
  self._resync_attempted = false
  local pending = self._decoration_pending
  self._decoration_revision = (self._decoration_revision or 0) + 1
  self._decoration_pending = true
  if not pending then
    vim.schedule(function()
      if not self._closed then
        async.watch(self._state._data)
      end
    end)
  end
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

---@param row                           integer
---@return stl.c.Future
function M:set_cursor(row)
  if not self:_valid() or self._desynced or self._publishing or not self._frame then
    return Future.resolve(async.rejected("Stale", "Treeview surface has no valid input frame"))
  end
  local node = self._frame:node_at(row)
  if not node then
    return Future.resolve({ kind = "NoChange" })
  end
  vim.api.nvim_win_set_cursor(self.winnr, { row, 0 })
  self._observed_cursor = vim.api.nvim_win_get_cursor(self.winnr)
  return self._state:dispatch({ kind = "set_cursor", node = node }, { frame = self._frame })
end

---@param direction                     string
---@return nil
function M:navigate(direction)
  if not self:_valid() or self._desynced or self._publishing or not self._frame then
    return
  end
  local row = self._frame:navigate(vim.api.nvim_win_get_cursor(self.winnr)[1], direction)
  if row then
    self:set_cursor(row)
  end
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
---@param notify                        ?boolean Report failures here unless the caller owns reporting.
---@return stl.c.Future
function M:range_action(submit, notify)
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
    if notify ~= false and (not ok or result.kind == "Rejected") then
      self:_notify_error(ok and result.error or result)
    end
    self:_poll()
  end)
  return future
end

---@return nil
function M:detach()
  self:_cancel_source_timer()
  if self._detached then
    return
  end
  self._detached = true
  if not self._closed then
    self._closed = true
    self._epoch = self._epoch + 1
  end
  self._state._data._views[self] = nil
  decorations.detach(self)
  self._native:detach()
  self._frame, self._latest, self._gesture, self._decorations = nil, nil, nil, nil
  self._render_guard = nil
  if self._group then
    vim.api.nvim_del_augroup_by_id(self._group)
  end
  if vim.api.nvim_win_is_valid(self.winnr) and vim.api.nvim_win_get_buf(self.winnr) == self.bufnr then
    if self._previous_bufnr and vim.api.nvim_buf_is_valid(self._previous_bufnr) then
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
  if options.bufnr then
    assert(
      options.bufnr > 0
        and vim.api.nvim_buf_is_valid(options.bufnr)
        and not decorations.attached(options.bufnr)
        and vim.api.nvim_get_option_value("buftype", { buf = options.bufnr }) == "nofile"
        and not vim.api.nvim_get_option_value("modified", { buf = options.bufnr })
        and vim.api.nvim_buf_line_count(options.bufnr) == 1
        and vim.api.nvim_buf_get_lines(options.bufnr, 0, 1, true)[1] == "",
      "Treeview requires an unowned, empty, unmodified scratch buffer"
    )
  end
  local previous = vim.api.nvim_win_get_buf(winnr)
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
    _detached = false,
    _desynced = false,
    _busy = false,
    _publishing = false,
    _window_options = {},
    _previous_bufnr = previous ~= options.bufnr and previous or nil,
    winnr = winnr,
    bufnr = options.bufnr or vim.api.nvim_create_buf(false, true),
  }, M)
  -- Renaming an already named buffer leaves an unloaded entry for its previous name.
  local bufname = options.bufname or "treeview://" .. native:id()
  if vim.api.nvim_buf_get_name(self.bufnr) ~= bufname then
    vim.api.nvim_buf_set_name(self.bufnr, bufname)
  end
  local filetype = options.bufnr and vim.api.nvim_get_option_value("filetype", { buf = self.bufnr }) or ""
  for name, value in pairs({
    buftype = "nofile",
    bufhidden = "wipe",
    swapfile = false,
    modifiable = false,
    undolevels = -1,
  }) do
    vim.api.nvim_set_option_value(name, value, { buf = self.bufnr })
  end
  if filetype == "" then
    vim.api.nvim_set_option_value("filetype", "treeview", { buf = self.bufnr })
  end
  if previous ~= self.bufnr then
    vim.api.nvim_win_set_buf(winnr, self.bufnr)
  end
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
  ---@return nil
  local function unload()
    if self._closed then
      return
    end
    -- BufUnload precedes exit-time Future settlement and forbids switching windows.
    self._closed = true
    self._epoch = self._epoch + 1
    vim.schedule(function()
      self:detach()
    end)
  end
  vim.api.nvim_create_autocmd("BufUnload", {
    group = self._group,
    buf = self.bufnr,
    callback = unload,
  })
  vim.api.nvim_buf_attach(self.bufnr, false, {
    on_lines = function()
      if not self._publishing and not self._closed then
        self._desynced = true
        vim.schedule(function()
          surface.fail(self, "Treeview buffer was modified outside publication", true)
        end)
      end
    end,
    on_detach = unload,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = self._group,
    callback = function()
      if self:_valid() then
        self:_sync_gesture()
        async.watch(self._state._data)
      end
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self._group,
    buf = self.bufnr,
    callback = function()
      if not self:_valid() or self._publishing or self._desynced or not self._frame then
        return
      end
      local cursor = vim.api.nvim_win_get_cursor(self.winnr)
      local observed = self._observed_cursor
      if observed and cursor[1] == observed[1] and cursor[2] == observed[2] then
        return
      end
      -- Repeated or delayed events at an unchanged position carry no new navigation intent.
      self._observed_cursor = cursor
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
        key = "<Esc><Esc>",
        desc = "Treeview clear selection",
        callback = function()
          if self:_visual_mode() then
            vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
          end
          self._state:clear_selection():finally(function(ok, result)
            if not ok or result.kind == "Rejected" then
              self:_notify_error(ok and result.error or result)
            end
          end)
        end,
      },
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
  if options.on_attach then
    local ok, failure = pcall(options.on_attach, self)
    if not ok then
      self:detach()
      error(failure, 0)
    end
  end
  async.watch(state._data)
  self._latest = native:snapshot()
  self:_poll()
  return self
end

return M
