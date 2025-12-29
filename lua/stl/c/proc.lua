---@see https://github.com/folke/snacks.nvim/blob/5589c9d37bccf56f98982cd88a72e69cddf13436/lua/snacks/util/spawn.lua

---@param handle                        uv.uv_handle_t|nil
---@return nil
local function close(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

---@class stl.c.proc.IProps: uv.spawn.options,{}
---@field public cmd                    string
---@field public args                   ?(string|number)[]
---@field public timeout                ?number
---@field public run                    ?boolean
---@field public on_stdout              ?fun(proc: stl.c.Proc, data: string)
---@field public on_stderr              ?fun(proc: stl.c.Proc, data: string)
---@field public on_exit                ?fun(proc: stl.c.Proc, err: boolean)

---@class stl.c.proc.IMultiProps: stl.c.proc.IProps,{}
---@field public cmd                    nil
---@field public on_exit                ?fun(procs: stl.c.Proc[], err: boolean)

---@class stl.c.Proc
---@field public opts                   stl.c.proc.IProps
---@field public handle                 ?uv.uv_process_t
---@field public stdout                 uv.uv_pipe_t
---@field public stderr                 uv.uv_pipe_t
---@field public code                   ?number
---@field public signal                 ?number
---@field public timer                  ?uv.uv_timer_t
---@field public aborted                ?boolean
---@field public data                   table<uv.uv_pipe_t, string[]>
local M = {}
M.__index = M

---@param opts                          stl.c.proc.IProps
---@return stl.c.Proc
function M.new(opts)
  local self = setmetatable({}, M)
  self.opts = opts
  self.code, self.signal = 0, 0
  self.data = {}
  if opts.run ~= false then
    self:run()
  end
  return self
end

---@param procs                         stl.c.Proc[]
---@param opts                          ?stl.c.proc.IMultiProps
function M.multi(procs, opts)
  if #procs == 0 then
    return
  end

  opts = opts or {}
  local current = 0

  local function done()
    if opts.on_exit then
      opts.on_exit(procs, procs[current]:failed())
    end
  end

  local function next()
    current = current + 1
    assert(current <= #procs, "current > #procs")
    local proc = procs[current]
    proc.opts.on_exit = function(_, err)
      if err or current == #procs then
        done()
      else
        next()
      end
    end
    proc:run()
  end

  ---@type stl.c.Proc|{procs: stl.c.Proc[]}
  local ret = setmetatable({
    procs = procs,
    run = next,
  }, {
    __index = function(_, k)
      return procs[current][k]
    end,
  })

  if opts.run ~= false then
    next()
  end
  return ret
end

---@return boolean
function M:failed()
  if self.aborted then
    return true
  end
  if self:running() then
    return false
  end
  return self.code ~= 0 or self.signal ~= 0
end

---@return boolean
function M:running()
  return self.handle and not self.handle:is_closing() or false
end

---@param signal                        string|number|nil
---@return nil
function M:kill(signal)
  close(self.stdout)
  close(self.stderr)
  if not self.handle then
    self.aborted = true
  elseif self:running() then
    self.handle:kill(signal or "sigterm")
  end
end

---@return nil
function M:run()
  assert(not self.handle, "already running")
  if self.aborted then
    return self:on_exit()
  end
  self.stdout = assert(vim.uv.new_pipe())
  self.stderr = assert(vim.uv.new_pipe())
  self.data = { [self.stdout] = {}, [self.stderr] = {} }
  local opts = vim.tbl_deep_extend("force", self.opts, {
    stdio = { nil, self.stdout, self.stderr },
    hide = true,
    args = vim.tbl_map(tostring, self.opts.args or {}),
  })
  self.handle = vim.uv.spawn(self.opts.cmd, opts, function(code, signal)
    self.code = code
    self.signal = signal
    self:on_exit()
  end)
  if not self.handle then
    self.code = 1
    self.data[self.stderr] = { "Failed to spawn " .. self.opts.cmd }
    close(self.stdout)
    close(self.stderr)
    return self:on_exit()
  end
  if self.opts.timeout then
    self.timer = assert(vim.uv.new_timer())
    self.timer:start(self.opts.timeout, 0, function()
      self:kill("sigterm")
    end)
  end
  for _, handle in ipairs({ self.stdout, self.stderr }) do
    handle:read_start(function(err, data)
      assert(not err, err)
      if data then
        self:on_data(data, handle)
      else
        close(handle)
      end
    end)
  end
end

---@return string
function M:out()
  return table.concat(self.data[self.stdout] or {})
end

---@return string
function M:err()
  return table.concat(self.data[self.stderr] or {})
end

---@return any
function M:json()
  return vim.json.decode(self:out(), {
    luanil = {
      object = true,
      array = true,
    },
  })
end

---@return string[]
function M:lines()
  return vim.split(self:out(), "\n", { plain = true })
end

---@param data                          string
---@param handle                        uv.uv_pipe_t
---@return nil
function M:on_data(data, handle)
  table.insert(self.data[handle], data)
  if self.opts.on_stdout and handle == self.stdout then
    self.opts.on_stdout(self, data)
  elseif self.opts.on_stderr and handle == self.stderr then
    self.opts.on_stderr(self, data)
  end
end

---@return nil
function M:on_exit()
  close(self.timer)
  close(self.handle)
  local check = assert(vim.uv.new_check())
  check:start(function()
    for _, handle in ipairs({ self.stdout, self.stderr }) do
      if handle and not handle:is_closing() then
        return
      end
    end
    check:stop()
    close(check)
    close(self.stdout)
    close(self.stderr)
    if self.opts.on_exit then
      self.opts.on_exit(self, self.code ~= 0 or self.signal ~= 0 or self.aborted or false)
    end
  end)
end

return M
