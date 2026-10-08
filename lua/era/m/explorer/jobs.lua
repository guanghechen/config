---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.jobs" ---@type string

local async = require("stl.async")
local Future = require("stl.c.future")
local native_async = require("ux.treeview.async")
local Task = require("ux.treeview.task")
local buffers = require("era.m.explorer.buffers")
local Git = require("era.m.git.state")
local filepath = require("ux.filetree.path")
local active = {} ---@type table<era.m.explorer.Session, boolean>
local draining = {} ---@type table<era.m.explorer.Session, yoz.ux.filetree.Job>
local M = {}

local OPERATIONS = { ---@type table<era.m.explorer.JobKind, era.m.explorer.OperationKind>
  create = "create",
  copy = "copy",
  move = "move",
  paste = "copy", -- Replaced by the locked selection purpose before launch.
  delete = "delete",
  rename = "move",
  copy_to_path = "copy",
  move_to_path = "move",
  copy_to_directory = "copy",
  move_to_directory = "move",
}

---@param session                       era.m.explorer.Session
---@param label                         string
---@param acquire                       fun(state: ux.treeview.State): stl.c.Future
---@param run                           async fun(task: ux.treeview.Task|nil, preparation: era.m.explorer.IPreparation, reply: ux.treeview.IReply): ux.treeview.IReply|yoz.ux.filetree.Job|nil
---@return stl.c.Future
local function with_preparation(session, label, acquire, run)
  if session._disposed then
    return Future.reject("Explorer session is disposed")
  end
  if session:busy() then
    return Future.reject("Explorer already has an active operation")
  end
  local state = session.state
  local preparation = { cancelled = false, label = label } ---@type era.m.explorer.IPreparation
  session.preparing, session._preparation = true, preparation
  active[session] = true
  session:notify()
  return async.run_future(function()
    local task
    local ok, value = pcall(function()
      -- Retain acquisition ownership through cancellation, including a late Locked reply.
      local reply = session.await(acquire(state))
      if reply.kind == "Locked" then
        task = Task.new(state, reply.token)
      end
      if not preparation.cancelled then
        return run(task, preparation, reply)
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
---@param preparation                   era.m.explorer.IPreparation
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
---@return stl.c.Future
function M.resolve_selection(session)
  if session._disposed then
    return Future.reject("Explorer session is disposed")
  end
  if session.preparing then
    return Future.reject("Explorer already has an active operation")
  end
  if session:busy() then
    -- Complete inspection is read-only and may coexist with an operation's task.
    return session.state:inspect_selection():map(function(reply)
      if reply.kind == "Inspected" and reply.summary.pending then
        error("Explorer already has an active operation", 0)
      end
      return reply
    end)
  end
  return with_preparation(session, "loading selection · <Space> cancel", function()
    return native_async.run(session.native:prepare_selection())
  end, function(task, preparation, reply)
    if task then
      return prepare_sources(session, task, preparation)
    end
    return reply
  end)
end

---@async
---@param preparation                   era.m.explorer.IPreparation
---@param request                       fun(done: fun(value: string|nil): nil): nil
---@return string|nil
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
---@param preparation                   era.m.explorer.IPreparation
---@param options                       era.m.input.IOptions
---@return string|nil
local function input(preparation, options)
  return prompt(preparation, function(done)
    vim.ui.input(options, done)
  end)
end

---@async
---@param preparation                   era.m.explorer.IPreparation
---@param message                       string
---@return boolean
local function confirm_delete(preparation, message)
  local answer = input(preparation, { prompt = message, inputtype = "confirmation" })
  answer = answer and vim.trim(answer):lower()
  return answer == "y" or answer == "yes"
end

---@async
---@param session                       era.m.explorer.Session
---@param preparation                   era.m.explorer.IPreparation
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
      local job = session.native:start_create({ target = value, path = table.concat(names, "/"), directory = true })
      preparation.job = job
      local status = async.await(function(done)
        session.data:_track_job(job, function(status)
          if status.terminal then
            done(status)
          end
        end)
      end)
      preparation.job = nil
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
    local parent = filepath.dirname(ancestor)
    if parent == ancestor or value.error.code ~= "NotFound" then
      error(value.error.message, 0)
    end
    missing[#missing + 1], ancestor = filepath.basename(ancestor), parent
  end
  return nil
end

---@param session                       era.m.explorer.Session
---@param job                           yoz.ux.filetree.Job
---@param status                        ux.filetree.IJobStatus
---@return nil
local function update(session, job, status)
  if session.job ~= job then
    return
  end
  session.progress = status
  local key = table.concat({
    status.results,
    status.processed,
    status.bytes,
    status.phase,
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
    ---@param proceed                   boolean
    ---@return nil
    local function confirmed(proceed)
      if session.job == job then
        local current = job:status().confirmation
        if current and current.token == confirmation.token then
          local ok, error = pcall(job.confirm, job, confirmation.token, proceed)
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
      vim.ui.input({
        prompt = "Overwrite existing target?\nTarget: "
          .. string.format("%q", confirmation.target_label)
          .. "\nSource: "
          .. string.format("%q", confirmation.source_label),
        inputtype = "confirmation",
      }, function(answer)
        answer = answer and vim.trim(answer):lower()
        confirmed(answer == "y" or answer == "yes")
      end)
    end
  end
  local last = math.min(status.results, session._result_offset + 128)
  if last > session._result_offset then
    for _, item in ipairs(job:results(session._result_offset + 1, last)) do
      ---@cast item era.m.explorer.IItemResult
      item.editor_error = buffers.sync(session, item)
      if item.editor_error then
        session._counts.editor_failed = session._counts.editor_failed + 1
      end
      session._counts[item.status] = session._counts[item.status] + 1
      session.results[#session.results + 1] = item
      if #session.results > 128 then
        table.remove(session.results, 1)
      end
      if item.status ~= "success" or item.sync_error or item.editor_error then
        -- A successful tail must not erase failures, skipped sources, or incomplete synchronization.
        local bytes = 256
        for _, value in pairs(item) do
          if type(value) == "string" then
            bytes = bytes + #value
          elseif type(value) == "table" then
            bytes = bytes + #(value.message or "") + #(value.code or "")
          end
        end
        if #session.issues < 512 and session._issue_bytes + bytes <= 1024 * 1024 then
          session.issues[#session.issues + 1] = item
          session._issue_bytes = session._issue_bytes + bytes
        else
          session.issues_omitted = session.issues_omitted + 1
        end
      end
    end
    session._result_offset = last
  end
  if status.terminal and session._result_offset == status.results and not session._finishing then
    session._finishing = true
    if draining[session] == job then
      draining[session] = nil
    end
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
        message = session:result_text(),
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
  if session.job == job and session._result_offset < status.results and draining[session] ~= job then
    draining[session] = job
    vim.schedule(function()
      if draining[session] == job then
        draining[session] = nil
        if session.job == job then
          update(session, job, job:status())
        end
      end
    end)
  end
end

-- Explicit draining is used while the editor is synchronously waiting to exit.
---@return nil
function M.poll()
  for session in pairs(active) do
    local job = session.job
    if job then
      update(session, job, job:status())
    end
  end
end

---@param session                       era.m.explorer.Session
---@param view                          ux.filetree.View
---@param request                       era.m.explorer.IJobRequest
---@return stl.c.Future
function M.start(session, view, request)
  if session:busy() then
    return Future.reject("Explorer already has an active operation")
  end
  local kind = request.kind
  local operation = assert(OPERATIONS[kind], "Invalid Explorer operation")
  local cursor = request.cursor and request.cursor.resource or session:cursor(view)
  local destination = request.target or session:target(view)
  local root = operation == "create" and not request.path and not request.target and session:root(view:frame()) or nil
  return with_preparation(session, "preparing", function(state)
    if request.cursor then
      return native_async.run(session.native:prepare_cursor(request.cursor.frame, cursor:node()))
    end
    return native_async.run(state._native:lock_selection())
  end, function(task, preparation)
    if kind == "paste" then
      -- The lock fixes both selection and its purpose, even before the new frame is drawn.
      local mode = session.state:status().selection_purpose
      if mode ~= "copy" and mode ~= "cut" then
        return
      end
      operation = mode == "copy" and "copy" or "move"
    end
    local ready, selected, nodes, source, count
    if request.range then
      local inspected = session.await(session:inspect_range(request.range))
      nodes, source = inspected.subtree_roots, inspected.source
      count = nodes:len()
      if count == 0 then
        return
      end
    elseif request.cursor then
      nodes, source, count = { cursor:node() }, cursor:source(), 1
    elseif operation ~= "create" then
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
    if operation == "create" then
      local path = request.path
      if path == nil then
        local default = ""
        local message = request.directory and "Create directory: " or "Create file: "
        if root then
          local prefix = root:path()
          local last = prefix:sub(-1)
          if last ~= "/" and not (stl.env.IS_WIN and last == "\\") then
            prefix = prefix .. "/"
          end
          default = destination:path() == root:path() and "" or destination:path():sub(#prefix + 1) .. "/"
        end
        if default:find("\n", 1, true) then
          -- Keep unrepresentable parent paths out of the single editable line.
          default, root = "", nil
          message = string.format(
            request.directory and "Create directory in %q: " or "Create file in %q: ",
            destination:info().label
          )
        end
        path = input(preparation, {
          prompt = message,
          default = default,
        })
        if path then
          path = filepath.from_os(path)
        end
        if root then
          if path and path:sub(1, #default) == default then
            -- An unchanged directory prefix keeps the captured destination identity.
            path = path:sub(#default + 1)
          else
            destination = root
          end
        end
      end
      if not path or path == "" or preparation.cancelled then
        return
      end
      job = session.native:start_create({
        target = destination,
        path = path,
        directory = request.directory == true or path:sub(-1) == "/",
      })
      session._direct_task = task
    else
      local name = request.name
      if kind == "rename" then
        if count ~= 1 then
          error("Rename requires exactly one source", 0)
        end
        local node = type(nodes) == "table" and nodes[1] or nodes:get(1)
        local resource = session.data:inspect(source, node)
        name = name or input(preparation, { prompt = "Rename to: ", default = filepath.basename(resource:path()) })
        if not name or name == "" then
          return
        end
        destination = session.data:inspect(source, source:node(node).parent)
      elseif kind == "copy_to_path" or kind == "move_to_path" then
        if count ~= 1 then
          error("Copy or move to a path requires exactly one source; use a target directory for multiple sources", 0)
        end
        local node = type(nodes) == "table" and nodes[1] or nodes:get(1)
        local resource = session.data:inspect(source, node)
        local path = request.path
          or input(preparation, {
            prompt = operation == "copy" and "Copy to: " or "Move to: ",
            default = request.default_path or resource:path(),
            completion = "file",
          })
        if not path or path == "" or preparation.cancelled then
          return
        end
        path = request.path or filepath.from_os(path)
        path = filepath.trim(filepath.resolve(filepath.from_os(dot.path.cwd()), path))
        name = filepath.basename(path)
        if name == "." or name == ".." then
          -- Resolve terminal directory components before deriving the destination name.
          local target = session.await(session.data:resolve(path))
          path = target:path()
          name = filepath.basename(path)
        end
        -- Native target preparation checks physical ancestry, including symlinks and parent components.
        destination = target_directory(session, preparation, filepath.dirname(path), resource)
        if not destination then
          return
        end
      elseif kind == "copy_to_directory" or kind == "move_to_directory" then
        local path = request.path
          or input(preparation, {
            prompt = operation == "copy" and "Copy to directory: " or "Move to directory: ",
            default = destination:path(),
            completion = "dir",
          })
        if not path or path == "" or preparation.cancelled then
          return
        end
        path = request.path or filepath.from_os(path)
        destination = session.await(session.data:resolve(filepath.resolve(filepath.from_os(dot.path.cwd()), path)))
      end
      if operation == "delete" then
        local trash = dot.context.explorer.trash:snapshot()
        local labels = {}
        for index = 1, math.min(count, 5) do
          local node = type(nodes) == "table" and nodes[index] or nodes:get(index)
          local info = session.data:inspect(source, node):info()
          labels[#labels + 1] = string.format("%q", info.label .. (info.kind == "directory" and "/" or ""))
        end
        if count > #labels then
          labels[#labels + 1] = "and " .. (count - #labels) .. " more"
        end
        local message = (trash and "Trash " or "Permanently delete ")
          .. (count == 1 and labels[1] .. "?" or count .. " items?\n" .. table.concat(labels, "\n"))
        if not confirm_delete(preparation, message) then
          return
        end
        operation = trash and "trash" or "delete"
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
        kind = operation,
        source = source,
        nodes = nodes,
        target = (operation == "copy" or operation == "move") and destination or nil,
        name = name,
        task = context,
        prepare_move = operation == "move",
      })
    end
    preparation.launched = true
    session._preparation = nil
    session.job, session.operation, session.preparing = job, operation, false
    session._result_offset, session._confirmation = 0, nil
    session._counts = { success = 0, failed = 0, skipped = 0, editor_failed = 0 }
    session.results, session._on_complete = {}, request.on_complete
    session.issues, session.issues_omitted, session._issue_bytes = {}, 0, 0
    session.data:_track_job(job, function(status)
      update(session, job, status)
    end)
    return job
  end)
end

---@param session                       era.m.explorer.Session
---@return nil
function M.cancel(session)
  if session.job then
    session.job:cancel()
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
