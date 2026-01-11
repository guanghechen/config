---@class stl.git.exec
local M = {}

---Execute git command asynchronously
---@param args                          string[]
---@param opts                          { cwd: string|nil }|nil
---@param callback                      fun(lines: string[], code: integer): nil
---@return fun(): nil                   cancel_fn
function M.exec_async(args, opts, callback)
  local cmd = { "git" }
  if opts and opts.cwd then
    cmd[#cmd + 1] = "-C"
    cmd[#cmd + 1] = opts.cwd
  end
  for _, arg in ipairs(args) do
    cmd[#cmd + 1] = arg
  end

  local cancelled = false ---@type boolean
  local proc = vim.system(cmd, { text = true }, function(obj)
    if not cancelled then
      vim.schedule(function()
        if not cancelled then
          local lines = {}
          if obj.code == 0 and obj.stdout then
            lines = vim.split(obj.stdout, "\n", { plain = true })
            if lines[#lines] == "" then
              lines[#lines] = nil
            end
          end
          callback(lines, obj.code)
        end
      end)
    end
  end)

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
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
