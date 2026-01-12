---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.plugin.action" ---@type string

local State = require("era.m.plugin.state")

---@class era.m.plugin.action
local M = {}

---@type integer
local CONCURRENCY = 8

---@type table<string, era.m.plugin.ITaskState>
M._tasks = {}

---@type table<string, era.m.plugin.ITaskState>
M._history = {}

---@type boolean
M._running = false

---@return boolean
function M.is_running()
  return M._running
end

---@return table<string, era.m.plugin.ITaskState>
function M.get_tasks()
  return M._tasks
end

---@return table<string, era.m.plugin.ITaskState>
function M.get_history()
  return M._history
end

---@param on_progress                   fun(): nil
---@param on_done                       fun(): nil
---@return nil
function M.install(on_progress, on_done)
  if M._running then
    return
  end

  M._running = true
  M._tasks = {}

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
    on_done()
    return
  end

  M.__install_plugins__(to_install, on_progress, function()
    M._running = false
    on_done()
  end)
end

---@param on_progress                   fun(): nil
---@param on_done                       fun(): nil
---@return nil
function M.update(on_progress, on_done)
  if M._running then
    return
  end

  M._running = true
  M._tasks = {}

  local specs = State.specs ---@type era.m.plugin.IPluginSpec[]
  State.load_lock()

  M.__update_plugins__(specs, on_progress, function()
    M._running = false
    on_done()
  end)
end

---@param on_done                       fun(): nil
---@return nil
function M.clean(on_done)
  if M._running then
    return
  end

  M._running = true
  M._tasks = {}

  local to_clean = State.collect_orphan_plugins() ---@type string[]

  if #to_clean == 0 then
    M._running = false
    on_done()
    return
  end

  for _, name in ipairs(to_clean) do
    ---@type era.m.plugin.ITaskState
    local task = {
      name = name,
      status = "running",
      message = "Removing...",
      from_commit = nil,
      to_commit = nil,
    }
    M._tasks[name] = task

    local path = dot.path.join(State.options.root, name) ---@type string
    local ok = M.__rm_recursive__(path) ---@type boolean
    if ok then
      task.status = "done"
      task.message = "Removed"
    else
      task.status = "error"
      task.message = "Failed to remove"
    end
  end

  State.remove_orphan_lock_entries()

  M._running = false
  on_done()
end

---@param name                          string
---@param on_progress                   fun(): nil
---@param on_done                       fun(): nil
---@return nil
function M.build(name, on_progress, on_done)
  if M._running then
    return
  end

  local Loader = require("era.m.plugin.loader")
  local plugin_state = Loader.get(name) ---@type era.m.plugin.IPluginState|nil
  if not plugin_state then
    stl.reporter.warn({
      from = "era.m.plugin.action",
      subject = "build",
      message = "Plugin not found: " .. name,
    })
    on_done()
    return
  end

  local spec = plugin_state.spec ---@type era.m.plugin.IPluginSpec
  if not spec.build then
    stl.reporter.info({
      from = "era.m.plugin.action",
      subject = "build",
      message = "No build step for: " .. name,
    })
    on_done()
    return
  end

  M._running = true
  M._tasks = {}

  ---@type era.m.plugin.ITaskState
  local task = {
    name = name,
    status = "running",
    step = "building",
    message = "Building...",
    from_commit = nil,
    to_commit = nil,
  }
  M._tasks[name] = task
  on_progress()

  local path = dot.path.join(State.options.root, name) ---@type string
  M.__run_build__(spec, path, task, on_progress, function(ok, err)
    if ok then
      task.status = "done"
      task.step = nil
      task.message = "Build complete"
    else
      task.status = "error"
      task.step = nil
      task.message = "Build failed: " .. (err or "unknown error")
    end

    M.__save_to_history__()
    M._running = false
    on_progress()
    on_done()
  end)
end

----------------------------------------------------------------------------------------------------

---@param tasks                         fun(callback: fun(): nil)[]
---@param on_all_done                   fun(): nil
---@return nil
function M.__throttle_execute__(tasks, on_all_done)
  local total = #tasks ---@type integer
  if total == 0 then
    on_all_done()
    return
  end

  local running = 0 ---@type integer
  local completed = 0 ---@type integer
  local next_index = 1 ---@type integer

  ---@return nil
  local function run_next()
    while running < CONCURRENCY and next_index <= total do
      local index = next_index ---@type integer
      next_index = next_index + 1
      running = running + 1

      tasks[index](function()
        running = running - 1
        completed = completed + 1

        if completed == total then
          on_all_done()
        else
          run_next()
        end
      end)
    end
  end

  run_next()
end

---@param dir                           string
---@return boolean
function M.__rm_recursive__(dir)
  local ok, err = pcall(vim.fn.delete, dir, "rf")
  if not ok then
    stl.reporter.error({
      from = "era.m.plugin.action",
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
---@param callback                      fun(commits: era.m.plugin.ICommitInfo[]): nil
---@return nil
function M.__fetch_commits__(path, from_commit, to_commit, callback)
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
      callback(commits)
    end)
  end)
end

---@param name                          string
---@param callback                      fun(task: era.m.plugin.ITaskState): nil
---@return boolean
function M.__run_task__(name, callback)
  ---@type era.m.plugin.ITaskState
  local task = {
    name = name,
    status = "running",
    step = nil,
    message = "",
    from_commit = nil,
    to_commit = nil,
  }
  M._tasks[name] = task

  callback(task)
  return true
end

---@param spec                          era.m.plugin.IPluginSpec
---@param path                          string
---@param task                          era.m.plugin.ITaskState|nil
---@param on_output                     (fun(): nil)|nil
---@param callback                      fun(ok: boolean, err: string|nil): nil
---@return nil
function M.__run_build__(spec, path, task, on_output, callback)
  local build = spec.build
  if not build then
    callback(true, nil)
    return
  end

  if type(build) == "function" then
    local ok, err = pcall(build)
    if ok then
      callback(true, nil)
    else
      callback(false, tostring(err))
    end
    return
  end

  if type(build) == "string" then
    if build:sub(1, 1) == ":" then
      local ok, err = pcall(vim.cmd, build:sub(2))
      if ok then
        callback(true, nil)
      else
        callback(false, tostring(err))
      end
      return
    end

    local output_lines = {} ---@type string[]
    local MAX_OUTPUT_LINES = 8 ---@type integer

    ---@param err string|nil
    ---@param data string|nil
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

    vim.system(stl.shell.get_shell_args(build), {
      cwd = path,
      text = true,
      stdout = on_data,
      stderr = on_data,
    }, function(result)
      vim.schedule(function()
        if result.code == 0 then
          callback(true, nil)
        else
          callback(false, result.stderr or "Build command failed")
        end
      end)
    end)
    return
  end

  callback(true, nil)
end

---@return nil
function M.__save_to_history__()
  for name, task in pairs(M._tasks) do
    M._history[name] = vim.deepcopy(task)
  end
end

---@param specs                         era.m.plugin.IPluginSpec[]
---@param on_progress                   fun(): nil
---@param on_done                       fun(): nil
---@return nil
function M.__install_plugins__(specs, on_progress, on_done)
  local total = #specs ---@type integer

  if total == 0 then
    on_done()
    return
  end

  -- Load existing lock to preserve entries
  State.load_lock()

  ---@type table<string, era.m.plugin.ILockEntry>
  local new_lock = vim.tbl_extend("keep", {}, State.lock)

  ---@type fun(callback: fun(): nil)[]
  local tasks = {}

  for _, spec in ipairs(specs) do
    tasks[#tasks + 1] = function(task_done)
      M.__run_task__(spec.name, function(task)
        local path = dot.path.join(State.options.root, spec.name) ---@type string
        local url = spec.url or ("https://github.com/" .. spec.name) ---@type string

        task.step = "cloning"
        task.message = "Cloning..."
        on_progress()

        stl.git.act.clone(url, path, spec.branch, function(ok, _, stderr)
          if not ok then
            task.status = "error"
            task.step = nil
            task.message = "Clone failed: " .. (stderr or "unknown error")
            on_progress()
            task_done()
            return
          end

          local info = stl.git.info.info(path)
          if not info or not info.commit then
            task.status = "error"
            task.step = nil
            task.message = "Failed to get commit info"
            on_progress()
            task_done()
            return
          end

          local branch = info.branch or spec.branch or "main" ---@type string
          task.to_commit = info.commit:sub(1, 7)
          new_lock[spec.name] = { branch = branch, commit = info.commit }

          if spec.build then
            task.step = "building"
            task.message = "Building..."
            on_progress()

            M.__run_build__(spec, path, task, on_progress, function(build_ok, build_err)
              if not build_ok then
                task.status = "error"
                task.step = nil
                task.message = "Build failed: " .. (build_err or "unknown error")
                on_progress()
                task_done()
                return
              end

              task.status = "done"
              task.step = nil
              task.message = "Installed"

              M.__fetch_commits__(path, info.commit .. "~10", info.commit, function(commits)
                task.commits = commits
                on_progress()
                task_done()
              end)
            end)
          else
            task.status = "done"
            task.step = nil
            task.message = "Installed"

            M.__fetch_commits__(path, info.commit .. "~10", info.commit, function(commits)
              task.commits = commits
              on_progress()
              task_done()
            end)
          end
        end)
      end)
    end
  end

  M.__throttle_execute__(tasks, function()
    State.update_lock(new_lock)
    M.__save_to_history__()
    on_done()
  end)
end

---@param specs                         era.m.plugin.IPluginSpec[]
---@param on_progress                   fun(): nil
---@param on_done                       fun(): nil
---@return nil
function M.__update_plugins__(specs, on_progress, on_done)
  local total = #specs ---@type integer

  if total == 0 then
    on_done()
    return
  end

  -- Load existing lock to preserve entries
  State.load_lock()

  ---@type table<string, era.m.plugin.ILockEntry>
  local new_lock = vim.tbl_extend("keep", {}, State.lock)

  ---@type fun(callback: fun(): nil)[]
  local tasks = {}

  for _, spec in ipairs(specs) do
    tasks[#tasks + 1] = function(task_done)
      M.__run_task__(spec.name, function(task)
        local path = dot.path.join(State.options.root, spec.name) ---@type string

        if not yoz.path.is_exist(path) then
          -- Plugin not installed, trigger installation
          local url = spec.url or ("https://github.com/" .. spec.name) ---@type string
          task.step = "cloning"
          task.message = "Cloning..."
          on_progress()

          stl.git.act.clone(url, path, spec.branch, function(ok, _, stderr)
            if not ok then
              task.status = "error"
              task.step = nil
              task.message = "Clone failed: " .. (stderr or "unknown error")
              on_progress()
              task_done()
              return
            end

            local info = stl.git.info.info(path)
            if not info or not info.commit then
              task.status = "error"
              task.step = nil
              task.message = "Failed to get commit info"
              on_progress()
              task_done()
              return
            end

            local branch = info.branch or spec.branch or "main" ---@type string
            task.to_commit = info.commit:sub(1, 7)
            new_lock[spec.name] = { branch = branch, commit = info.commit }

            if spec.build then
              task.step = "building"
              task.message = "Building..."
              on_progress()

              M.__run_build__(spec, path, task, on_progress, function(build_ok, build_err)
                if not build_ok then
                  task.status = "error"
                  task.step = nil
                  task.message = "Build failed: " .. (build_err or "unknown error")
                  on_progress()
                  task_done()
                  return
                end

                task.status = "done"
                task.step = nil
                task.message = "Installed"

                M.__fetch_commits__(path, info.commit .. "~10", info.commit, function(commits)
                  task.commits = commits
                  on_progress()
                  task_done()
                end)
              end)
            else
              task.status = "done"
              task.step = nil
              task.message = "Installed"

              M.__fetch_commits__(path, info.commit .. "~10", info.commit, function(commits)
                task.commits = commits
                on_progress()
                task_done()
              end)
            end
          end)
          return
        end

        local info = stl.git.info.info(path)
        if not info then
          task.status = "error"
          task.step = nil
          task.message = "Not a git repo"
          on_progress()
          task_done()
          return
        end

        task.from_commit = info.commit and info.commit:sub(1, 7) or nil
        task.step = "fetching"
        task.message = "Fetching..."
        on_progress()

        vim.system(
          { "git", "fetch", "--tags", "--force", "--recurse-submodules" },
          { cwd = path, text = true },
          function(fetch_result)
            vim.schedule(function()
              if fetch_result.code ~= 0 then
                task.status = "error"
                task.step = nil
                task.message = "Fetch failed"
                on_progress()
                task_done()
                return
              end

              local branch = spec.branch or stl.git.info.get_branch(path) or "main" ---@type string
              local target_commit = stl.git.info.get_commit(path, branch, true)

              if not target_commit then
                task.status = "error"
                task.step = nil
                task.message = "No target commit"
                on_progress()
                task_done()
                return
              end

              task.to_commit = target_commit:sub(1, 7)

              if info.commit and stl.git.info.eq(info, { commit = target_commit }) then
                task.status = "done"
                task.step = nil
                task.message = "Already up to date"
                new_lock[spec.name] = { branch = branch, commit = target_commit }
                on_progress()
                task_done()
                return
              end

              task.step = "checkout"
              task.message = "Checking out..."
              on_progress()

              vim.system({ "git", "checkout", target_commit }, { cwd = path, text = true }, function(checkout_result)
                vim.schedule(function()
                  if checkout_result.code ~= 0 then
                    task.status = "error"
                    task.step = nil
                    task.message = "Checkout failed"
                    on_progress()
                    task_done()
                    return
                  end

                  new_lock[spec.name] = { branch = branch, commit = target_commit }

                  if spec.build then
                    task.step = "building"
                    task.message = "Building..."
                    on_progress()

                    M.__run_build__(spec, path, task, on_progress, function(build_ok, build_err)
                      if not build_ok then
                        task.status = "error"
                        task.step = nil
                        task.message = "Build failed: " .. (build_err or "unknown error")
                        on_progress()
                        task_done()
                        return
                      end

                      task.status = "done"
                      task.step = nil
                      task.message = "Updated"

                      if info.commit then
                        M.__fetch_commits__(path, info.commit, target_commit, function(commits)
                          task.commits = commits
                          on_progress()
                          task_done()
                        end)
                      else
                        on_progress()
                        task_done()
                      end
                    end)
                  else
                    task.status = "done"
                    task.step = nil
                    task.message = "Updated"

                    if info.commit then
                      M.__fetch_commits__(path, info.commit, target_commit, function(commits)
                        task.commits = commits
                        on_progress()
                        task_done()
                      end)
                    else
                      on_progress()
                      task_done()
                    end
                  end
                end)
              end)
            end)
          end
        )
      end)
    end
  end

  M.__throttle_execute__(tasks, function()
    State.update_lock(new_lock)
    M.__save_to_history__()
    on_done()
  end)
end

return M
