---@class stl.git.exec
local M = {}

---Execute git command asynchronously (async/await version).
---Returns a Future that resolves with { lines, code }.
---@param args                          string[]
---@param opts                          { cwd: string|nil }|nil
---@param token                         stl.c.CancellationToken|nil
---@return stl.c.Future
function M.exec(args, opts, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({ lines = {}, code = -1 })
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

    local proc = vim.system(cmd, { text = true }, function(obj)
      vim.schedule(function()
        if token and token:is_cancelled() then
          return
        end

        local lines = {}
        if obj.code == 0 and obj.stdout then
          lines = vim.split(obj.stdout, "\n", { plain = true })
          if lines[#lines] == "" then
            lines[#lines] = nil
          end
        end
        resolve({ lines = lines, code = obj.code })
      end)
    end)

    if token then
      token:on_cancel(function()
        proc:kill(9)
      end)
    end
  end)
end

---Execute git command asynchronously with callback (for simple fire-and-forget operations).
---@param args                          string[]
---@param opts                          { cwd: string|nil }|nil
---@param callback                      fun(lines: string[], code: integer): nil
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
      callback(lines, obj.code)
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
