---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.ui" ---@type string

-- A raw msgpack-RPC client for a child Neovim. Unlike Neovim's built-in client it exposes redraw notifications,
-- which UI specs read as a screen.

local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))) ---@type string
local ROOT = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source))) ---@type string

---@class __test__.support.ui.IOptions
---@field timeout_ms                    ?integer
---@field init                          ?string
---@field args                          ?string[]
---@field cwd                           ?string

---@class __test__.support.ui.IStart
---@field width                         ?integer
---@field height                        ?integer
---@field runtime                       ?"ark"|"native"
---@field ui                            ?table

---@class __test__.support.UI
---@field stderr                        string
---@field redraws                       integer
---@field last_flush                    ?integer
---@field exit_code                     ?integer
---@field on_redraw                     ?fun(events: table[]): nil
---@field on_notification               ?fun(method: string, args: table): nil
local M = {}
M.__index = M

---@param options                       ?__test__.support.ui.IOptions
---@return __test__.support.UI
function M.new(options)
  local self = setmetatable({
    _sequence = 0,
    _responses = {},
    _timeout_ms = options and options.timeout_ms or 10000,
    stderr = "",
    redraws = 0,
  }, M)
  local args = { "--embed", "--headless", "-u", options and options.init or "NONE", "-i", "NONE", "-n" }
  if options and options.args then
    vim.list_extend(args, options.args)
  end
  self._stdin, self._stdout, self._stderr = vim.uv.new_pipe(false), vim.uv.new_pipe(false), vim.uv.new_pipe(false)
  local unpacker = vim.mpack.Unpacker()
  self._process = assert(vim.uv.spawn(vim.v.progpath, {
    args = args,
    cwd = options and options.cwd,
    stdio = { self._stdin, self._stdout, self._stderr },
  }, function(code)
    self.exit_code = code
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
        elseif message[1] == 2 and self.on_notification then
          self.on_notification(message[2], message[3])
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
      return self._responses[id] ~= nil or self._error or self.exit_code ~= nil
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

---@param method                        string
---@param ...                           any
---@return nil
function M:notify(method, ...)
  self._stdin:write(vim.mpack.encode({ 2, method, { ... } }))
end

---@param code                          string
---@param ...                           any
---@return any
function M:lua(code, ...)
  return self:rpc("nvim_exec_lua", code, { ... })
end

---Makes this checkout loadable in the child, after attaching a linegrid UI when given a size. The "ark" runtime
---runs the full bootstrap; "native" exposes only the native library, as `bootstrap.with_native` does, and records
---reports in the child's global `reports`.
---@param options                       __test__.support.ui.IStart
---@return nil
function M:start(options)
  if options.width then
    local attach = vim.tbl_extend("force", { rgb = true, ext_linegrid = true }, options.ui or {})
    self:rpc("nvim_ui_attach", options.width, options.height, attach)
  end
  self:lua(
    [[
    local root, runtime = ...
    vim.opt.runtimepath:prepend(root)
    package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
    if runtime == "ark" then
      require("ark.bootstrap").setup()
    elseif runtime == "native" then
      local bootstrap = require("__test__.support.bootstrap")
      local t = require("__test__.support.harness").new()
      bootstrap.with_native(t)
      reports = bootstrap.with_reporter(t)
    end
  ]],
    ROOT,
    options.runtime
  )
end

---Polls `predicate` until it holds. Unlike `vim.wait`, the predicate may make RPC requests: a request waits on
---the event loop itself, and inside a `vim.wait` callback that keeps the outer wait from ever timing out.
---@param predicate                     fun(): any
---@param timeout_ms                    integer
---@param msg                           ?string
---@return nil
function M:wait_until(predicate, timeout_ms, msg)
  local deadline = vim.uv.hrtime() + timeout_ms * 1e6
  while not predicate() do
    if vim.uv.hrtime() >= deadline then
      error(string.format("%s within %d ms%s", msg or "condition was not met", timeout_ms, self.stderr), 2)
    end
    vim.wait(20)
  end
end

---@return nil
function M:close()
  if self.exit_code == nil then
    self._process:kill("sigterm")
    vim.wait(1000, function()
      return self.exit_code ~= nil
    end)
  end
  for _, pipe in ipairs({ self._stdin, self._stdout, self._stderr }) do
    if not pipe:is_closing() then
      pipe:close()
    end
  end
end

return M
