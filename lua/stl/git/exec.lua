---@class stl.git.exec
local M = {}

---@class stl.git.exec.IExecOpts
---@field public cwd                    string|nil
---@field public env                    table<string, string>|nil
---@field public raw                    boolean|nil                    preserve stdout bytes in lines[1]
---@field public stdin                  string|nil

---@class stl.git.exec.IResult
---@field public lines                  string[]
---@field public code                   integer
---@field public stderr                 string

---Execute git command asynchronously (async/await version).
---Returns stdout only on success, while always preserving the exit code and stderr.
---@param args                          string[]
---@param opts                          stl.git.exec.IExecOpts|nil
---@param token                         stl.c.CancellationToken|nil
---@return stl.c.Future                Resolves with stl.git.exec.IResult
function M.exec(args, opts, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ lines = {}, code = -1, stderr = "" })
      return
    end

    local cmd = { "git" }
    if opts and opts.cwd then
      cmd[#cmd + 1] = "-C"
      cmd[#cmd + 1] = opts.cwd
    end
    for _, arg in ipairs(args) do
      cmd[#cmd + 1] = arg
    end

    local raw = opts ~= nil and opts.raw == true
    local system_opts = {
      env = opts and opts.env or nil,
      stdin = opts and opts.stdin or nil,
      text = not raw,
    }
    local proc = vim.system(cmd, system_opts, function(obj)
      vim.schedule(function()
        if token and token:is_cancelled() then
          return
        end

        local lines = {}
        if obj.code == 0 and obj.stdout then
          if raw then
            lines = obj.stdout == "" and {} or { obj.stdout }
          else
            lines = vim.split(obj.stdout, "\n", { plain = true })
            if lines[#lines] == "" then
              lines[#lines] = nil
            end
          end
        end
        resolve({ lines = lines, code = obj.code, stderr = obj.stderr or "" })
      end)
    end)

    if token then
      token:on_cancel(function()
        resolve({ lines = {}, code = -1, stderr = "Operation cancelled" })
        pcall(proc.kill, proc, 9)
      end)
    end
  end)
end

---Execute git command asynchronously with callback (for simple fire-and-forget operations).
---@param args                          string[]
---@param opts                          { cwd: string|nil }|nil
---@param callback                      fun(lines: string[], code: integer, stderr: string): nil
function M.exec_async(args, opts, callback)
  local cmd = { "git" }
  if opts and opts.cwd then
    cmd[#cmd + 1] = "-C"
    cmd[#cmd + 1] = opts.cwd
  end
  for _, arg in ipairs(args) do
    cmd[#cmd + 1] = arg
  end

  vim.system(cmd, { text = true }, function(obj)
    vim.schedule(function()
      local lines = {}
      if obj.code == 0 and obj.stdout then
        lines = vim.split(obj.stdout, "\n", { plain = true })
        if lines[#lines] == "" then
          lines[#lines] = nil
        end
      end
      callback(lines, obj.code, obj.stderr or "")
    end)
  end)
end

---Execute git command synchronously (for user-triggered actions where blocking is acceptable)
---@param args                          string[]
---@param opts                          { cwd: string|nil }|nil
---@return string[]
---@return integer
function M.exec_sync(args, opts)
  local cmd = { "git" }
  if opts and opts.cwd then
    cmd[#cmd + 1] = "-C"
    cmd[#cmd + 1] = opts.cwd
  end
  for _, arg in ipairs(args) do
    cmd[#cmd + 1] = arg
  end

  local obj = vim.system(cmd, { text = true }):wait()
  local lines = {}
  if obj.code == 0 and obj.stdout then
    lines = vim.split(obj.stdout, "\n", { plain = true })
    if lines[#lines] == "" then
      lines[#lines] = nil
    end
  end
  return lines, obj.code
end

return M
