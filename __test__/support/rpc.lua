---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.rpc" ---@type string

-- Raw RPC preserves redraw notifications, which Neovim's built-in RPC client does not expose.
local M = {}
M.__index = M

---@param timeout_ms                    integer
---@param predicate                     fun(): boolean
---@param interval_ms                   integer
---@return boolean
function M.wait(timeout_ms, predicate, interval_ms)
  -- A predicate may make a blocking RPC request; keep it outside vim.wait's callback.
  local deadline = vim.uv.hrtime() + timeout_ms * 1e6
  repeat
    if predicate() then
      return true
    end
    vim.wait(interval_ms)
  until vim.uv.hrtime() >= deadline
  return false
end

---@param root                          string
---@return table
function M.new(root)
  local self = setmetatable({ responses = {}, notifications = {}, stderr = {}, next_id = 0 }, M)
  self.stdin = assert(vim.uv.new_pipe(false))
  self.stdout = assert(vim.uv.new_pipe(false))
  self.err = assert(vim.uv.new_pipe(false))
  self.handle = assert(vim.uv.spawn(vim.v.progpath, {
    args = { "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n" },
    cwd = root,
    stdio = { self.stdin, self.stdout, self.err },
  }, function(code)
    self.exit_code = code
  end))
  local unpacker = vim.mpack.Unpacker()
  self.stdout:read_start(function(err, chunk)
    assert(not err, err)
    if chunk == nil then
      return
    end
    local position = 1
    while position <= #chunk do
      local message
      message, position = unpacker(chunk, position)
      if message ~= nil then
        if message[1] == 1 then
          self.responses[message[2]] = message
        elseif message[1] == 2 then
          self.notifications[#self.notifications + 1] =
            { method = message[2], args = message[3], time = vim.uv.hrtime() }
        end
      end
    end
  end)
  self.err:read_start(function(_, chunk)
    if chunk ~= nil then
      self.stderr[#self.stderr + 1] = chunk
    end
  end)
  return self
end

---@param method                        string
---@param args                          table
---@return nil
function M:notify(method, args)
  self.stdin:write(vim.mpack.encode({ 2, method, args }))
end

---@param method                        string
---@param args                          table
---@return any
function M:request(method, args)
  self.next_id = self.next_id + 1
  local id = self.next_id
  self.stdin:write(vim.mpack.encode({ 0, id, method, args }))
  assert(
    vim.wait(10000, function()
      return self.responses[id] ~= nil or self.exit_code ~= nil
    end, 1),
    "RPC timeout: " .. method
  )
  local response = assert(self.responses[id], table.concat(self.stderr))
  self.responses[id] = nil
  assert(response[3] == vim.NIL, vim.inspect(response[3]))
  return response[4]
end

---@param code                          string
---@param ...                           any
---@return any
function M:lua(code, ...)
  return self:request("nvim_exec_lua", { code, { ... } })
end

---@return nil
function M:close()
  if self.exit_code == nil then
    self.stdin:write(vim.mpack.encode({ 2, "nvim_command", { "qa!" } }))
    if not vim.wait(2000, function()
      return self.exit_code ~= nil
    end, 1) then
      self.handle:kill("sigkill")
      vim.wait(1000, function()
        return self.exit_code ~= nil
      end, 1)
    end
  end
  for _, handle in ipairs({ self.stdin, self.stdout, self.err, self.handle }) do
    if not handle:is_closing() then
      handle:close()
    end
  end
end

return M
