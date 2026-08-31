---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.plugin.action" ---@type string

local State = require("era.m.plugin.state")

---@class era.m.plugin.action
local M = {}

---@type integer
local CONCURRENCY = 8

---@type table<string, era.m.plugin.ITaskState> Current operation snapshot, retained until the next action starts
M._tasks = {}

---@type boolean
M._running = false

---@type era.m.plugin.ActionEnum|nil
M._action = nil

---@return boolean
function M.is_running()
  return M._running
end

---@return table<string, era.m.plugin.ITaskState>
function M.get_tasks()
  return M._tasks
end

---@return era.m.plugin.IOperationProgress
function M.get_progress()
  local progress = {
    action = M._action,
    total = 0,
    queued = 0,
    running = 0,
    done = 0,
    error = 0,
  } ---@type era.m.plugin.IOperationProgress

  for _, task in pairs(M._tasks) do
    progress.total = progress.total + 1
    progress[task.status] = progress[task.status] + 1
  end
  return progress
end

---@param action                        era.m.plugin.ActionEnum
---@return boolean
local function begin_action(action)
  if M._running then
    return false
  end
  M._running = true
  M._action = action
  M._tasks = {}
  return true
end

---@param future                        stl.c.Future
---@return stl.c.Future
local function finish_action(future)
  future:finally(function()
    M._running = false
  end)
  return future
end

---@param task                          era.m.plugin.ITaskState
---@param err                           any
---@param prefix                        string|nil
---@return nil
local function set_task_error(task, err, prefix)
  local message = tostring(err or "Unknown error"):gsub("\r\n", "\n"):gsub("\r", "\n") ---@type string
  local lines = vim.split(message, "\n", { plain = true, trimempty = true }) ---@type string[]
  local first_line = table.remove(lines, 1) or "Unknown error" ---@type string

  task.status = "error"
  task.step = nil
  task.message = prefix and (prefix .. ": " .. first_line) or first_line
  if #lines > 0 then
    task.output = task.output or {}
    vim.list_extend(task.output, lines)
  end
end

---@param on_progress                   ?fun(): nil
---@return stl.c.Future                 Resolves with nil when install completes
function M.install(on_progress)
  if not begin_action("install") then
    return stl.c.Future.resolve(nil)
  end

  local specs = State.specs ---@type era.m.plugin.IPluginSpec[]
  local to_install = {} ---@type era.m.plugin.IPluginSpec[]

  for _, spec in ipairs(specs) do
    local path = dot.path.join(State.options.root, spec.name) ---@type string
    if not yoz.path.is_exist(path) then
      to_install[#to_install + 1] = spec
    end
  end

  if #to_install == 0 then
    M._running = false
    return stl.c.Future.resolve(nil)
  end

  return finish_action(M.__install_plugins__(to_install, on_progress))
end

---@param on_progress                   ?fun(): nil
---@return stl.c.Future                 Resolves with nil when sync completes
function M.sync(on_progress)
  if not begin_action("sync") then
    return stl.c.Future.resolve(nil)
  end

  State.reload_lock()
  return finish_action(M.__sync_plugins__(State.specs, on_progress))
end

---@param on_progress                   ?fun(): nil
---@return stl.c.Future                 Resolves with nil when update completes
function M.update(on_progress)
  if not begin_action("update") then
    return stl.c.Future.resolve(nil)
  end

  local specs = State.specs ---@type era.m.plugin.IPluginSpec[]
  State.load_lock()

  return finish_action(M.__update_plugins__(specs, on_progress))
end

---@param on_progress                   ?fun(): nil
---@return stl.c.Future Resolves with nil when clean completes
function M.clean(on_progress)
  if not begin_action("clean") then
    return stl.c.Future.resolve(nil)
  end

  local to_clean = State.collect_orphan_plugins() ---@type string[]

  if #to_clean == 0 then
    M._running = false
    return stl.c.Future.resolve(nil)
  end

  for _, name in ipairs(to_clean) do
    ---@type era.m.plugin.ITaskState
    local task = {
      name = name,
      action = "clean",
      status = "running",
      message = "Removing...",
      from_commit = nil,
      to_commit = nil,
    }
    M._tasks[name] = task
    if on_progress then
      on_progress()
    end

    local path = dot.path.join(State.options.root, name) ---@type string
    local ok = M.__rm_recursive__(path) ---@type boolean
    if ok then
      task.status = "done"
      task.message = "Removed"
    else
      task.status = "error"
      task.message = "Failed to remove"
    end
    if on_progress then
      on_progress()
    end
  end

  State.remove_orphan_lock_entries()

  M._running = false
  return stl.c.Future.resolve(nil)
end

---@param name                          string
---@param on_progress                   ?fun(): nil
---@return stl.c.Future                 Resolves with nil when build completes
function M.build(name, on_progress)
  if M._running then
    return stl.c.Future.resolve(nil)
  end

  local Loader = require("era.m.plugin.loader")
  local plugin_state = Loader.get(name) ---@type era.m.plugin.IPluginState|nil
  if not plugin_state then
    stl.reporter.warn({
      from = __module_name__,
      subject = "build",
      message = "Plugin not found: " .. name,
    })
    return stl.c.Future.resolve(nil)
  end

  local spec = plugin_state.spec ---@type era.m.plugin.IPluginSpec
  if not spec.build then
    stl.reporter.info({
      from = __module_name__,
      subject = "build",
      message = "No build step for: " .. name,
    })
    return stl.c.Future.resolve(nil)
  end

  if not begin_action("build") then
    return stl.c.Future.resolve(nil)
  end

  ---@type era.m.plugin.ITaskState
  local task = {
    name = name,
    action = "build",
    status = "running",
    step = "building",
    message = "Building...",
    from_commit = nil,
    to_commit = nil,
  }
  M._tasks[name] = task
  if on_progress then
    on_progress()
  end

  local function finish(result)
    if result and result.ok then
      task.status = "done"
      task.step = nil
      task.message = "Build complete"
    else
      set_task_error(task, result and result.err or "unknown error", "Build failed")
    end

    M._running = false
    if on_progress then
      on_progress()
    end
    return nil
  end

  local path = dot.path.join(State.options.root, name) ---@type string
  return M.__run_build__(spec, path, task, on_progress):then_(finish, function(err)
    return finish({ ok = false, err = err })
  end)
end

----------------------------------------------------------------------------------------------------

---@param dir                           string
---@return boolean
function M.__rm_recursive__(dir)
  local ok, err = pcall(vim.fn.delete, dir, "rf")
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "__rm_recursive__",
      message = "Failed to delete directory: " .. dir,
      details = { error = tostring(err) },
    })
    return false
  end
  return true
end

---@param path                          string
---@param from_commit                   string
---@param to_commit                     string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with era.m.plugin.ICommitInfo[]
function M.__fetch_commits__(path, from_commit, to_commit, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({})
      return
    end

    local args = {
      "log",
      "--pretty=format:%h %s (%cr)",
      "--abbrev-commit",
      "--decorate",
      "--date=short",
      "--color=never",
      "--no-show-signature",
      from_commit .. ".." .. to_commit,
    }

    vim.system({ "git", unpack(args) }, { cwd = path, text = true }, function(result)
      if token and token:is_cancelled() then
        vim.schedule(function()
          resolve({})
        end)
        return
      end
      vim.schedule(function()
        local commits = {} ---@type era.m.plugin.ICommitInfo[]
        if result.code == 0 and result.stdout then
          local output = vim.trim(result.stdout) ---@type string
          if output ~= "" then
            for _, line in ipairs(vim.split(output, "\n")) do
              local hash, msg, time = line:match("^(%w+) (.*) (%(.*%))$")
              if hash and msg then
                commits[#commits + 1] = {
                  hash = hash,
                  message = vim.trim(msg),
                  time = time,
                }
              end
            end
          end
        end
        resolve(commits)
      end)
    end)
  end)
end

---@param spec                          era.m.plugin.IPluginSpec
---@param path                          string
---@param task                          ?era.m.plugin.ITaskState
---@param on_output                     ?fun(): nil
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { ok: boolean, err: ?string }
function M.__run_build__(spec, path, task, on_output, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ ok = false, err = "Cancelled" })
      return
    end

    local build = spec.build
    if not build then
      resolve({ ok = true, err = nil })
      return
    end

    if type(build) == "function" then
      local ok, err = pcall(build)
      if ok then
        resolve({ ok = true, err = nil })
      else
        resolve({ ok = false, err = tostring(err) })
      end
      return
    end

    if type(build) == "string" then
      ---@cast build string
      if build:sub(1, 1) == ":" then
        local cmd_str = build:sub(2) ---@type string
        local ok, err = pcall(vim.cmd --[[@as fun(cmd: string)]], cmd_str)
        if ok then
          resolve({ ok = true, err = nil })
        else
          resolve({ ok = false, err = tostring(err) })
        end
        return
      end

      local output_lines = {} ---@type string[]
      local MAX_OUTPUT_LINES = 8 ---@type integer

      ---@param err ?string
      ---@param data ?string
      local function on_data(err, data)
        if err or not data or not task then
          return
        end
        for line in data:gmatch("[^\r\n]+") do
          output_lines[#output_lines + 1] = line
          if #output_lines > MAX_OUTPUT_LINES then
            table.remove(output_lines, 1)
          end
        end
        task.output = output_lines
        if on_output then
          vim.schedule(on_output)
        end
      end

      local ok, err = pcall(vim.system, stl.shell.get_shell_args(build), {
        cwd = path,
        text = true,
        stdout = on_data,
        stderr = on_data,
      }, function(result)
        if token and token:is_cancelled() then
          vim.schedule(function()
            resolve({ ok = false, err = "Cancelled" })
          end)
          return
        end
        vim.schedule(function()
          if result.code == 0 then
            resolve({ ok = true, err = nil })
          else
            local message = result.stderr
            if not message or vim.trim(message) == "" then
              message = output_lines[#output_lines]
            end
            resolve({ ok = false, err = message or "Build command failed" })
          end
        end)
      end)
      if not ok then
        resolve({ ok = false, err = tostring(err) })
      end
      return
    end

    resolve({ ok = true, err = nil })
  end)
end

---@param path                          string
---@param branch                        string|nil
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { ok: boolean, err: ?string }
function M.__git_fetch__(path, branch, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ ok = false, err = "Cancelled" })
      return
    end

    local args = { "git", "fetch", "--tags", "--force", "--recurse-submodules" }
    if branch then
      args[#args + 1] = "origin"
      args[#args + 1] = "refs/heads/" .. branch
    end

    vim.system(args, { cwd = path, text = true }, function(result)
      if token and token:is_cancelled() then
        vim.schedule(function()
          resolve({ ok = false, err = "Cancelled" })
        end)
        return
      end
      vim.schedule(function()
        if result.code == 0 then
          resolve({ ok = true, err = nil })
        else
          resolve({ ok = false, err = result.stderr or "Fetch failed" })
        end
      end)
    end)
  end)
end

---@param path                          string
---@param target                        string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { ok: boolean, err: ?string }
function M.__git_checkout__(path, target, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ ok = false, err = "Cancelled" })
      return
    end

    vim.system({ "git", "checkout", target }, { cwd = path, text = true }, function(result)
      if token and token:is_cancelled() then
        vim.schedule(function()
          resolve({ ok = false, err = "Cancelled" })
        end)
        return
      end
      vim.schedule(function()
        if result.code == 0 then
          resolve({ ok = true, err = nil })
        else
          resolve({ ok = false, err = result.stderr or "Checkout failed" })
        end
      end)
    end)
  end)
end

---@param path                          string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { ok: boolean, dirty: boolean, err: ?string }
function M.__git_is_dirty__(path, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ ok = false, dirty = false, err = "Cancelled" })
      return
    end

    vim.system(
      { "git", "status", "--porcelain=v1", "--untracked-files=all" },
      { cwd = path, text = true },
      function(result)
        if token and token:is_cancelled() then
          vim.schedule(function()
            resolve({ ok = false, dirty = false, err = "Cancelled" })
          end)
          return
        end
        vim.schedule(function()
          resolve({
            ok = result.code == 0,
            dirty = result.code == 0 and (result.stdout or "") ~= "",
            err = result.code == 0 and nil or (result.stderr or "Status failed"),
          })
        end)
      end
    )
  end)
end

---@param name                          string
---@param action                        era.m.plugin.ActionEnum
---@return era.m.plugin.ITaskState
function M.__new_task__(name, action)
  return {
    name = name,
    action = action,
    status = "queued",
    step = nil,
    message = "Queued",
    from_commit = nil,
    to_commit = nil,
  }
end

---@param specs                         era.m.plugin.IPluginSpec[]
---@param action                        era.m.plugin.ActionEnum
---@param worker                        async fun(spec: era.m.plugin.IPluginSpec, task: era.m.plugin.ITaskState): nil
---@param on_progress                   ?fun(): nil
---@return stl.c.Future
function M.__run_plugin_jobs__(specs, action, worker, on_progress)
  local jobs = {} ---@type (fun(): stl.c.Future)[]

  for _, spec in ipairs(specs) do
    local task = M.__new_task__(spec.name, action) ---@type era.m.plugin.ITaskState
    M._tasks[spec.name] = task
    jobs[#jobs + 1] = function()
      task.status = "running"
      task.message = ""
      if on_progress then
        on_progress()
      end

      local future = stl.async.run_future(function()
        worker(spec, task)
      end)
      future:finally(function(ok, err)
        if not ok then
          set_task_error(task, err)
          if on_progress then
            on_progress()
          end
        end
      end)
      return future
    end
  end

  if on_progress then
    on_progress()
  end
  return M.__throttle_jobs__(jobs)
end

---@async
---@param spec                          era.m.plugin.IPluginSpec
---@param task                          era.m.plugin.ITaskState
---@param new_lock                      table<string, era.m.plugin.ILockEntry>
---@param on_progress                   ?fun(): nil
---@return nil
function M.__install_single_plugin__(spec, task, new_lock, on_progress)
  local name = spec.name ---@type string

  local path = dot.path.join(State.options.root, name) ---@type string
  local url = spec.url or ("https://github.com/" .. name) ---@type string

  task.step = "cloning"
  task.message = "Cloning..."
  if on_progress then
    on_progress()
  end

  local clone_result = stl.git.act.clone(url, path, spec.branch):await()
  if not clone_result or not clone_result.ok then
    set_task_error(task, clone_result and clone_result.stderr or "unknown error", "Clone failed")
    if on_progress then
      on_progress()
    end
    return
  end

  local info = stl.git.info.info(path)
  if not info or not info.commit then
    task.status = "error"
    task.step = nil
    task.message = "Failed to get commit info"
    if on_progress then
      on_progress()
    end
    return
  end

  local branch = info.branch or spec.branch or "main" ---@type string
  task.to_commit = info.commit:sub(1, 7)
  new_lock[name] = { branch = branch, commit = info.commit }

  if spec.build then
    task.step = "building"
    task.message = "Building..."
    if on_progress then
      on_progress()
    end

    local build_result = M.__run_build__(spec, path, task, on_progress):await()
    if not build_result or not build_result.ok then
      set_task_error(task, build_result and build_result.err or "unknown error", "Build failed")
      if on_progress then
        on_progress()
      end
      return
    end
  end

  task.status = "done"
  task.step = nil
  task.message = "Installed"

  local commits = M.__fetch_commits__(path, info.commit .. "~10", info.commit):await()
  task.commits = commits
  if on_progress then
    on_progress()
  end
end

---@param specs                         era.m.plugin.IPluginSpec[]
---@param on_progress                   ?fun(): nil
---@return stl.c.Future
function M.__install_plugins__(specs, on_progress)
  local total = #specs ---@type integer

  if total == 0 then
    return stl.c.Future.resolve(nil)
  end

  State.load_lock()

  ---@type table<string, era.m.plugin.ILockEntry>
  local new_lock = vim.tbl_extend("keep", {}, State.lock)

  return M.__run_plugin_jobs__(specs, "install", function(spec, task)
    M.__install_single_plugin__(spec, task, new_lock, on_progress)
  end, on_progress):map(function()
    State.update_lock(new_lock)
    return nil
  end)
end

---@async
---@param spec                          era.m.plugin.IPluginSpec
---@param task                          era.m.plugin.ITaskState
---@param lock                          era.m.plugin.ILockEntry
---@param on_progress                   ?fun(): nil
---@return nil
function M.__sync_single_plugin__(spec, task, lock, on_progress)
  local name = spec.name ---@type string
  local path = dot.path.join(State.options.root, name) ---@type string
  local target_commit = lock.commit ---@type string
  task.to_commit = target_commit:sub(1, 7)

  local installed = yoz.path.is_exist(path) ---@type boolean
  if not installed then
    task.step = "cloning"
    task.message = "Cloning..."
    if on_progress then
      on_progress()
    end

    local url = spec.url or ("https://github.com/" .. name) ---@type string
    local clone_result = stl.git.act.clone(url, path, lock.branch or spec.branch):await()
    if not clone_result or not clone_result.ok then
      set_task_error(task, clone_result and clone_result.stderr or "unknown error", "Clone failed")
      if on_progress then
        on_progress()
      end
      return
    end
  end

  local info = stl.git.info.info(path)
  if not info or not info.commit then
    task.status = "error"
    task.step = nil
    task.message = "Not a git repo"
    if on_progress then
      on_progress()
    end
    return
  end

  task.from_commit = info.commit:sub(1, 7)
  local needs_checkout = info.commit:lower() ~= target_commit:lower() ---@type boolean
  if installed then
    task.step = "checking"
    task.message = "Checking worktree..."
    if on_progress then
      on_progress()
    end

    local dirty_result = M.__git_is_dirty__(path):await()
    if not dirty_result or not dirty_result.ok then
      set_task_error(task, dirty_result and dirty_result.err or "unknown error", "Status failed")
      if on_progress then
        on_progress()
      end
      return
    end
    if dirty_result.dirty then
      task.status = "error"
      task.step = nil
      task.message = "Dirty worktree"
      if on_progress then
        on_progress()
      end
      return
    end
  end

  if installed and not needs_checkout then
    task.status = "done"
    task.step = nil
    task.message = "Already synced"
    if on_progress then
      on_progress()
    end
    return
  end

  if needs_checkout then
    if installed then
      task.step = "fetching"
      task.message = "Fetching..."
      if on_progress then
        on_progress()
      end

      local fetch_result = M.__git_fetch__(path, lock.branch or spec.branch):await()
      if not fetch_result or not fetch_result.ok then
        set_task_error(task, fetch_result and fetch_result.err or "unknown error", "Fetch failed")
        if on_progress then
          on_progress()
        end
        return
      end
    end

    task.step = "checkout"
    task.message = "Checking out lock..."
    if on_progress then
      on_progress()
    end

    local checkout_result = M.__git_checkout__(path, target_commit):await()
    if not checkout_result or not checkout_result.ok then
      set_task_error(task, checkout_result and checkout_result.err or "unknown error", "Checkout failed")
      if on_progress then
        on_progress()
      end
      return
    end

    local checked_out = stl.git.info.info(path)
    if not checked_out or not checked_out.commit or checked_out.commit:lower() ~= target_commit:lower() then
      task.status = "error"
      task.step = nil
      task.message = "Checkout verification failed"
      if on_progress then
        on_progress()
      end
      return
    end
  end

  if spec.build then
    task.step = "building"
    task.message = "Building..."
    if on_progress then
      on_progress()
    end

    local build_result = M.__run_build__(spec, path, task, on_progress):await()
    if not build_result or not build_result.ok then
      set_task_error(task, build_result and build_result.err or "unknown error", "Build failed")
      if on_progress then
        on_progress()
      end
      return
    end
  end

  task.status = "done"
  task.step = nil
  task.message = "Synced"
  task.commits = M.__fetch_commits__(path, info.commit, target_commit):await()
  if on_progress then
    on_progress()
  end
end

---@param specs                         era.m.plugin.IPluginSpec[]
---@param on_progress                   ?fun(): nil
---@return stl.c.Future
function M.__sync_plugins__(specs, on_progress)
  local pinned = {} ---@type era.m.plugin.IPluginSpec[]
  local locks = {} ---@type table<string, era.m.plugin.ILockEntry>

  for _, spec in ipairs(specs) do
    local lock = State.lock[spec.name] ---@type era.m.plugin.ILockEntry|nil
    if lock == nil then
      local task = M.__new_task__(spec.name, "sync") ---@type era.m.plugin.ITaskState
      task.status = "error"
      task.message = "Unpinned"
      M._tasks[spec.name] = task
    elseif
      type(lock) ~= "table"
      or type(lock.commit) ~= "string"
      or (#lock.commit ~= 40 and #lock.commit ~= 64)
      or lock.commit:match("^%x+$") == nil
      or (lock.branch ~= nil and (type(lock.branch) ~= "string" or lock.branch == ""))
    then
      local task = M.__new_task__(spec.name, "sync") ---@type era.m.plugin.ITaskState
      task.status = "error"
      task.message = "Invalid lock entry"
      M._tasks[spec.name] = task
    else
      pinned[#pinned + 1] = spec
      locks[spec.name] = lock
    end
  end

  if #pinned == 0 then
    if on_progress then
      on_progress()
    end
    return stl.c.Future.resolve(nil)
  end

  return M.__run_plugin_jobs__(pinned, "sync", function(spec, task)
    local lock = assert(locks[spec.name]) ---@type era.m.plugin.ILockEntry
    M.__sync_single_plugin__(spec, task, lock, on_progress)
  end, on_progress)
end

---@async
---@param spec                          era.m.plugin.IPluginSpec
---@param task                          era.m.plugin.ITaskState
---@param new_lock                      table<string, era.m.plugin.ILockEntry>
---@param on_progress                   ?fun(): nil
---@return nil
function M.__update_single_plugin__(spec, task, new_lock, on_progress)
  local name = spec.name ---@type string

  local path = dot.path.join(State.options.root, name) ---@type string

  if not yoz.path.is_exist(path) then
    -- Plugin not installed, trigger installation
    local url = spec.url or ("https://github.com/" .. name) ---@type string
    task.step = "cloning"
    task.message = "Cloning..."
    if on_progress then
      on_progress()
    end

    local clone_result = stl.git.act.clone(url, path, spec.branch):await()
    if not clone_result or not clone_result.ok then
      set_task_error(task, clone_result and clone_result.stderr or "unknown error", "Clone failed")
      if on_progress then
        on_progress()
      end
      return
    end

    local info = stl.git.info.info(path)
    if not info or not info.commit then
      task.status = "error"
      task.step = nil
      task.message = "Failed to get commit info"
      if on_progress then
        on_progress()
      end
      return
    end

    local branch = info.branch or spec.branch or "main" ---@type string
    task.to_commit = info.commit:sub(1, 7)
    new_lock[name] = { branch = branch, commit = info.commit }

    if spec.build then
      task.step = "building"
      task.message = "Building..."
      if on_progress then
        on_progress()
      end

      local build_result = M.__run_build__(spec, path, task, on_progress):await()
      if not build_result or not build_result.ok then
        set_task_error(task, build_result and build_result.err or "unknown error", "Build failed")
        if on_progress then
          on_progress()
        end
        return
      end
    end

    task.status = "done"
    task.step = nil
    task.message = "Installed"

    local commits = M.__fetch_commits__(path, info.commit .. "~10", info.commit):await()
    task.commits = commits
    if on_progress then
      on_progress()
    end
    return
  end

  local info = stl.git.info.info(path)
  if not info then
    task.status = "error"
    task.step = nil
    task.message = "Not a git repo"
    if on_progress then
      on_progress()
    end
    return
  end

  task.from_commit = info.commit and info.commit:sub(1, 7) or nil
  task.step = "fetching"
  task.message = "Fetching..."
  if on_progress then
    on_progress()
  end

  local fetch_result = M.__git_fetch__(path):await()
  if not fetch_result or not fetch_result.ok then
    set_task_error(task, fetch_result and fetch_result.err or "unknown error", "Fetch failed")
    if on_progress then
      on_progress()
    end
    return
  end

  local branch = spec.branch or stl.git.info.get_branch(path) or "main" ---@type string
  local target_commit = stl.git.info.get_commit(path, branch, true)

  if not target_commit then
    task.status = "error"
    task.step = nil
    task.message = "No target commit"
    if on_progress then
      on_progress()
    end
    return
  end

  task.to_commit = target_commit:sub(1, 7)

  if info.commit and stl.git.info.eq(info, { commit = target_commit }) then
    task.status = "done"
    task.step = nil
    task.message = "Already up to date"
    new_lock[name] = { branch = branch, commit = target_commit }
    if on_progress then
      on_progress()
    end
    return
  end

  task.step = "checkout"
  task.message = "Checking out..."
  if on_progress then
    on_progress()
  end

  local checkout_result = M.__git_checkout__(path, target_commit):await()
  if not checkout_result or not checkout_result.ok then
    set_task_error(task, checkout_result and checkout_result.err or "unknown error", "Checkout failed")
    if on_progress then
      on_progress()
    end
    return
  end

  new_lock[name] = { branch = branch, commit = target_commit }

  if spec.build then
    task.step = "building"
    task.message = "Building..."
    if on_progress then
      on_progress()
    end

    local build_result = M.__run_build__(spec, path, task, on_progress):await()
    if not build_result or not build_result.ok then
      set_task_error(task, build_result and build_result.err or "unknown error", "Build failed")
      if on_progress then
        on_progress()
      end
      return
    end
  end

  task.status = "done"
  task.step = nil
  task.message = "Updated"

  if info.commit then
    local commits = M.__fetch_commits__(path, info.commit, target_commit):await()
    task.commits = commits
  end
  if on_progress then
    on_progress()
  end
end

---@param specs                         era.m.plugin.IPluginSpec[]
---@param on_progress                   ?fun(): nil
---@return stl.c.Future
function M.__update_plugins__(specs, on_progress)
  local total = #specs ---@type integer

  if total == 0 then
    return stl.c.Future.resolve(nil)
  end

  State.load_lock()

  ---@type table<string, era.m.plugin.ILockEntry>
  local new_lock = vim.tbl_extend("keep", {}, State.lock)

  return M.__run_plugin_jobs__(specs, "update", function(spec, task)
    M.__update_single_plugin__(spec, task, new_lock, on_progress)
  end, on_progress):map(function()
    State.update_lock(new_lock)
    return nil
  end)
end

---Run lazy jobs with concurrency limit.
---@param jobs                          (fun(): stl.c.Future)[]
---@return stl.c.Future
function M.__throttle_jobs__(jobs)
  local total = #jobs ---@type integer
  if total == 0 then
    return stl.c.Future.resolve({})
  end

  return stl.c.Future.new(function(resolve)
    local running = 0 ---@type integer
    local completed = 0 ---@type integer
    local next_index = 1 ---@type integer

    local function run_next()
      while running < CONCURRENCY and next_index <= total do
        local index = next_index ---@type integer
        next_index = next_index + 1
        running = running + 1

        jobs[index]():finally(function()
          running = running - 1
          completed = completed + 1

          if completed == total then
            resolve({})
          else
            run_next()
          end
        end)
      end
    end

    run_next()
  end)
end

return M
