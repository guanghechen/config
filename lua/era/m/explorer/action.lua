---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.action" ---@type string

local async = require("stl.async")
local Session = require("era.m.explorer.session")

---@class era.m.explorer.Action
---@field _widget                       era.m.explorer.Widget
local M = {}
M.__index = M

---@param widget                        era.m.explorer.Widget
---@return era.m.explorer.Action
function M.new(widget)
  return setmetatable({ _widget = widget }, M)
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
    source = range.frame:source()
  else
    if session.preparing then
      error("Explorer already has an active operation", 0)
    end
    local cursor = session:cursor(view)
    value = Session.await(session.state:inspect_selection())
    local summary = value.summary
    if summary.pending then
      value = Session.await(require("era.m.explorer.jobs").resolve_selection(session, value.revisions.selection))
      if not value then
        return nil
      end
      source = value.source
    elseif summary.known_roots == 0 and summary.known_self_only == 0 then
      return cursor and { cursor } or {}
    else
      source = data:source()
      if source:revision() ~= value.revisions.data then
        error("Explorer selection changed; retry the action", 0)
      end
    end
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
---@param candidate                     ?integer
---@return nil
local function open_paths(strategy, paths, candidate)
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
    if not strategy and not candidate then
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
        Session.await(
          session.state:dispatch(
            { kind = "toggle_expanded", node = resources[1]:node(), recursive = false },
            { frame = frame }
          )
        )
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

---@return nil
function M:activate()
  local _, view = self._widget:context()
  view:activate()
end

---@param mark                          "toggle"|"select"|"copy"|"cut"
---@return stl.c.Future
function M:mark(mark)
  local session, view = self._widget:context()
  return session:mark(view, mark)
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
    local pattern = stl.env.IS_WIN and "[^/\\]+$" or "[^/]+$"
    local name = assert(path:match(pattern))
    local extension = directory and "" or yoz.path.extname(name)
    if #extension == #name then
      extension = ""
    end
    path = path:sub(1, #path - #extension) .. "-copy" .. extension
  end
  if directory then
    path = path .. "/"
  end
  return session:operate(view, mark == "copy" and "copy" or "move", {
    to_path = true,
    default_path = dot.path.relative(dot.path.cwd(), path, "/"),
    selection_revision = frame:header().selection_revision,
  })
end

---@param direction                     string
---@return nil
function M:navigate(direction)
  local _, view = self._widget:context()
  view:navigate(direction)
end

---@return stl.c.Future|nil
function M:collapse()
  local session, view = self._widget:context()
  local frame = view:frame()
  if not frame or frame:header().mode ~= "tree" then
    return
  end
  local row = vim.api.nvim_win_get_cursor(view.winnr)[1]
  local node = frame:node_at(row)
  if not node then
    return
  end
  local values = frame:rows(row, row)
  if values.can_expand[1] and values.expanded[1] then
    return session.state:set_expanded({ node }, false, false)
  end
  local parent = frame:source():node(node).parent
  if parent and parent ~= frame:header().root.node then
    return session.state:set_expanded({ parent }, false, false)
  end
end

---@return stl.c.Future|nil
function M:recursive()
  local session, view = self._widget:context()
  local frame = view:frame()
  if not frame or frame:header().mode ~= "tree" then
    return
  end
  local row = vim.api.nvim_win_get_cursor(view.winnr)[1]
  local node = frame:node_at(row)
  if node then
    return session.state:dispatch({ kind = "toggle_expanded", node = node, recursive = true }, { frame = frame })
  end
end

---@return stl.c.Future|nil
function M:collapse_all()
  local session, view = self._widget:context()
  local frame = view:frame()
  if frame and frame:header().mode == "tree" then
    return session.state:set_expanded({ frame:header().root.node }, false, true)
  end
end

---@param target                        "parent"|"cursor"|"previous"|"cwd"|"workspace"
---@return stl.c.Future|nil
function M:root(target)
  local session, view = self._widget:context()
  if target == "cwd" then
    return session:navigate_path(dot.path.cwd(), false)
  end
  local node
  if target == "workspace" then
    return session:navigate_path(session.native:workspace_path(), false)
  elseif target == "previous" then
    node = session.native:previous()
  elseif target == "cursor" then
    node = session:target(view):node()
  else
    local frame = view:frame()
    local root = frame and frame:header().root.node
    local entry = root and frame:source():node(root)
    if not entry then
      return session:navigate_path(dot.path.dirname(self._widget:get_root_filepath()), false)
    end
    node = entry.parent
  end
  if node then
    return session:navigate(node, false)
  end
end

---@param kind                          "git"|"diagnostic"|"error"|"warning"
---@param forward                       boolean
---@return stl.c.Future
function M:annotation(kind, forward)
  local session, view = self._widget:context()
  local frame = view:frame()
  return async.run_future(function()
    if not frame then
      return
    end
    local row = vim.api.nvim_win_get_cursor(view.winnr)[1]
    local target = Session.await(session.data:next_annotation(frame, row, kind, forward))
    if view._closed or view:frame() ~= frame then
      return
    end
    if target == 0 then
      Session.report("No matching " .. kind .. " in the current view")
      return
    end
    Session.await(view:set_cursor(target))
  end)
end

---@param kind                          string
---@param options                       ?table
---@return stl.c.Future
function M:operate(kind, options)
  local session, view = self._widget:context()
  return session:operate(view, kind, options)
end

---@param directory                     boolean
---@return stl.c.Future
function M:create(directory)
  local session, view = self._widget:context()
  return session:operate(view, "create", {
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
      return session:operate(view, "delete", { range = { frame = frame, first = first, last = last } }):map(function()
        return { kind = "NoChange" }
      end)
    end)
  end
  return session:operate(view, "delete")
end

---@param kind                          string
---@return stl.c.Future
function M:auxiliary(kind)
  local session, view = self._widget:context()
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
        vim.ui.open(path)
      end
    elseif kind == "info" then
      if #resources ~= 1 then
        error("File info requires one item", 0)
      end
      local info = resources[1]:info()
      local details = Session.await(session.data:details(resources[1]))
      local lines = {
        resources[1]:path(),
        "Type: " .. info.kind,
        "Size: " .. details.size .. " bytes",
        "Permissions: " .. details.permissions .. " (" .. details.mode .. ")",
        "Modified: " .. (details.modified or "unavailable"),
        "Accessed: " .. (details.accessed or "unavailable"),
        "Created: " .. (details.created or "unavailable"),
      }
      stl.reporter.info({ from = __module_name__, message = table.concat(lines, "\n") })
    end
    return { kind = "NoChange" }
  end
  if kind == "ai" and view:_visual_mode() then
    return view:range_action(function(frame, first, last)
      return async.run_future(function()
        return run({ frame = frame, first = first, last = last })
      end)
    end)
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
      stl.reporter.info({
        from = __module_name__,
        message = vim.inspect({ progress = session.progress, results = session.results }),
      })
    elseif choice == "Copy to path" or choice == "Move to path" then
      session:operate(view, choice == "Copy to path" and "copy" or "move", { to_path = true }):catch(Session.report)
    elseif choice == "Copy to directory" or choice == "Move to directory" then
      session
        :operate(view, choice == "Copy to directory" and "copy" or "move", { to_directory = true })
        :catch(Session.report)
    end
  end)
end

return M
