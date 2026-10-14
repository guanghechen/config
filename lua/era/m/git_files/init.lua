---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git_files" ---@type string

local Tree = require("era.view.git_files")
local Paths = require("era.view.result_paths")
local Result = require("era.view.picker.result")
local Input = require("era.m.git_files.input")
local Preview = require("era.m.git_files.preview")
local Keymaps = require("era.m.git_files.keymaps")
local Numstat = require("era.m.git.numstat")
local transfer = require("era.m.git_files.transfer")
local scopes = { "staged", "unstaged" }

---@alias era.m.git_files.LeftPane "input"|"staged"|"unstaged"

---@class era.m.git_files.IPane
---@field scope                         era.view.git_files.Scope
---@field tree                          era.view.GitFiles
---@field result                        era.view.PickerResult
---@field _position_observer            stl.c.IUnsubscribable

---@class era.m.git_files.IRequest
---@field root                          string
---@field token                         stl.c.CancellationToken
---@field focus                         boolean
---@field future                        ?stl.c.Future

---@class era.m.git_files.Widget
---@field panes                         table<era.view.git_files.Scope, era.m.git_files.IPane>
---@field input                         era.m.git_files.Input
---@field preview                       era.m.git_files.Preview
---@field _request                      ?era.m.git_files.IRequest
---@field _root                         ?string
---@field _origin                       ?integer
---@field _active                       era.view.git_files.Scope
---@field _last_left                    era.m.git_files.LeftPane
---@field _query                        string
---@field _foldempty                    boolean
---@field _preview_enabled              boolean
---@field _disposed                     boolean
---@field _closing                      boolean
---@field _writing                      boolean
---@field _failed                       boolean
---@field _group                        integer
---@field _observer                     stl.c.IUnsubscribable
---@field _bound                        table<integer, boolean>
---@field _keymaps                      stl.t.IKeymap[]
local M = {}
M.__index = M

---@param error                         any
---@param subject                       ?string
---@return nil
local function report(error, subject)
  stl.reporter.warn({ from = __module_name__, subject = subject or "refresh", message = tostring(error) })
end

---@param tree                          era.view.GitFiles
---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@param visual                        boolean
---@return string[]
local function action_keys(tree, frame, first, last, visual)
  if visual then
    local keys = {}
    for _, key in tree:iter_rows(frame, first, last) do
      keys[#keys + 1] = key
    end
    return keys
  end
  if tree:has_selected(frame) then
    return tree:selected_keys(true, frame)
  end
  local key = tree:retrieve_uuid(first, frame)
  return key and { key } or {}
end

---@return era.m.git_files.Widget
function M.new()
  local self = setmetatable({
    panes = {},
    _active = "staged",
    _last_left = "input",
    _query = "",
    _foldempty = true,
    _preview_enabled = true,
    _disposed = false,
    _closing = false,
    _writing = false,
    _failed = false,
    _bound = {},
  }, M)
  local uuid = yoz.fn.uuid()
  self._keymaps = Keymaps.tree(self)
  for _, scope in ipairs(scopes) do
    local pane = { scope = scope, tree = Tree.new("Git Files " .. scope, scope) }
    self.panes[scope] = pane
    pane.result = Result.new({
      name = "Git Files",
      uuid = uuid .. scope,
      tree = pane.tree,
      flags = {},
      winbar = false,
      keymaps = self._keymaps,
      winline_hl = "f_wl_picker",
      diagnostic_scope = scope,
      augroup_prefix = "GitFiles",
      draw = function()
        return pane.tree:render(self._query, self._foldempty)
      end,
      on_drawed = function(bufnr)
        if not self._bound[bufnr] then
          stl.nvim.fn.bindkeys(self._keymaps, { bufnr = bufnr, nowait = true, noremap = true, silent = true })
          self._bound[bufnr] = true
        end
        self:_header(pane)
        self:_update_preview()
      end,
    })
    pane._position_observer = stl.fn.observe({ pane.result.lnum_current, pane.result.lnum_total }, function()
      self:_header(pane)
    end, true)
  end
  self.input = Input.new(Keymaps.input(self), function(pattern)
    if self._disposed or self._query == pattern then
      return
    end
    self._query = pattern
    if self:isvisible() and not self._closing then
      for _, scope in ipairs(scopes) do
        self.panes[scope].result:mark_content_dirty()
      end
    end
  end)
  self.preview = Preview.new(Keymaps.preview(self))
  self._group = vim.api.nvim_create_augroup("GitFiles:" .. uuid, { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = self._group,
    callback = function()
      self:resize()
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = self._group,
    callback = function()
      if self:isvisible() then
        self:refresh(false)
      end
    end,
  })
  vim.api.nvim_create_autocmd("TabLeave", {
    group = self._group,
    callback = function()
      self:hide(false)
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = self._group,
    callback = function()
      if self.input:isfocused() then
        self._last_left = "input"
        return
      end
      for _, scope in ipairs(scopes) do
        if self.panes[scope].result:isfocused() then
          self._active, self._last_left = scope, scope
          self:_update_preview()
          break
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self._group,
    callback = function()
      self:_update_preview()
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = self._group,
    callback = function(args)
      if self._closing or self._disposed then
        return
      end
      local winnr = tonumber(args.match)
      if self.input:get_winnr() == winnr then
        self:hide(false)
        return
      end
      for _, scope in ipairs(scopes) do
        if self.panes[scope].result:get_winnr() == winnr then
          self:hide(false)
          return
        end
      end
      if self.preview.surface:get_winnr() == winnr then
        self._preview_enabled = false
        self.preview:hide()
        self:resize()
      end
    end,
  })
  self._observer = stl.fn.observe({ era.m.git.state.o_refreshed }, function()
    if not self._writing and self:isvisible() then
      self:refresh(false)
    end
  end, true)
  return self
end

---@return boolean
function M:isvisible()
  return not self._disposed
    and (self.input:isvisible() or self.panes.staged.result:isvisible() or self.panes.unstaged.result:isvisible())
end

---@return boolean
function M:isfocused()
  return self:isvisible()
    and (
      self.input:isfocused()
      or self.panes.staged.result:isfocused()
      or self.panes.unstaged.result:isfocused()
      or self.preview.surface:isfocused()
    )
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param scope                         era.m.git_files.LeftPane
---@return nil
function M:focus(scope)
  if self.input:isfocused() and scope ~= "input" then
    self.input:sync()
    vim.cmd.stopinsert()
  end
  self._last_left = scope
  if scope == "input" then
    self.input:focus()
  else
    ---@cast scope era.view.git_files.Scope
    self._active = scope
    self.panes[scope].result:focus()
  end
  self:_update_preview()
end

---@param direction                     "h"|"j"|"k"|"l"
---@return nil
function M:navigate(direction)
  if not self:isfocused() then
    return
  end
  local preview = self.preview.surface
  local from_preview = preview:isfocused()
  local from_input = self.input:isfocused()
  local current = from_input and "input" or self._active
  if from_preview then
    if direction == "h" then
      self:focus(self._last_left)
      return
    end
  elseif direction == "j" and current ~= "unstaged" then
    self:focus(current == "input" and "staged" or "unstaged")
    return
  elseif direction == "k" and current ~= "input" then
    self:focus(current == "unstaged" and "staged" or "input")
    return
  elseif direction == "l" and preview:isvisible() then
    if from_input then
      self.input:sync()
      vim.cmd.stopinsert()
    end
    preview:focus()
    return
  end
  if stl.env.IS_TMUX and not dot.state.status.tmux_zen_mode:snapshot() then
    stl.tmux.change_pane(direction)
    return
  end
  if from_preview and direction == "l" then
    self:focus(self._last_left)
  elseif not from_preview and (direction == "j" or direction == "k") then
    self:focus(direction == "j" and "input" or "unstaged")
  end
end

---@return nil
function M:_cancel()
  local request = self._request
  self._request = nil
  if request then
    request.token:cancel()
  end
end

---@param restore                       ?boolean
---@return nil
function M:hide(restore)
  if self._disposed or self._closing then
    return
  end
  local focused = self:isfocused()
  self._closing = true
  self:_cancel()
  if self.input:isfocused() then
    vim.cmd.stopinsert()
  end
  self.input:sync()
  self.input:hide()
  self.preview:hide()
  for _, scope in ipairs(scopes) do
    self.panes[scope].result:hide()
  end
  self._closing = false
  if restore ~= false and focused and self._origin and vim.api.nvim_win_is_valid(self._origin) then
    vim.api.nvim_set_current_win(self._origin)
  end
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self:hide(false)
  self._disposed = true
  self._observer:unsubscribe()
  vim.api.nvim_del_augroup_by_id(self._group)
  self.input:dispose()
  self.preview:dispose()
  for _, scope in ipairs(scopes) do
    self.panes[scope]._position_observer:unsubscribe()
    self.panes[scope].result:dispose()
    self.panes[scope].tree:dispose()
  end
end

---@return nil
function M:toggle()
  if self._disposed then
    return
  end
  if self:isfocused() then
    self:hide()
    return
  end
  if self:isvisible() then
    self:focus(self._last_left)
    return
  end
  if self._request then
    self._request.focus = true
    return
  end
  self._origin = vim.api.nvim_get_current_win()
  self:refresh(true)
end

---@param request                       era.m.git_files.IRequest
---@return boolean
function M:_current(request)
  return not self._disposed
    and self._request == request
    and not request.token:is_cancelled()
    and request.root == dot.path.workspace()
end

---@param focus                         boolean
---@return stl.c.Future|nil
function M:refresh(focus)
  local previous_focus = self._request and self._request.focus
  self:_cancel()
  if self._disposed then
    return
  end
  if not dot.path.is_git_repo() then
    if focus then
      report("Not a git repository")
    end
    self:hide()
    return
  end
  local request =
    { root = dot.path.workspace(), token = stl.c.CancellationToken.new(), focus = focus or previous_focus or false }
  self._request = request
  for _, scope in ipairs(scopes) do
    self:_header(self.panes[scope])
  end
  local future = stl.async.run_future(function()
    local snapshot = era.m.git.status.collect({ include_numstat = true }, request.token):await()
    if not self:_current(request) then
      return
    end
    local data = snapshot:export()
    local staged, unstaged = snapshot:changed_files()
    local untracked = {}
    for _, path in ipairs(unstaged) do
      local entry = data.status_map[path]
      if entry.unstaged["?"] then
        untracked[#untracked + 1] = entry.relative
      end
    end
    local auxiliary = Numstat.collect_untracked(request.root, untracked, request.token)
    if not self:_current(request) then
      return
    end
    if auxiliary then
      for path, stat in pairs(Numstat.parse(auxiliary.lines)) do
        data.numstats.unstaged[path] = stat
      end
    end
    local deadline = vim.uv.hrtime() + 2000000
    ---@return nil
    local function checkpoint()
      if vim.uv.hrtime() >= deadline then
        stl.async.scheduler()
        deadline = vim.uv.hrtime() + 2000000
      end
      if not self:_current(request) then
        error("Git Files refresh superseded", 0)
      end
    end
    local prepared = {
      staged = self.panes.staged.tree:prepare(request.root, staged, data, checkpoint),
      unstaged = self.panes.unstaged.tree:prepare(request.root, unstaged, data, checkpoint),
    }
    local columns = Tree.measure_columns({ prepared.staged.totals, prepared.unstaged.totals })
    for _, scope in ipairs(scopes) do
      for column, width in pairs(columns) do
        prepared[scope].columns[column] = width
      end
    end
    checkpoint()
    local changed_workspace = self._root ~= request.root
    if changed_workspace then
      self._query = ""
      self.input:set_content("")
    end
    for _, scope in ipairs(scopes) do
      if changed_workspace then
        self.panes[scope].tree.root = nil
      end
      self.panes[scope].tree:apply(prepared[scope])
    end
    self._root = request.root
    for _, scope in ipairs(scopes) do
      local reply = self.panes[scope].tree:render(self._query, self._foldempty):await()
      if reply.kind == "Rejected" then
        error(reply.error)
      end
      if not self:_current(request) then
        return
      end
    end
    self._failed = false
    if request.focus then
      self:_show()
      self._active = self.panes.staged.tree.totals.count > 0 and "staged" or "unstaged"
      self:focus("input")
    end
    self:_update_preview(true)
  end)
  request.future = future
  future:finally(function(ok, failure)
    local current = self:_current(request)
    if self._request == request then
      self._request = nil
    end
    if not current then
      return
    end
    self._failed = not ok
    if not ok then
      report(failure)
    end
    for _, scope in ipairs(scopes) do
      self:_header(self.panes[scope])
    end
  end)
  return future
end

---@return nil
function M:_show()
  self:_layout()
end

---@return nil
function M:resize()
  if self:isvisible() then
    self:_layout()
  end
end

---@return nil
function M:_layout()
  local preview = self._preview_enabled and vim.o.columns >= 88
  local width = math.max(8, math.min(preview and 182 or 122, vim.o.columns - 4))
  local height = math.max(9, math.floor((vim.o.lines - 2) * 0.9))
  local row, col = math.max(0, math.floor((vim.o.lines - height - 2) / 2)), math.floor((vim.o.columns - width) / 2)
  local left = preview and math.floor(width * 0.48) or width
  local top = math.floor((height - 5) / 2)
  -- Lower panes own horizontal separators; left panes own the divider beside preview.
  self.input:show(
    { row = row, col = col, width = left - 2, height = 1 },
    { "╭", "─", preview and "┬" or "╮", "│", "", "", "", "│" }
  )
  for index, scope in ipairs(scopes) do
    local pane = self.panes[scope]
    local dimension = {
      row = row + 2 + (index == 1 and 0 or top + 1),
      col = col,
      width = left - 2,
      height = index == 1 and top or height - top - 5,
    }
    local border = index == 1 and { "├", "─", "┤", "│", "", "", "", "│" }
      or { "├", "─", "┤", "│", preview and "┴" or "╯", "─", "╰", "│" }
    local winnr = pane.result:create_win({
      border = border,
      number = true,
      winhighlight = "Normal:m_pk_result_normal,CursorLine:m_pk_result_current,FloatBorder:FloatBorder,TreeviewMatch:m_pk_matches",
      zindex = 50,
    }, dimension)
    pane.result:resize(dimension)
    vim.api.nvim_win_set_config(winnr, { border = border })
    self:_header(pane)
  end
  if preview then
    local dimension = { row = row, col = col + left, width = width - left - 1, height = height - 2 }
    local border = { "", "─", "╮", "│", "╯", "─", "", "" }
    local winnr = self.preview.surface:create_win({
      border = border,
      winhighlight = "Normal:m_pk_preview_normal,CursorLine:m_pk_preview_current,FloatBorder:FloatBorder,FloatTitle:m_pk_preview_title",
      zindex = 50,
    }, dimension)
    self.preview.surface:resize(dimension)
    vim.api.nvim_win_set_config(winnr, { border = border })
    self:_update_preview()
  else
    self.preview:hide()
  end
end

---@param pane                          era.m.git_files.IPane
---@return nil
function M:_header(pane)
  if self._disposed then
    return
  end
  local winnr, totals = pane.result:get_winnr(), pane.tree.totals
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return
  end
  local name = pane.scope == "staged" and "Staged" or "Unstaged"
  local title = { { " " .. name, pane.scope == "staged" and "m_ft_git_staged" or "m_ft_git_unstaged" } }
  local status = self._writing and "Updating index…"
    or self._request and "Refreshing…"
    or self._failed and "Refresh failed"
  if status then
    title[#title + 1] = { " · " .. status, status == "Refresh failed" and "m_ft_git_delete" or "m_ft_git_other" }
  end
  if totals then
    title[#title + 1] = { " · " .. totals.count .. " files", "FloatTitle" }
    title[#title + 1] = { "  +" .. totals.insertions, "m_ft_git_add" }
    title[#title + 1] = { " -" .. totals.deletions, "m_ft_git_delete" }
    if totals.unknown > 0 then
      title[#title + 1] = { " · " .. totals.unknown .. " unknown", "m_ft_git_other" }
    end
  end
  title[#title + 1] = { " ", "FloatTitle" }
  local total = pane.result.lnum_total:snapshot()
  local current = math.min(pane.result.lnum_current:snapshot(), total)
  local position = string.format(" %d / %d ", current, total)
  local width = vim.api.nvim_win_get_width(winnr)
  local available = math.max(0, width - #position - 1)
  local fitted, used = {}, 0
  for _, chunk in ipairs(title) do
    if used >= available then
      break
    end
    local text = chunk[1]
    if vim.api.nvim_strwidth(text) > available - used then
      text = vim.fn.strcharpart(text, 0, available - used - 1) .. "…"
    end
    fitted[#fitted + 1] = { text, chunk[2] }
    used = used + vim.api.nvim_strwidth(text)
  end
  fitted[#fitted + 1] = { string.rep("─", math.max(0, width - used - #position)), "FloatBorder" }
  fitted[#fitted + 1] = { position, "FloatTitle" }
  vim.api.nvim_win_set_config(winnr, {
    title = fitted,
    title_pos = "left",
  })
end

---@return era.m.git_files.IPane
---@return string|nil
---@return era.view.result_paths.IFile|nil
---@return era.view.git_files.IEntry|nil
function M:current()
  local pane = self.panes[self._active]
  local winnr = pane.result:get_winnr()
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return pane
  end
  local frame = pane.tree:frame()
  local key = frame and pane.tree:retrieve_uuid(vim.api.nvim_win_get_cursor(winnr)[1], frame)
  local data = key and pane.tree:data(key, frame)
  local entry = key and pane.tree:retrieve(key, frame)
  ---@cast data era.view.result_paths.IFile|nil
  ---@cast entry era.view.git_files.IEntry|nil
  return pane, key, data, entry
end

---@param force                         ?boolean
---@return nil
function M:_update_preview(force)
  if self._disposed or not self.preview or not self.preview.surface:isvisible() then
    return
  end
  local _, _, _, entry = self:current()
  self.preview:update(self._root, entry and entry.nodetype == "leaf" and entry.git or nil, force)
end

---@return nil
function M:toggle_preview()
  self._preview_enabled = not self._preview_enabled
  if not self._preview_enabled and self.preview.surface:isfocused() then
    self:focus(self._last_left)
  end
  self:resize()
end

---@return nil
function M:activate()
  local pane, key, data, entry = self:current()
  if not key or not data or not entry then
    return
  end
  if entry.nodetype == "container" then
    pane.tree:collapse(key, "toggle")
    return
  end
  if not vim.uv.fs_stat(yoz.canonical_path.to_os_path(data.filepath)) then
    report("File is absent from the worktree: " .. vim.fn.strtrans(data.filepath), "open")
    return
  end
  local tabnr = vim.api.nvim_get_current_tabpage()
  local winnr = dot.tab.retrieve_winnr_sourcefile(tabnr)
  self:hide()
  dot.win.open_filepath(winnr, data.filepath)
end

---@return nil
function M:collapse()
  local pane, key, _, entry = self:current()
  if not key or not entry then
    return
  end
  if entry.nodetype == "container" and not entry.collapsed then
    pane.tree:collapse(key, "collapse")
  elseif pane.tree.view then
    pane.tree.view:navigate("parent")
  end
end

---@param where                         "cursor"|"parent"|"workspace"
---@return nil
function M:root(where)
  local pane, key, _, entry = self:current()
  if where == "workspace" then
    key = self._root and Paths.key(self._root)
  elseif where == "parent" then
    key = pane.tree.root and pane.tree.source:parent(pane.tree.root)
  elseif not entry or entry.nodetype ~= "container" then
    return
  end
  local data = key and pane.tree.source:get(key)
  if
    not data
    or not self._root
    or (data.filepath ~= self._root and data.filepath:sub(1, #self._root + 1) ~= self._root .. "/")
  then
    return
  end
  pane.tree.root = key
  pane.result:mark_content_dirty()
end

---@param scope                         era.view.git_files.Scope
---@return stl.c.Future|nil
function M:transfer(scope)
  local pane = self.panes[scope]
  if
    self._writing
    or self._failed
    or self._request
    or not pane.result:isfocused()
    or self._root ~= dot.path.workspace()
  then
    return
  end
  if pane.tree:after_selection(function()
    self:transfer(scope)
  end) then
    return
  end
  if not pane.tree.view then
    return
  end
  return pane.tree.view:range_action(function(frame, first, last, visual)
    local keys = action_keys(pane.tree, frame, first, last, visual)
    local entries = pane.tree:targets(keys, frame)
    if #entries == 0 then
      return stl.c.Future.resolve({ kind = "NoChange" })
    end
    return self:_transfer_entries(pane, keys, entries):map(function()
      return { kind = "NoChange" }
    end)
  end, false)
end

---@param pane                          era.m.git_files.IPane
---@param keys                          string[]
---@param entries                       era.view.git_files.IMetadata[]
---@return stl.c.Future
function M:_transfer_entries(pane, keys, entries)
  local root, scope = assert(self._root), pane.scope
  local selection = pane.tree:frame():header().selection_revision
  self._writing = true
  for _, side in ipairs(scopes) do
    self:_header(self.panes[side])
  end
  local future = transfer(root, scope, entries)
  future:finally(function(ok, result)
    self._writing = false
    if not ok then
      report(result, scope == "staged" and "unstage" or "stage")
    end
    if self._disposed then
      return
    end
    if
      ok
      and self._root == root
      and not pane.tree:selection_pending()
      and pane.tree:frame():header().selection_revision == selection
    then
      for _, key in ipairs(keys) do
        pane.tree:set_selected(key, false)
      end
    end
    if self:isvisible() and self._root == root and root == dot.path.workspace() then
      local refreshing = self:refresh(false)
      if refreshing then
        refreshing:map(function()
          if not self._disposed and pane.result:isfocused() and pane.tree.totals.count == 0 then
            self:focus(scope == "staged" and "unstaged" or "staged")
          end
        end)
      end
    end
    if ok and root == dot.path.workspace() then
      era.m.git.state.refresh_index():catch(function(error)
        report(error)
      end)
    end
  end)
  return future
end

---@return stl.c.Future|nil
function M:copy_paths()
  local pane = self:current()
  if
    pane.tree:after_selection(function()
      if pane.result:isfocused() then
        self:copy_paths()
      end
    end)
  then
    return
  end
  if not pane.tree.view then
    return
  end
  local paths = {}
  return pane.tree.view
    :range_action(function(frame, first, last, visual)
      for _, key in ipairs(action_keys(pane.tree, frame, first, last, visual)) do
        local data = pane.tree:data(key, frame)
        if data then
          paths[#paths + 1] = data.filepath
        end
      end
      return stl.c.Future.resolve({ kind = "NoChange" })
    end)
    :map(function()
      if not self._disposed and #paths > 0 then
        era.fn.select_copy_filepaths({ filepaths = paths, relative = "cursor", row = 1, col = 4 })
      end
    end)
end

---@return nil
function M:filter()
  self.input:set_content(self._query)
  self:focus("input")
  vim.cmd.startinsert()
end

---@param action                        "explorer"|"find"|"search"|"system"|"quickfix"
---@return nil
function M:browse(action)
  local pane, key, data = self:current()
  if not data then
    return
  end
  if action == "quickfix" then
    local keys = pane.tree:has_selected() and pane.tree:selected_keys(true) or { key }
    local items = {}
    for _, entry in ipairs(pane.tree:targets(keys)) do
      items[#items + 1] = { filename = self._root .. "/" .. entry.path, lnum = 1 }
    end
    self:hide()
    vim.fn.setqflist({}, "r", { title = "Git Files", items = items })
    vim.cmd.copen()
    return
  end
  local path = data.filetype == "directory" and data.filepath or yoz.canonical_path.dirname(data.filepath, false)
  if action == "system" then
    vim.ui.open(yoz.canonical_path.to_os_path(data.filepath))
    return
  end
  self:hide()
  if action == "explorer" then
    era.fn.find_explorer(path)
  elseif action == "find" then
    era.fn.find_files(path, true)
  else
    era.fn.search_in_files(path)
  end
end

return M
