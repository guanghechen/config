---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.jobs" ---@type string

local async = require("stl.async")
local native_async = require("ux.treeview.async")
local Future = require("stl.c.future")
local buffers = require("era.m.explorer.buffers")
local Git = require("era.m.git.state")
local active = {} ---@type table<era.m.explorer.Session, boolean>
local scheduled = false
local M = {}

---@param session                       era.m.explorer.Session
---@param label                         string
---@param run                           async fun(task: ux.treeview.Task, preparation: table): any
---@param selection_revision            ?ux.treeview.Revision
---@return stl.c.Future
local function with_preparation(session, label, run, selection_revision)
  if session:busy() then
    return Future.reject("Explorer already has an active operation")
  end
  local preparation = { cancelled = false, label = label }
  session.preparing, session._preparation = true, preparation
  active[session] = true
  session:notify()
  return async.run_future(function()
    local task
    local ok, value = pcall(function()
      task = session.await(session.state:lock_selection(nil, selection_revision))
      if not preparation.cancelled then
        return run(task, preparation)
      end
    end)
    if not preparation.launched then
      if task then
        local unlocked, error = pcall(session.await, task:unlock())
        if not unlocked then
          session.report(error)
        end
      end
      session._direct_task, session._preparation, session.preparing = nil, nil, false
      active[session] = nil
      session:notify()
      session:_release()
    end
    if not ok and not preparation.cancelled then
      error(value, 0)
    end
    return not preparation.cancelled and value or nil
  end)
end

---@async
---@param session                       era.m.explorer.Session
---@param task                          ux.treeview.Task
---@param preparation                   table
---@return ux.treeview.IReply|nil
local function prepare_sources(session, task, preparation)
  local retry = true
  while not preparation.cancelled do
    local ready = session.await(task:prepare_sources(retry))
    retry = false
    if preparation.cancelled then
      return nil
    end
    if ready.kind == "Ready" then
      return ready
    elseif ready.kind ~= "Pending" then
      error("Explorer sources could not be prepared", 0)
    end
    async.await(function(done)
      vim.defer_fn(done, 10)
    end)
  end
  return nil
end

---@param session                       era.m.explorer.Session
---@param revision                      ux.treeview.Revision
---@return stl.c.Future
function M.resolve_selection(session, revision)
  return with_preparation(session, "loading selection · <Space> cancel", function(task, preparation)
    return prepare_sources(session, task, preparation)
  end, revision)
end

---@async
---@param preparation                   table
---@param request                       fun(done: fun(value: any): nil): nil
---@return any
local function prompt(preparation, request)
  if preparation.cancelled then
    return nil
  end
  return async.await(function(done)
    local resume
    resume = function(value)
      if preparation.resume ~= resume then
        return
      end
      preparation.resume = nil
      done(value)
    end
    preparation.resume = resume
    request(resume)
  end)
end

---@async
---@param preparation                   table
---@param options                       table
---@return string|nil
local function input(preparation, options)
  return prompt(preparation, function(done)
    vim.ui.input(options, done)
  end)
end

---@async
---@param preparation                   table
---@param message                       string
---@param trash                         boolean
---@return boolean
local function confirm_delete(preparation, message, trash)
  return prompt(preparation, function(done)
    vim.ui.select(
      { "Cancel", trash and "Move to trash" or "Delete permanently" },
      { prompt = message },
      function(_, index)
        done(index == 2)
      end
    )
  end)
end

---@async
---@param session                       era.m.explorer.Session
---@param preparation                   table
---@param path                          string
---@param source                        yoz.ux.filetree.Resource
---@return yoz.ux.filetree.Resource|nil
local function target_directory(session, preparation, path, source)
  local ancestor, missing = path, {}
  while not preparation.cancelled do
    local value = session.data:resolve(ancestor):await()
    if type(value) == "userdata" then
      if not value:info().directory then
        error("Target parent is not a directory: " .. ancestor, 0)
      end
      if #missing == 0 then
        return value
      end
      session.await(session.data:check_transfer_target(source, value))
      if preparation.cancelled then
        return nil
      end
      local names = {}
      for index = #missing, 1, -1 do
        names[#names + 1] = missing[index]
      end
      local job = session.data:_track_job(
        session.native:start_create({ target = value, path = table.concat(names, "/"), directory = true })
      )
      preparation.job = job
      while not job:status().terminal do
        async.await(function(done)
          vim.defer_fn(done, 10)
        end)
      end
      preparation.job = nil
      local status = job:status()
      if status.results > 0 then
        Git.refresh(false)
      end
      if status.error then
        error(status.error.message, 0)
      end
      if preparation.cancelled or status.cancelled then
        return nil
      end
      return session.await(session.data:resolve(path))
    end
    local parent = dot.path.dirname(ancestor)
    if parent == ancestor or not value.error.message:find("kind=NotFound", 1, true) then
      error(value.error.message, 0)
    end
    missing[#missing + 1], ancestor = yoz.path.basename(ancestor), parent
  end
  return nil
end

---@return nil
function M.poll()
  for session in pairs(active) do
    local job = session.job
    if job then
      local status = job:status()
      session.progress = status
      local key = table.concat({
        status.results,
        status.bytes,
        tostring(status.cancelling),
        status.confirmation and status.confirmation.token or "",
      }, ":")
      if session._progress_key ~= key then
        session._progress_key = key
        session:notify()
      end
      if status.confirmation and session._confirmation ~= status.confirmation.token then
        local confirmation = status.confirmation
        session._confirmation = confirmation.token
        ---@param proceed               boolean
        ---@return nil
        local function confirmed(proceed)
          if session.job == job then
            local current = job:status().confirmation
            if current and current.token == confirmation.token then
              local ok, error = pcall(job.confirm, job, confirmation.token, proceed)
              native_async.watch(M)
              if not ok then
                session.report(error)
              end
            end
          end
        end
        if confirmation.kind == "prepare_move" then
          buffers.prepare(job, confirmation):finally(function(ok, result)
            if not ok then
              session.report(result)
            end
            confirmed(ok and result == true)
          end)
        else
          vim.ui.select(
            { "Skip", "Overwrite" },
            { prompt = "Overwrite " .. confirmation.target_label .. " with " .. confirmation.source_label .. "?" },
            function(_, index)
              confirmed(index == 2)
            end
          )
        end
      end
      local last = math.min(status.results, session._result_offset + 128)
      if last > session._result_offset then
        for _, item in ipairs(job:results(session._result_offset + 1, last)) do
          local synced, error = pcall(buffers.sync, session, item)
          if not synced then
            session.report(error)
          end
          session._counts[item.status] = session._counts[item.status] + 1
          session.results[#session.results + 1] = item
          if #session.results > 128 then
            table.remove(session.results, 1)
          end
        end
        session._result_offset = last
      end
      if status.terminal and session._result_offset == status.results and not session._finishing then
        session._finishing = true
        local unlocked = session._direct_task and session._direct_task:unlock() or Future.resolve(nil)
        unlocked:finally(function(ok, result)
          session._direct_task = nil
          session.job, session.preparing, session._finishing = nil, false, false
          active[session] = nil
          session:notify()
          if not ok then
            session.report(result)
          end
          if status.error then
            session.report(status.error)
          end
          if type(status.cleanup) == "table" then
            session.report(status.cleanup)
          end
          local counts = session._counts
          if counts.success > 0 then
            Git.refresh(false)
          end
          stl.reporter.info({
            from = __module_name__,
            message = string.format(
              "%s: %d succeeded, %d failed, %d skipped%s",
              session.operation,
              counts.success,
              counts.failed,
              counts.skipped,
              status.cancelled and " (cancelled)" or ""
            ),
          })
          local complete = session._on_complete
          session._on_complete = nil
          if complete then
            local completed, error = pcall(complete, status, session.results)
            if not completed then
              session.report(error)
            end
          end
          session:_release()
        end)
      end
    end
  end
  if next(active) and not scheduled then
    scheduled = true
    vim.defer_fn(function()
      scheduled = false
      M.poll()
    end, 40)
  end
end

-- Completion and new confirmations use the native poller; progress stays on the slower timer.
---@return boolean
function M._poll()
  local pending = false
  for session in pairs(active) do
    local job = session.job
    if job then
      local status = job:status()
      if status.terminal or status.confirmation and session._confirmation ~= status.confirmation.token then
        M.poll()
        return true
      end
      pending = pending or status.cancelling or status.confirmation == nil
    end
  end
  if not pending then
    native_async.unwatch(M)
  end
  return pending
end

---@param session                       era.m.explorer.Session
---@param view                          ux.filetree.View
---@param kind                          string
---@param options                       table
---@return stl.c.Future
function M.start(session, view, kind, options)
  if session:busy() then
    return Future.reject("Explorer already has an active operation")
  end
  local cursor = session:cursor(view)
  local destination = options.target or session:target(view)
  return with_preparation(session, "preparing", function(task, preparation)
    if kind == "paste" then
      -- The lock fixes both selection and its purpose, even before the new frame is drawn.
      local mode = session.state:status().selection_purpose
      if mode ~= "copy" and mode ~= "cut" then
        return
      end
      kind = mode == "copy" and "copy" or "move"
    end
    local ready, selected, nodes, source, count
    if options.range then
      local inspected = session.await(session:inspect_range(options.range))
      nodes, source = inspected.subtree_roots, options.range.frame:source()
      count = nodes:len()
      if count == 0 then
        return
      end
    elseif kind ~= "create" then
      ready = prepare_sources(session, task, preparation)
      if not ready then
        return
      end
      local summary = ready.summary
      selected = summary.known_roots ~= 0 or summary.known_self_only ~= 0 or summary.pending
      nodes, source = ready.subtree_roots, ready.source
      count = nodes:len()
      if count == 0 then
        if selected or not cursor then
          return
        end
        nodes, source, count = { cursor:node() }, cursor:source(), 1
      end
    end
    local job
    if kind == "create" then
      local path = options.path
        or input(preparation, { prompt = options.directory and "New directory: " or "New file or directory: " })
      if not path or path == "" or preparation.cancelled then
        return
      end
      job = session.native:start_create({
        target = destination,
        path = path,
        directory = options.directory == true or path:sub(-1) == "/",
      })
      session._direct_task = task
    else
      local name = options.name
      if options.rename then
        if count ~= 1 then
          error("Rename requires exactly one source", 0)
        end
        local node = type(nodes) == "table" and nodes[1] or nodes:get(1)
        local resource = session.data:inspect(source, node)
        -- Native Unix paths preserve backslashes and arbitrary filename bytes.
        local pattern = stl.env.IS_WIN and "[^/\\]+$" or "[^/]+$"
        name = name or input(preparation, { prompt = "Rename: ", default = resource:path():match(pattern) })
        if not name or name == "" then
          return
        end
        destination = session.data:inspect(source, source:node(node).parent)
      elseif options.to_path then
        if count ~= 1 then
          error("Copy or move to a path requires exactly one source; use a target directory for multiple sources", 0)
        end
        local node = type(nodes) == "table" and nodes[1] or nodes:get(1)
        local resource = session.data:inspect(source, node)
        local path = type(options.to_path) == "string" and options.to_path
          or input(preparation, {
            prompt = kind == "copy" and "Copy to path: " or "Move to path: ",
            default = options.default_path or resource:path(),
            completion = "file",
          })
        if not path or path == "" or preparation.cancelled then
          return
        end
        path = dot.path.normalize(dot.path.resolve(dot.path.cwd(), path), false, "/")
        if
          resource:info().kind == "directory"
          and (path == resource:path() or yoz.path.is_descendant(resource:path(), path))
        then
          error("Directory destination is inside its source", 0)
        end
        name = yoz.path.basename(path)
        destination = target_directory(session, preparation, dot.path.dirname(path), resource)
        if not destination then
          return
        end
      elseif options.to_directory then
        local path = type(options.to_directory) == "string" and options.to_directory
          or input(preparation, { prompt = "Target directory: ", default = destination:path(), completion = "dir" })
        if not path or path == "" or preparation.cancelled then
          return
        end
        destination = session.await(session.data:resolve(dot.path.resolve(dot.path.cwd(), path)))
      end
      if kind == "delete" then
        local trash = dot.context.explorer.trash:snapshot()
        if
          not confirm_delete(preparation, (trash and "Trash " or "Permanently delete ") .. count .. " item(s)?", trash)
        then
          return
        end
        kind = trash and "trash" or "delete"
      end
      if preparation.cancelled then
        return
      end
      local context
      if selected then
        context = { state = session.state._native, lock = task.token, cleanup = ready.cleanup }
      else
        session._direct_task = task
      end
      job = session.native:start_operation({
        kind = kind,
        source = source,
        nodes = nodes,
        target = (kind == "copy" or kind == "move") and destination or nil,
        name = name,
        task = context,
        prepare_move = kind == "move",
      })
    end
    preparation.launched = true
    session._preparation = nil
    session.job, session.operation, session.preparing = session.data:_track_job(job), kind, false
    session._result_offset, session._confirmation = 0, nil
    session._counts = { success = 0, failed = 0, skipped = 0 }
    session.results, session._on_complete = {}, options.on_complete
    native_async.watch(M)
    if not scheduled then
      M.poll()
    end
    return job
  end, options.selection_revision)
end

---@param session                       era.m.explorer.Session
---@return nil
function M.cancel(session)
  if session.job then
    session.job:cancel()
    native_async.watch(M)
  elseif session._preparation then
    local preparation = session._preparation
    preparation.cancelled = true
    if preparation.job then
      preparation.job:cancel()
    end
    if preparation.resume then
      preparation.resume(nil)
    end
  end
end

---@return boolean
function M.pending()
  return next(active) ~= nil
end

---@return nil
function M.cancel_all()
  for session in pairs(active) do
    M.cancel(session)
  end
end

require("era.m.explorer.exit").setup(M)

return M
