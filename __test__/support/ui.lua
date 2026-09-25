---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.ui" ---@type string

---@class __test__.support.UI
---@field on_redraw                     ?fun(events: table[]): nil
local M = {}
M.__index = M

---@param options                       ?{timeout_ms: integer}
---@return __test__.support.UI
function M.new(options)
  local self = setmetatable({
    _sequence = 0,
    _responses = {},
    _timeout_ms = options and options.timeout_ms or 10000,
    stderr = "",
    redraws = 0,
  }, M)
  self._stdin, self._stdout, self._stderr = vim.uv.new_pipe(false), vim.uv.new_pipe(false), vim.uv.new_pipe(false)
  local unpacker = vim.mpack.Unpacker()
  self._process = assert(vim.uv.spawn(vim.v.progpath, {
    args = { "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n" },
    stdio = { self._stdin, self._stdout, self._stderr },
  }, function()
    self._exited = true
    self._process:close()
  end))
  self._stdout:read_start(function(error, data)
    if error then
      self._error = error
    end
    if not data then
      return
    end
    local at = 1
    while at <= #data do
      local message, next_byte = unpacker(data, at)
      at = next_byte
      if message then
        if message[1] == 1 then
          self._responses[message[2]] = message
        elseif message[1] == 2 and message[2] == "redraw" then
          self.redraws = self.redraws + 1
          if self.on_redraw then
            self.on_redraw(message[3])
          end
          for _, event in ipairs(message[3]) do
            if event[1] == "flush" then
              self.last_flush = vim.uv.hrtime()
            end
          end
        end
      end
    end
  end)
  self._stderr:read_start(function(_, data)
    if data then
      self.stderr = self.stderr .. data
    end
  end)
  return self
end

---@param method                        string
---@param ...                           any
---@return any
function M:rpc(method, ...)
  self._sequence = self._sequence + 1
  local id = self._sequence
  self._stdin:write(vim.mpack.encode({ 0, id, method, { ... } }))
  assert(
    vim.wait(self._timeout_ms, function()
      return self._responses[id] ~= nil or self._error or self._exited
    end),
    "RPC timeout: " .. method .. self.stderr
  )
  local response = self._responses[id]
  self._responses[id] = nil
  assert(response, tostring(self._error or self.stderr))
  assert(response[3] == vim.NIL, method .. ": " .. vim.inspect(response[3]))
  if response[4] == vim.NIL then
    return nil
  end
  return response[4]
end

---@return nil
function M:close()
  if not self._exited then
    self._process:kill("sigterm")
    vim.wait(1000, function()
      return self._exited
    end)
  end
  for _, pipe in ipairs({ self._stdin, self._stdout, self._stderr }) do
    if not pipe:is_closing() then
      pipe:close()
    end
  end
end

return M
