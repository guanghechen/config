---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.action" ---@type string

local async = require("stl.async")
local Session = require("era.m.explorer.session")
local filepath = require("ux.filetree.path")

---@class era.m.explorer.Action
---@field _widget                       era.m.explorer.Widget
---@field _info_sequence                integer
---@field _navigation                   ?{ view: ux.filetree.View, generation: integer|nil, tail: stl.c.Future|nil }
local M = {}
M.__index = M

---@param widget                        era.m.explorer.Widget
---@return era.m.explorer.Action
function M.new(widget)
  return setmetatable({ _widget = widget, _info_sequence = 0 }, M)
end

---@async
---@param session                       era.m.explorer.Session
---@param view                          ux.filetree.View
---@param range                         ?era.m.explorer.IInputRange
---@return yoz.ux.filetree.Resource[]|nil
local function sources(session, view, range)
  local data = session.data
  local value, source
  if range then
    value = Session.await(session:inspect_range(range))
    source = value.source
  else
    if session.preparing then
      error("Explorer already has an active operation", 0)
    end
    local cursor = session:cursor(view)
    value = Session.await(require("era.m.explorer.jobs").resolve_selection(session))
    if not value or session._disposed or view._closed then
      return nil
    end
    local summary = value.summary
    if summary.known_roots == 0 and summary.known_self_only == 0 then
      return cursor and { cursor } or {}
    end
    source = value.source
  end
  local result = {}
  for first = 1, value.subtree_roots:len(), 128 do
    if session._disposed or view._closed then
      return nil
    end
    for _, node in ipairs(value.subtree_roots:slice(first, math.min(first + 127, value.subtree_roots:len()))) do
      result[#result + 1] = data:inspect(source, node)
    end
    async.scheduler()
  end
  return result
end

---@async
---@param strategy                      ?string
---@param paths                         string[]
---@return nil
local function open_paths(strategy, paths)
  if #paths == 0 then
    return
  end
  local original = vim.api.nvim_get_current_win()
  local winnr
  if strategy == "tab" then
    vim.cmd.tabnew()
    winnr = vim.api.nvim_get_current_win()
    vim.t[vim.api.nvim_get_current_tabpage()].tabtype = stl.e.TabTypeEnum.NORMAL
  else
    local candidate
    if not strategy then
      candidate = dot.tab.retrieve_winnr_sourcefile(vim.api.nvim_get_current_tabpage())
    end
    winnr = dot.win.pick_sourcefile(candidate)
    if not winnr then
      return
    end
    if strategy == "split" or strategy == "vsplit" then
      vim.api.nvim_set_current_win(winnr)
      vim.cmd(strategy)
      winnr = vim.api.nvim_get_current_win()
    end
  end
  local last
  local started = vim.uv.hrtime()
  for _, path in ipairs(paths) do
    if not vim.api.nvim_win_is_valid(winnr) then
      return
    end
    local bufnr = dot.buf.loadfile(path)
    if bufnr then
      last = bufnr
      dot.win.on_buf_enter(winnr, bufnr)
      dot.tab.on_buf_enter(vim.api.nvim_win_get_tabpage(winnr), bufnr)
    end
    if vim.uv.hrtime() - started > 2000000 then
      async.scheduler()
      started = vim.uv.hrtime()
    end
  end
  if last and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_buf(winnr, last)
    vim.api.nvim_set_current_win(winnr)
  elseif vim.api.nvim_win_is_valid(original) then
    vim.api.nvim_set_current_win(original)
  end
end

---@param strategy                      ?string
---@param resource                      ?yoz.ux.filetree.Resource
---@return stl.c.Future
function M:open(strategy, resource)
  local session, view = self._widget:context()
  local frame = view:frame()
  return async.run_future(function()
    local resources = resource and { resource } or sources(session, view)
    if not resources or view._closed then
      return
    end
    if not strategy and not session:mode() and #resources == 1 and resources[1]:info().directory then
      if frame and frame:header().mode == "tree" then
        Session.await(session:fold(frame, resources[1]:node(), "toggle"))
      end
      return
    end
    local paths = {}
    for _, resource in ipairs(resources) do
      local info = resource:info()
      if info.kind == "file" or info.target_kind == "file" then
        paths[#paths + 1] = resource:path()
      end
    end
    open_paths(strategy, paths)
  end)
end

---@return stl.c.Future|nil
function M:activate()
  local _, view = self._widget:context()
  local frame = view:frame()
  if frame and frame:header().mode == "tree" then
    local row = vim.api.nvim_win_get_cursor(view.winnr)[1]
    if frame:node_at(row) and frame:rows(row, row).can_expand[1] then
      return self:_fold("toggle")
    end
  end
  view:activate()
end

---@param mark                          "toggle"|"select"|"copy"|"cut"
---@return stl.c.Future
function M:mark(mark)
  local session, view = self._widget:context()
  return session:mark(view, mark)
end

---@return stl.c.Future
function M:cancel_transfer_or_clear_selection()
  local session, view = self._widget:context()
  if view:_visual_mode() then
    vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
  end
  return session:cancel_transfer_or_clear_selection()
end

---@param mark                          "copy"|"cut"
---@return stl.c.Future|nil
function M:transfer(mark)
  local session, view = self._widget:context()
  local frame = view:frame()
  if not frame then
    return nil
  end
  if session:mode(frame) then
    return self:mark(mark)
  end
  local resource = session:cursor(view)
  if not resource then
    return nil
  end
  local path = resource:path()
  local directory = resource:info().directory
  if mark == "copy" then
    local name = filepath.basename(path)
    local extension = directory and "" or filepath.extname(name)
    if #extension == #name then
      extension = ""
    end
    path = path:sub(1, #path - #extension) .. "-copy" .. extension
  end
  if directory then
    path = path .. "/"
  end
  return session:operate(view, {
    kind = mark == "copy" and "copy_to_path" or "move_to_path",
    default_path = filepath.relative(filepath.from_os(dot.path.cwd()), path),
    cursor = { frame = frame, resource = resource },
  })
end

---@param direction                     string
---@return nil
function M:navigate(direction)
  local _, view = self._widget:context()
  view:navigate(direction)
end

---@param kind                          "toggle"|"recursive"|"collapse"
---@return stl.c.Future|nil
function M:_fold(kind)
  local session, view = self._widget:context()
  local frame = view:frame()
  if not view:_valid() or view._desynced or view._publishing or not frame or frame:header().mode ~= "tree" then
    return
  end
  local node = frame:node_at(vim.api.nvim_win_get_cursor(view.winnr)[1])
  if node then
    return session:fold(frame, node, kind)
  end
end

---@return stl.c.Future|nil
function M:collapse()
  return self:_fold("collapse")
end

---@return stl.c.Future|nil
function M:recursive()
  return self:_fold("recursive")
end

---@return stl.c.Future|nil
function M:collapse_all()
  local session, view = self._widget:context()
  local frame = view:frame()
  if frame and frame:header().mode == "tree" then
    return session.state:set_expanded({ frame:header().root.node }, false, true)
  end
end

---@param action                        fun(session: era.m.explorer.Session, view: ux.filetree.View): stl.c.Future|nil
---@return stl.c.Future
function M:_navigate(action)
  local session, view = self._widget:context()
  session.state:note_navigation()
  local queue = self._navigation
  if not queue or queue.view ~= view or queue.generation ~= session._navigation_generation then
    queue = { view = view, generation = session._navigation_generation }
    self._navigation = queue
  end
  local previous = queue.tail
  local future = async.run_future(function()
    if previous then
      pcall(previous.await, previous)
    end
    if
      self._navigation ~= queue
      or not view:_valid()
      or session._disposed
      or queue.generation ~= session._navigation_generation
    then
      return { kind = "NoChange" }
    end
    local pending = action(session, view)
    queue.generation = session._navigation_generation
    return pending and Session.await(pending) or { kind = "NoChange" }
  end)
  queue.tail = future
  future:finally(function()
    if self._navigation == queue and queue.tail == future then
      self._navigation = nil
    end
  end)
  return future
end

---@param target                        "parent"|"cursor"|"previous"|"cwd"|"workspace"
---@return stl.c.Future
function M:root(target)
  return self:_navigate(function(session, view)
    if target == "cwd" then
      return session:navigate_path(filepath.from_os(dot.path.cwd()), false)
    end
    local node
    if target == "workspace" then
      return session:navigate_path(session.native:workspace_path(), false)
    elseif target == "previous" then
      node = session.native:previous()
    elseif target == "cursor" then
      node = session:target(view):node()
    else
      local frame = session.state:snapshot()
      local root = frame:header().root.node
      local entry = frame:source():node(root)
      if not entry then
        return session:navigate_path(filepath.dirname(self._widget:get_root_filepath()), false)
      end
      -- Resolve relative intent on the owner; even native snapshots can lag its last commit.
      return session:navigate_parent()
    end
    if node then
      return session:navigate(node, false)
    end
  end)
end

---@param kind                          "git"|"diagnostic"|"error"|"warning"
---@param forward                       boolean
---@return stl.c.Future
function M:annotation(kind, forward)
  return self:_navigate(function(session, view)
    return async.run_future(function()
      local frame = view:frame()
      if not frame then
        return
      end
      local queue = self._navigation
      local row = vim.api.nvim_win_get_cursor(view.winnr)[1]
      local target = Session.await(session.data:next_annotation(frame, row, kind, forward))
      local current = view:frame()
      if
        not view:_valid()
        or not current
        or self._navigation ~= queue
        or queue.generation ~= session._navigation_generation
        or current:header().layout_revision ~= frame:header().layout_revision
        or vim.api.nvim_win_get_cursor(view.winnr)[1] ~= row
      then
        if self._navigation == queue then
          self._navigation = nil
        end
        return
      end
      if target == 0 then
        Session.report("No matching " .. kind .. " in the current view")
        return
      end
      return Session.await(view:set_cursor(target))
    end)
  end)
end

---@param request                       era.m.explorer.IJobRequest
---@return stl.c.Future
function M:operate(request)
  local session, view = self._widget:context()
  return session:operate(view, request)
end

---@param directory                     boolean
---@return stl.c.Future
function M:create(directory)
  local session, view = self._widget:context()
  return session:operate(view, {
    kind = "create",
    directory = directory,
    on_complete = function(status, results)
      if status.error or status.cancelled or view._closed then
        return
      end
      local item = results[#results]
      if not item then
        return
      end
      if not item.target then
        session:navigate(item.node, true):catch(Session.report)
        Session.report("Created " .. item.target_label .. "; its path cannot be represented by Neovim")
        return
      end
      async
        .run_future(function()
          -- Creation already published this occurrence; retain its logical path without resolving it again.
          Session.await(session:navigate(item.node, true))
          if view._closed then
            return
          end
          local resource = session.data:inspect(session.data:source(), item.node)
          if resource:info().kind == "file" then
            open_paths(nil, { resource:path() })
          end
        end)
        :catch(Session.report)
    end,
  })
end

---@return stl.c.Future
function M:delete()
  local session, view = self._widget:context()
  if view:_visual_mode() then
    return view:range_action(function(frame, first, last)
      return session
        :operate(view, { kind = "delete", range = { frame = frame, first = first, last = last } })
        :map(function()
          return { kind = "NoChange" }
        end)
    end, false)
  end
  return session:operate(view, { kind = "delete" })
end

---@param kind                          string
---@return stl.c.Future
function M:auxiliary(kind)
  local session, view = self._widget:context()
  if kind == "info" then
    local resource = session:cursor(view)
    self._info_sequence = self._info_sequence + 1
    local sequence = self._info_sequence
    local focus_revoked = false
    local focus_watch
    ---@return nil
    local function clear_focus_watch()
      if focus_watch then
        vim.api.nvim_del_autocmd(focus_watch)
        focus_watch = nil
      end
    end
    if resource then
      focus_watch = vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
        buf = view.bufnr,
        callback = function()
          focus_revoked = true
          clear_focus_watch()
        end,
      })
    end
    return async.run_future(function()
      if not resource then
        return { kind = "NoChange" }
      end
      local ok, details = pcall(function()
        return Session.await(session.data:details(resource))
      end)
      clear_focus_watch()
      if
        sequence ~= self._info_sequence
        or focus_revoked
        or session._disposed
        or not view:_valid()
        or vim.api.nvim_get_current_win() ~= view.winnr
      then
        return { kind = "NoChange" }
      end
      if not ok then
        error(details, 0)
      end
      local info = resource:info()
      require("era.view.fileinfo").new({ filepath = resource:path(), kind = info.kind, details = details }):open()
      return { kind = "NoChange" }
    end)
  end
  ---@async
  ---@param range                       ?era.m.explorer.IInputRange
  ---@return ux.treeview.IReply|nil
  local function run(range)
    local cursor = session:cursor(view)
    if kind == "find" or kind == "directory" then
      local path = session:target(view):path()
      if kind == "find" then
        era.fn.find_files(path, true)
      else
        era.fn.find_explorer(path)
      end
      return
    elseif kind == "search" then
      era.fn.search_in_files((cursor or session:root(view:frame())):path())
      return
    end
    local resources = sources(session, view, range)
    if not resources or view._closed then
      return
    end
    local paths = {}
    for _, resource in ipairs(resources) do
      paths[#paths + 1] = resource:path()
    end
    if kind == "copy_path" then
      era.fn.select_copy_filepaths({ filepaths = paths, winopts = { relative = "cursor", row = 1, col = 4 } })
    elseif kind == "quickfix" then
      local items = {}
      for _, path in ipairs(paths) do
        items[#items + 1] = { filename = path, lnum = 1, col = 1 }
      end
      vim.fn.setqflist({}, "r", { title = "Explorer", items = items })
      vim.cmd.copen()
    elseif kind == "ai" then
      local locations = {}
      for _, path in ipairs(paths) do
        locations[#locations + 1] = { filepath = path }
      end
      era.fn.add_locations_to_ai(locations)
    elseif kind == "system" then
      for _, path in ipairs(paths) do
        vim.ui.open(filepath.to_os(path))
      end
    end
    return { kind = "NoChange" }
  end
  if kind == "ai" and view:_visual_mode() then
    return view:range_action(function(frame, first, last)
      return async.run_future(function()
        return run({ frame = frame, first = first, last = last })
      end)
    end, false)
  end
  return async.run_future(run)
end

---@return nil
function M:menu()
  local session, view = self._widget:context()
  local entries = session:busy() and { "Progress", "Cancel operation" }
    or { "Clear selection", "Copy to path", "Move to path", "Copy to directory", "Move to directory", "Last results" }
  vim.ui.select(entries, { prompt = "Explorer actions" }, function(choice)
    if session._disposed or view._closed then
      return
    end
    if choice == "Clear selection" then
      session.state:clear_selection():catch(Session.report)
    elseif choice == "Cancel operation" then
      require("era.m.explorer.jobs").cancel(session)
    elseif choice == "Progress" or choice == "Last results" then
      if session.preparing then
        stl.reporter.info({ from = __module_name__, message = session:status_text() })
        return
      end
      local progress = session.progress
      local lines = { session:result_text() }
      if session:busy() then
        lines[#lines + 1] = session:status_text()
      end
      for _, item in ipairs(#session.issues > 0 and session.issues or session.results) do
        lines[#lines + 1] = item.status
          .. ": "
          .. item.source_label
          .. (item.target_label and " → " .. item.target_label or "")
        if item.error then
          lines[#lines + 1] = "  " .. item.error.message
        end
        if item.sync_error then
          lines[#lines + 1] = "  Synchronization: " .. item.sync_error.message
        end
        if item.editor_error then
          lines[#lines + 1] = "  Editor synchronization: " .. item.editor_error.message
          if item.editor_error.failures > 1 then
            lines[#lines + 1] =
              string.format("  %d editor synchronization failures; first shown.", item.editor_error.failures)
          end
        end
      end
      if session.issues_omitted > 0 then
        lines[#lines + 1] = string.format("%d additional issues omitted from retained history.", session.issues_omitted)
      end
      if progress and progress.error then
        lines[#lines + 1] = progress.error.message
      end
      if progress and type(progress.cleanup) == "table" then
        lines[#lines + 1] = "Selection cleanup: " .. progress.cleanup.message
      end
      stl.reporter.info({
        from = __module_name__,
        message = table.concat(lines, "\n"),
      })
    elseif choice == "Copy to path" or choice == "Move to path" then
      session
        :operate(view, { kind = choice == "Copy to path" and "copy_to_path" or "move_to_path" })
        :catch(Session.report)
    elseif choice == "Copy to directory" or choice == "Move to directory" then
      session
        :operate(view, { kind = choice == "Copy to directory" and "copy_to_directory" or "move_to_directory" })
        :catch(Session.report)
    end
  end)
end

return M
