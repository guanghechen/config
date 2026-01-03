local Git = require("era.m.plugin.git")
local State = require("era.m.plugin.state")

---@class era.m.plugin.action
local M = {}

---@type integer
local CONCURRENCY = 8

---@type table<string, era.m.plugin.ITaskState>
M._tasks = {}

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
    message = "",
    from_commit = nil,
    to_commit = nil,
  }
  M._tasks[name] = task

  callback(task)
  return true
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

        task.message = "Cloning..."
        on_progress()

        Git.clone(url, path, spec.branch, function(ok, _, stderr)
          if not ok then
            task.status = "error"
            task.message = "Clone failed: " .. (stderr or "unknown error")
            on_progress()
            task_done()
            return
          end

          local info = Git.info(path)
          if not info or not info.commit then
            task.status = "error"
            task.message = "Failed to get commit info"
            on_progress()
            task_done()
            return
          end

          local branch = info.branch or spec.branch or "main" ---@type string
          task.to_commit = info.commit:sub(1, 7)
          task.status = "done"
          task.message = "Installed"
          new_lock[spec.name] = { branch = branch, commit = info.commit }

          -- Fetch recent commits for display
          M.__fetch_commits__(path, info.commit .. "~10", info.commit, function(commits)
            task.commits = commits
            on_progress()
            task_done()
          end)
        end)
      end)
    end
  end

  M.__throttle_execute__(tasks, function()
    State.update_lock(new_lock)
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
          task.message = "Cloning..."
          on_progress()

          Git.clone(url, path, spec.branch, function(ok, _, stderr)
            if not ok then
              task.status = "error"
              task.message = "Clone failed: " .. (stderr or "unknown error")
              on_progress()
              task_done()
              return
            end

            local info = Git.info(path)
            if not info or not info.commit then
              task.status = "error"
              task.message = "Failed to get commit info"
              on_progress()
              task_done()
              return
            end

            local branch = info.branch or spec.branch or "main" ---@type string
            task.to_commit = info.commit:sub(1, 7)
            task.status = "done"
            task.message = "Installed"
            new_lock[spec.name] = { branch = branch, commit = info.commit }

            -- Fetch recent commits for display
            M.__fetch_commits__(path, info.commit .. "~10", info.commit, function(commits)
              task.commits = commits
              on_progress()
              task_done()
            end)
          end)
          return
        end

        local info = Git.info(path)
        if not info then
          task.status = "error"
          task.message = "Not a git repo"
          on_progress()
          task_done()
          return
        end

        task.from_commit = info.commit and info.commit:sub(1, 7) or nil
        task.message = "Fetching..."
        on_progress()

        vim.system(
          { "git", "fetch", "--tags", "--force", "--recurse-submodules" },
          { cwd = path, text = true },
          function(fetch_result)
            vim.schedule(function()
              if fetch_result.code ~= 0 then
                task.status = "error"
                task.message = "Fetch failed"
                on_progress()
                task_done()
                return
              end

              local branch = spec.branch or Git.get_branch(path) or "main" ---@type string
              local target_commit = Git.get_commit(path, branch, true)

              if not target_commit then
                task.status = "error"
                task.message = "No target commit"
                on_progress()
                task_done()
                return
              end

              task.to_commit = target_commit:sub(1, 7)

              if info.commit and Git.eq(info, { commit = target_commit }) then
                task.status = "done"
                task.message = "Already up to date"
                new_lock[spec.name] = { branch = branch, commit = target_commit }
                on_progress()
                task_done()
                return
              end

              task.message = "Checking out..."
              on_progress()

              vim.system({ "git", "checkout", target_commit }, { cwd = path, text = true }, function(checkout_result)
                vim.schedule(function()
                  if checkout_result.code ~= 0 then
                    task.status = "error"
                    task.message = "Checkout failed"
                    on_progress()
                    task_done()
                    return
                  end

                  task.status = "done"
                  task.message = "Updated"
                  new_lock[spec.name] = { branch = branch, commit = target_commit }

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
              end)
            end)
          end
        )
      end)
    end
  end

  M.__throttle_execute__(tasks, function()
    State.update_lock(new_lock)
    on_done()
  end)
end

return M
