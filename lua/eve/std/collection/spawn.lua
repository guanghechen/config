--- https://github.com/folke/snacks.nvim/blob/6917597f6d22d79fcd0bf9b0eb7845f7ffdc80a0/lua/snacks/util/spawn.lua

---@param handle                        uv.uv_handle_t|nil
---@return nil
local function close(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

---@class eve.std.collection.spawn.Proc
---@field public opts                   eve.std.collection.spawn.IOptions
---@field public handle                 ?uv.uv_process_t
---@field public stdout                 uv.uv_pipe_t
---@field public stderr                 uv.uv_pipe_t
---@field public code                   ?number
---@field public signal                 ?number
---@field public timer                  ?uv.uv_timer_t
---@field public aborted                ?boolean
---@field public data                   table<uv.uv_pipe_t, string[]>
local Proc = {}
Proc.__index = Proc

---@param opts                          eve.std.collection.spawn.IOptions
---@return eve.std.collection.spawn.Proc
function Proc.new(opts)
  local self = setmetatable({}, Proc)
  self.opts = opts
  self.code, self.signal = 0, 0
  self.data = {}
  if opts.run ~= false then
    self:run()
  end
  return self
end

---@return boolean
function Proc:failed()
  return (self.code ~= 0 or self.signal ~= 0) and not self:running()
end

---@return boolean
function Proc:running()
  return self.handle and not self.handle:is_closing() or false
end

---@param signal                        string|number|nil
---@return nil
function Proc:kill(signal)
  close(self.stdout)
  close(self.stderr)
  if not self.handle then
    self.aborted = true
  elseif self:running() then
    self.handle:kill(signal or "sigterm")
  end
end

---@param opts                          eve.builtin.debug.ICmdParams|{}|nil
function Proc:debug(opts)
  ---@type eve.builtin.debug.ICmdParams
  opts = eve.table.merge_config({}, opts or {}, {
    cmd = self.opts.cmd,
    args = self.opts.args,
    cwd = self.opts.cwd,
  })
  opts.props = opts.props or {}
  if not self:running() then
    opts.props.code = ("`%d`"):format(self.code)
    opts.props.signal = ("`%d`"):format(self.signal)
    if self.aborted then
      opts.props.aborted = "`true`"
    end
  end
  if self:failed() then
    opts.level = vim.log.levels.ERROR
  end
  local out = vim.trim(self:out() .. "\n" .. self:err())
  if out ~= "" then
    opts.footer = "# Output\n```\n" .. out .. "\n```"
  end
  return eve.debug.cmd(opts)
end

---@return nil
function Proc:run()
  assert(not self.handle, "already running")
  if self.aborted then
    return self:on_exit()
  end
  self.stdout = assert(vim.uv.new_pipe())
  self.stderr = assert(vim.uv.new_pipe())
  self.data = { [self.stdout] = {}, [self.stderr] = {} }
  if self.opts.debug then
    vim.schedule(function()
      self:debug()
    end)
  end
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
function Proc:out()
  return table.concat(self.data[self.stdout] or {})
end

---@return string
function Proc:err()
  return table.concat(self.data[self.stderr] or {})
end

---@return string[]
function Proc:lines()
  return vim.split(self:out(), "\n", { plain = true })
end

---@param data                          string
---@param handle                        uv.uv_pipe_t
---@return nil
function Proc:on_data(data, handle)
  table.insert(self.data[handle], data)
  if self.opts.on_stdout and handle == self.stdout then
    self.opts.on_stdout(self, data)
  elseif self.opts.on_stderr and handle == self.stderr then
    self.opts.on_stderr(self, data)
  end
end

---@return nil
function Proc:on_exit()
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

---@class eve.std.collection.Spawn
local M = {}

---@class eve.std.collection.spawn.IOptions: uv.spawn.options,{}
---@field public cmd                    string
---@field public args                   ?(string|number)[]
---@field public timeout                ?number
---@field public run                    ?boolean
---@field public debug                  ?boolean
---@field public on_stdout              ?fun(proc: eve.std.collection.spawn.Proc, data: string)
---@field public on_stderr              ?fun(proc: eve.std.collection.spawn.Proc, data: string)
---@field public on_exit                ?fun(proc: eve.std.collection.spawn.Proc, err: boolean)

---@class eve.std.collection.spawn.Multi: eve.std.collection.spawn.IOptions,{}
---@field cmd? nil
---@field on_exit? fun(procs: eve.std.collection.spawn.Proc[], err: boolean)

---@param procs                         eve.std.collection.spawn.Proc[]
---@param opts                          ?eve.std.collection.spawn.Multi
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
    proc.opts = eve.table.merge_config(vim.deepcopy(opts), proc.opts, {
      on_exit = function(_, err)
        if err or current == #procs then
          done()
        else
          next()
        end
      end,
    })
    proc:run()
  end

  ---@type eve.std.collection.spawn.Proc|{procs: eve.std.collection.spawn.Proc[]}
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

M.new = Proc.new

return M
