---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.widget" ---@type string

local Session = require("era.m.explorer.session")
local Action = require("era.m.explorer.action")
local Filetree = require("ux.filetree")
local Future = require("stl.c.future")
local Observable = require("stl.c.observable")
local Subscriber = require("stl.c.subscriber")
local path_display = require("era.m.explorer.path_display")
local filepath = require("ux.filetree.path")
local DISPLAY_FIELDS = { "selected_only", "mode", "compress", "show_hidden" }
-- Reserve the same cells for full and self-only marks, including glyph overhang.
local SELECTION_GLYPHS = {
  select = { selected = "󰄲  ", self_selected = "󰡖  " },
  copy = {
    selected = stl.icon.symbols.selection_copy .. "  ",
    self_selected = stl.icon.symbols.selection_copy .. "󰡖 ",
  },
  cut = {
    selected = stl.icon.symbols.selection_cut .. "  ",
    self_selected = stl.icon.symbols.selection_cut .. "󰡖 ",
  },
}

---@class era.m.explorer.Widget : dot.t.IWidget
---@field name                          string
---@field fullname                      string
---@field _session                      ?era.m.explorer.Session
---@field _ready                        stl.c.Future
---@field _action                       era.m.explorer.Action
---@field _views                        table<integer, ux.filetree.View>
---@field _tab_wins                     table<integer, integer>
---@field _tab_bufs                     table<integer, integer>
---@field _options                      stl.c.Observable[]
---@field _o_width                      stl.c.Observable
---@field _o_root                       stl.c.Observable
---@field _subscriptions                stl.c.IUnsubscribable[]
---@field _unregister                   (fun(): nil)[]
---@field _callbacks                    string[]
---@field _disposed                     boolean
---@field _group                        integer
---@field _navigation                   integer
---@field _workspace                    ux.filetree.Path
local M = {}
M.__index = M

---@return ux.treeview.IDisplay
function M:get_display()
  if self._session then
    return self._session.state:display()
  end
  return {
    selected_only = self._options[1]:snapshot(),
    mode = self._options[2]:snapshot(),
    compress = self._options[3]:snapshot(),
    show_hidden = self._options[4]:snapshot(),
    list_text = "ancestry",
  }
end

---@param props                         era.m.explorer.widget.IProps
---@return era.m.explorer.Widget
function M.new(props)
  local root = props.root or filepath.from_os(dot.path.workspace())
  local self = setmetatable({
    name = props.name,
    fullname = __module_name__ .. "@" .. props.name,
    _views = {},
    _tab_wins = {},
    _tab_bufs = {},
    _subscriptions = {},
    _unregister = {},
    _callbacks = {},
    _titles = {},
    _focus_highlights = {},
    _disposed = false,
    _navigation = 0,
    _workspace = root,
    _display_changes = {},
    _on_disposed = props.on_disposed,
    _o_root = Observable.from_value(root),
    _o_width = props.o_width or dot.context.explorer.width,
    _options = {
      props.o_flag_selected or dot.context.explorer.flag_selected,
      props.o_flag_viewtype or dot.context.explorer.flag_viewtype,
      props.o_flag_foldempty or dot.context.explorer.flag_foldempty,
      props.o_flag_hidden or dot.context.explorer.flag_show_hidden,
    },
  }, M)
  self._group = vim.api.nvim_create_augroup(self.fullname, { clear = true })
  self._action = Action.new(self)
  self._input_data = props.data
  self:_begin(root, props.session)
  for index, observable in ipairs(self._options) do
    self._subscriptions[#self._subscriptions + 1] = observable:subscribe(
      Subscriber.new({
        on_next = function(value)
          if value ~= observable:snapshot() then
            return
          end
          if self._session then
            local inputs = self._session._display_inputs
            if inputs[observable] == value then
              return
            end
            inputs[observable] = value
            self._session.state:note_navigation()
          end
          self._display_changes[DISPLAY_FIELDS[index]] = value
          self:_schedule_display()
        end,
      }),
      true
    )
    local callback, unregister = dot.G.register_anonymous_fn(function()
      self:toggle_flag(index)
    end)
    self._callbacks[index] = callback
    self._unregister[#self._unregister + 1] = unregister
  end
  self._subscriptions[#self._subscriptions + 1] = self._o_width:subscribe(
    Subscriber.new({
      on_next = function()
        self:resize()
      end,
    }),
    true
  )
  vim.api.nvim_create_autocmd("WinResized", {
    group = self._group,
    callback = function()
      for _, winnr in ipairs(vim.v.event.windows or {}) do
        for tabnr, owned in pairs(self._tab_wins) do
          if winnr == owned and self:get_winnr(tabnr) == owned then
            self._o_width:next(vim.api.nvim_win_get_width(owned))
            return
          end
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave" }, {
    group = self._group,
    callback = function()
      self:render_winbar()
    end,
  })
  vim.api.nvim_create_autocmd("OptionSet", {
    group = self._group,
    pattern = "showtabline",
    callback = function()
      self:render_winbar()
    end,
  })
  return self
end

---@return nil
function M:_schedule_display()
  if self._display_scheduled or self._disposed then
    return
  end
  self._display_scheduled = true
  vim.schedule(function()
    if self._disposed then
      return
    end
    local changes = self._display_changes
    self._display_changes = {}
    self._display_inflight = changes
    local ready = self._ready
    ready
      :then_(function(session)
        if self._disposed then
          return nil
        end
        local display, revision = session.state:display()
        return session.state:dispatch(
          { kind = "set_display", display = vim.tbl_extend("force", display, changes) },
          { expected_state = revision }
        )
      end)
      :then_(function(result)
        if not result or result.kind ~= "Rejected" or self._disposed then
          return
        end
        if result.error.code == "Stale" or result.error.code == "Busy" then
          for name, value in pairs(changes) do
            if self._display_changes[name] == nil then
              self._display_changes[name] = value
            end
          end
        else
          Session.report(result.error)
        end
      end)
      :catch(function(error)
        self:_report_ready_error(ready, error)
      end)
      :finally(function()
        self._display_scheduled = false
        self._display_inflight = nil
        if self._disposed then
          return
        end
        if next(self._display_changes) then
          vim.defer_fn(function()
            self:_schedule_display()
          end, 10)
        end
        self:render_winbar()
      end)
  end)
end

---@param index                         integer
---@return nil
function M:toggle_flag(index)
  local display = vim.tbl_extend("force", self:get_display(), self._display_inflight or {}, self._display_changes)
  if index == 3 and display.mode ~= "tree" then
    return
  end
  local name = DISPLAY_FIELDS[index]
  local value = display[name]
  value = index == 2 and (value == "tree" and "list" or "tree") or not value
  if self._session then
    self._session.state:note_navigation()
    self._session._display_inputs[self._options[index]] = value
  end
  self._display_changes[name] = value
  self:_schedule_display()
  -- Preferences persist the user's choice; the native publication drives every visible flag.
  self._options[index]:next(value, { silent = true })
end

---@return era.m.explorer.Session, ux.filetree.View
function M:context()
  local view = self:get_winnr() and self._views[vim.api.nvim_get_current_tabpage()]
  assert(self._session and view and not view._closed, "Explorer is still opening")
  return self._session, view
end

---@param tabnr                         integer
---@param winnr                         integer
---@return nil
function M:_forget_window(tabnr, winnr)
  if self._tab_wins[tabnr] ~= winnr then
    return
  end
  self._tab_wins[tabnr], self._tab_bufs[tabnr], self._views[tabnr] = nil, nil, nil
  self._titles[winnr], self._focus_highlights[winnr] = nil, nil
end

---@param tabnr                         ?integer
---@return integer|nil
function M:get_winnr(tabnr)
  tabnr = tabnr or vim.api.nvim_get_current_tabpage()
  local winnr = self._tab_wins[tabnr]
  if not winnr then
    return nil
  end
  local view = self._views[tabnr]
  if
    vim.api.nvim_win_is_valid(winnr)
    and vim.api.nvim_win_get_tabpage(winnr) == tabnr
    and vim.api.nvim_win_get_buf(winnr) == self._tab_bufs[tabnr]
    and (not view or not view._closed)
  then
    return winnr
  end
  self:_forget_window(tabnr, winnr)
  if view then
    view:detach()
  end
  return nil
end

---@return integer|nil
function M:get_bufnr()
  local winnr = self:get_winnr()
  return winnr and vim.api.nvim_win_get_buf(winnr) or nil
end

---@return string
function M:get_root_filepath()
  return self._o_root:snapshot()
end

---@return boolean
function M:show_hidden()
  return self:get_display().show_hidden
end

---@return string
---@return "error"|"progress"|nil priority
function M:status_text()
  if self._open_error then
    return "open failed · R retry"
  end
  if self._session then
    return self._session:status_text()
  end
  return "loading"
end

---@return string|nil
function M:get_cursor_filepath()
  local view = self:get_winnr() and self._views[vim.api.nvim_get_current_tabpage()]
  local resource = self._session and view and self._session:cursor(view)
  return resource and resource:path() or nil
end

---@param tabnr                         ?integer
---@return boolean
function M:has_win_in_tab(tabnr)
  return self:get_winnr(tabnr) ~= nil
end

---@param tabnr                         ?integer
---@return boolean
function M:isvisible(tabnr)
  return self:get_winnr(tabnr) ~= nil
end

---@param tabnr                         ?integer
---@return boolean
function M:isfocused(tabnr)
  return self:get_winnr(tabnr) == vim.api.nvim_get_current_win()
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param ready                         stl.c.Future
---@param error                         any
---@return nil
function M:_report_ready_error(ready, error)
  -- Initial-open failures belong to _begin, even when several views/actions await them.
  if not self._disposed and self._ready == ready and not ready:is_failed() then
    Session.report(error)
  end
end

---@param root                          string
---@param session                       ?era.m.explorer.Session
---@return nil
function M:_begin(root, session)
  self._open_error = nil
  local future = session and Future.resolve(session)
    or Session.open(root, self:get_display(), self._input_data, self._workspace)
  self._ready = future
  future:finally(function(ok, value)
    if self._disposed or self._ready ~= future then
      if ok and not value.owners then
        value:dispose()
      end
      return
    end
    if ok then
      self._session = value
      value.owners = (value.owners or 0) + 1
      self._o_root:next(value:root():path())
    else
      self._open_error = tostring(value)
      local message = self._open_error:match("^(.-)\nstack traceback:") or self._open_error
      Session.report(message .. "\nPress R in Explorer to retry.")
    end
    self:render_winbar()
  end)
end

---@param tabnr                         integer
---@param winnr                         integer
---@return nil
function M:_attach(tabnr, winnr)
  local ready = self._ready
  local bufnr = self._tab_bufs[tabnr]
  ready
    :then_(function(session)
      if self._disposed or self._ready ~= ready or self:get_winnr(tabnr) ~= winnr or self._tab_bufs[tabnr] ~= bufnr then
        return
      end
      -- Attach takes ownership of the placeholder; option callbacks must wait for the new owner.
      self._tab_wins[tabnr], self._tab_bufs[tabnr] = nil, nil
      local view
      view = Filetree.attach(session.state, {
        winnr = winnr,
        bufnr = bufnr,
        bufname = "explorer://" .. self.name .. "/" .. tabnr,
        glyphs = SELECTION_GLYPHS[session:mode() or "select"],
        on_attach = function(current)
          require("era.m.explorer.view").attach(session, current)
        end,
        on_error = Session.report,
        on_activate = function(frame, node)
          self._action:open(nil, session.data:inspect(frame:source(), node)):catch(Session.report)
        end,
        on_frame = function(frame)
          if self._disposed then
            return
          end
          session:observe_root(frame)
          local root = frame:header().root.node
          if root and frame:source():node(root) then
            self._o_root:next(session:root(frame):path())
          end
          if view then
            local glyphs = SELECTION_GLYPHS[session:mode(frame) or "select"]
            view._glyphs.selected, view._glyphs.self_selected = glyphs.selected, glyphs.self_selected
          end
          self:render_winbar()
        end,
      })
      if
        self._disposed
        or self._tab_wins[tabnr]
        or not view:_valid()
        or vim.api.nvim_win_get_tabpage(winnr) ~= tabnr
      then
        view:detach()
        return
      end
      self._tab_wins[tabnr], self._tab_bufs[tabnr] = winnr, view.bufnr
      self._views[tabnr], session.views[view] = view, function()
        self:render_winbar()
      end
      local detach = view.detach
      view.detach = function(current)
        session.views[current] = nil
        if self._views[tabnr] == current then
          self:_forget_window(tabnr, winnr)
        end
        detach(current)
      end
      require("era.m.explorer.keymaps").bind(self, view)
      self._titles[winnr], self._focus_highlights[winnr] = nil, nil
      self:render_winbar()
      session:refresh():catch(Session.report)
    end)
    :catch(function(error)
      if self._disposed or self._ready ~= ready then
        return
      end
      if
        not self._tab_wins[tabnr]
        and vim.api.nvim_win_is_valid(winnr)
        and vim.api.nvim_win_get_buf(winnr) == bufnr
      then
        self._tab_wins[tabnr], self._tab_bufs[tabnr] = winnr, bufnr
      end
      self:_report_ready_error(ready, error)
    end)
end

---@return integer
function M:focus()
  assert(not self._disposed, "Explorer was disposed")
  dot.state.widget.push(self)
  local tabnr = vim.api.nvim_get_current_tabpage()
  local winnr = self:get_winnr(tabnr)
  if winnr then
    vim.api.nvim_set_current_win(winnr)
    return winnr
  end
  local placeholder = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = placeholder })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = placeholder })
  vim.api.nvim_set_option_value("modifiable", false, { buf = placeholder })
  vim.api.nvim_set_option_value("filetype", "explorer", { buf = placeholder })
  vim.api.nvim_buf_set_name(placeholder, "explorer://" .. self.name .. "/" .. tabnr)
  local ok, opened = pcall(vim.api.nvim_open_win, placeholder, false, { split = "left", win = -1 })
  if not ok then
    vim.api.nvim_buf_delete(placeholder, { force = true })
    error(opened, 0)
  end
  winnr = opened
  self._tab_wins[tabnr], self._tab_bufs[tabnr] = winnr, placeholder
  local keymaps = dot.state.widget.get_keymaps(self)
  keymaps[#keymaps + 1] = {
    modes = { "n" },
    key = "R",
    desc = "Explorer: retry opening",
    callback = function()
      self:refresh()
    end,
  }
  stl.nvim.fn.bindkeys(keymaps, { bufnr = placeholder, noremap = true, silent = true })
  vim.w[winnr].wintype = stl.e.WinTypeEnum.EXPLORER
  self:resize()
  for name, value in pairs({
    foldcolumn = "0",
    signcolumn = "no",
    statuscolumn = "",
    number = false,
    relativenumber = false,
    wrap = false,
    spell = false,
    winfixwidth = true,
  }) do
    vim.api.nvim_set_option_value(name, value, { win = winnr })
  end
  vim.api.nvim_create_autocmd("WinClosed", {
    group = self._group,
    pattern = tostring(winnr),
    once = true,
    callback = function()
      self:_forget_window(tabnr, winnr)
    end,
  })
  vim.api.nvim_set_current_win(winnr)
  self:_attach(tabnr, winnr)
  return winnr
end

---@param tabnr                         ?integer
---@return nil
function M:hide(tabnr)
  tabnr = tabnr or vim.api.nvim_get_current_tabpage()
  local winnr = self:get_winnr(tabnr)
  if not winnr then
    return
  end
  self._o_width:next(vim.api.nvim_win_get_width(winnr))
  local view = self._views[tabnr]
  self:_forget_window(tabnr, winnr)
  if view then
    view:detach()
  end
  if vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
end

---@return nil
function M:close()
  self:hide()
end

---@return integer
function M:show()
  return self:focus()
end

---@return nil
function M:toggle()
  if self:isvisible() then
    self:hide()
  else
    self:focus()
  end
end

---@return nil
function M:resize()
  local width = math.max(1, math.min(self._o_width:snapshot(), vim.o.columns - 1))
  for tabnr, winnr in pairs(self._tab_wins) do
    if self:get_winnr(tabnr) == winnr then
      vim.api.nvim_win_set_width(winnr, width)
    end
  end
  self:render_winbar()
end

---@param width                         integer
---@return nil
function M:set_width(width)
  self._o_width:next(math.max(1, math.floor(width)))
end

---@return stl.c.Future
function M:refresh()
  if not self._session and self._ready:is_failed() then
    self:_begin(self._o_root:snapshot())
    for tabnr, winnr in pairs(self._tab_wins) do
      self:_attach(tabnr, winnr)
    end
    return self._ready
  end
  local ready = self._ready
  return ready
    :then_(function(session)
      if self._disposed then
        return
      end
      for _, tabnr in ipairs(vim.tbl_keys(self._views)) do
        local view = self._views[tabnr]
        if view and self:get_winnr(tabnr) == view.winnr then
          local status = view:status()
          if status.desynced or status.error or session.state:status().projection_error then
            view:refresh()
          end
        end
      end
      return session:refresh()
    end)
    :catch(function(error)
      self:_report_ready_error(ready, error)
    end)
end

---@param path                          string
---@return stl.c.Future
function M:set_root(path)
  self:focus()
  self._navigation = self._navigation + 1
  local generation = self._navigation
  if not self._session then
    self._o_root:next(path)
    self:_begin(path)
    for tabnr, winnr in pairs(self._tab_wins) do
      self:_attach(tabnr, winnr)
    end
    return self._ready
  end
  local ready = self._ready
  return ready
    :then_(function(session)
      if not self._disposed and self._ready == ready and generation == self._navigation then
        return session:navigate_path(path, false)
      end
    end)
    :catch(function(error)
      self:_report_ready_error(ready, error)
    end)
end

---@param path                          string
---@return stl.c.Future
function M:reveal(path)
  self:focus()
  self._navigation = self._navigation + 1
  local generation = self._navigation
  local ready = self._ready
  return ready
    :then_(function(session)
      if not self._disposed and self._ready == ready and generation == self._navigation then
        return session:navigate_path(path, true)
      end
    end)
    :catch(function(error)
      self:_report_ready_error(ready, error)
    end)
end

---@return nil
function M:render_winbar()
  if self._disposed or next(self._tab_wins) == nil then
    return
  end
  local icons = stl.icon.symbols
  local display = self:get_display()
  local labels = {
    icons.flag_selected,
    display.mode == "tree" and icons.flag_tree or icons.flag_list,
    icons.flag_fold_empty_path,
    icons.flag_hidden,
  }
  local flags = {}
  for index, label in ipairs(labels) do
    local enabled = index == 2 or display[DISPLAY_FIELDS[index]]
    local hlname = "f_wl_explorer_flag_grey"
    if enabled then
      hlname = index == 1 and "f_wl_explorer_flag_orange" or "f_wl_explorer_flag_blue"
    end
    local digit = stl.icon.todigit_supscript(index)
    flags[#flags + 1] = "%#" .. hlname .. "#%@v:lua." .. self._callbacks[index] .. "@ " .. label .. digit .. "%X"
  end
  local status, priority = self:status_text()
  local _, path_hl_text, _, detached_hl_text =
    path_display.format(self:get_root_filepath(), "f_wl", priority and "" or status)
  local text = "%#m_ex_winbar# %<"
    .. path_hl_text
    .. detached_hl_text
    .. "%#m_ex_winbar# %="
    .. table.concat(flags)
    .. "%#m_ex_winbar# "
  text = vim.o.showtabline == 0 and text or ""
  for tabnr, winnr in pairs(self._tab_wins) do
    if self:get_winnr(tabnr) == winnr then
      local title = text
      if priority and vim.o.showtabline == 0 then
        local width = vim.api.nvim_win_get_width(winnr)
        local message = path_display.fit_status(status, priority, width)
        title = stl.nvim.fn.txt(message, priority == "error" and "DiagnosticError" or "DiagnosticInfo")
        if vim.api.nvim_strwidth(message) < width - 1 then
          title = title .. "%< " .. path_hl_text .. detached_hl_text
        end
      end
      if self._titles[winnr] ~= title then
        self._titles[winnr] = title
        vim.api.nvim_set_option_value("winbar", title, { win = winnr })
      end
      local highlight = "Normal:m_ex_bg,EndOfBuffer:m_ex_eob,WinBar:m_ex_winbar,WinBarNC:m_ex_winbar,WinSeparator:m_ex_border,TreeviewGuide:m_ex_indent,TreeviewGuideActive:m_ex_indent_active,CursorLine:"
        .. (vim.api.nvim_get_current_win() == winnr and "m_ex_cursorline" or "m_ex_cursorline_blur")
      if self._focus_highlights[winnr] ~= highlight then
        self._focus_highlights[winnr] = highlight
        vim.api.nvim_set_option_value("cursorline", true, { win = winnr })
        vim.api.nvim_set_option_value("winhighlight", highlight, { win = winnr })
      end
    end
  end
  dot.state.status.dirtier_tabline:mark_dirty()
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  local tabs = vim.tbl_keys(self._tab_wins)
  for _, tabnr in ipairs(tabs) do
    self:hide(tabnr)
  end
  self._disposed = true
  for _, subscription in ipairs(self._subscriptions) do
    subscription:unsubscribe()
  end
  for _, unregister in ipairs(self._unregister) do
    unregister()
  end
  vim.api.nvim_del_augroup_by_id(self._group)
  if self._session then
    self._session.owners = self._session.owners - 1
    if self._session.owners == 0 then
      self._session:dispose()
    end
  end
  self._session, self._ready = nil, nil
  if self._on_disposed then
    self._on_disposed()
  end
end

return M
