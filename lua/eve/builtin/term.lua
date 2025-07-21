local __module_name__ = "eve.builtin.term" ---@type string

---@class eve.builtin.term.IMeta
---@field public uuid                   string
---@field public bufnr                  integer
---@field public name                   string
---@field public cmd                    string
---@field public cwd                    string
---@field public env                    table<string, string>|nil
---@field public permanent              boolean
---@field public keymaps                std.t.IKeymap[]
---@field public jobid                  integer|nil
---@field public on_closed              fun(): nil

---@class eve.builtin.term.ICreateParams
---@field public uuid                   string
---@field public name                   string
---@field public cmd                    ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public permanent              ?boolean
---@field public keymaps                ?std.t.IKeymap[]
---@field public on_closed              ?fun(): nil

---@class eve.builtin.term.IUpdateParams
---@field public name                   ?string
---@field public cmd                    ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public on_closed              ?fun(): nil

local metamap = {} ---@type table<string, eve.builtin.term.IMeta>
local termlist = {} ---@type string[]
local o_bufnr = std.Observable.from_value(0) ---@type std.collection.Observable

---@class eve.builtin.term
---@field public o_bufnr                std.collection.IObservable
local M = {}

---@param params                        eve.builtin.term.ICreateParams
---@return eve.builtin.term.IMeta
function M.create(params)
  local termuuid = params.uuid ---@type string
  if termuuid == nil or #termuuid < 1 then
    error(string.format("Invalid UUID: '%s'", termuuid), 2)
  end

  local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
  if termmeta ~= nil then
    std.reporter.error({
      from = __module_name__,
      subject = "Duplicate UUID",
      message = string.format("A terminal with UUID '%s' already exists.", termuuid),
      details = { params = params },
    })
    return termmeta
  end

  local name = params.name ---@type string
  local cmd = params.cmd or vim.env.SHELL or vim.o.shell ---@type string
  local cwd = params.cwd or std.path.cwd() ---@type string
  local env = params.env ---@type table<string, string>|nil
  local permanent = not not params.permanent ---@type boolean
  local on_closed = params.on_closed or std.fn.noop ---@type fun(): nil|nil

  local keymaps = params.keymaps and vim.list_slice(params.keymaps) or {} ---@type std.t.IKeymap[]
  for i = 1, 9 do
    local key = string.format("<C-%d>", i) ---@type string
    local definition = eve.command.definitions.term["focus_" .. tostring(i)] ---@type eve.builtin.command.IDefinition
    keymaps[#keymaps + 1] = {
      modes = { "i", "n", "t", "v" },
      key = key,
      desc = definition.desc,
      callback = function()
        vim.cmd(definition.uuid)
      end,
    }
  end

  ---@type eve.builtin.term.IMeta
  termmeta = {
    uuid = termuuid,
    bufnr = 0,
    name = name,
    cmd = cmd,
    cwd = cwd,
    env = env,
    keymaps = keymaps,
    permanent = permanent,
    on_closed = on_closed,
    jobid = nil,
  }
  metamap[termuuid] = termmeta
  termlist[#termlist + 1] = termuuid

  M.start_as_needed(termuuid) ---@type integer
  o_bufnr:next(termmeta.bufnr)
  return termmeta
end

---@return integer|nil
function M.current()
  local bufnr = o_bufnr:snapshot() ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  for _, termuuid in ipairs(termlist) do
    local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
    if termmeta ~= nil and vim.api.nvim_buf_is_valid(termmeta.bufnr) then
      o_bufnr:next(termmeta.bufnr)
      return termmeta.bufnr
    end
  end
end

---@param bufnr                         integer|nil
---@return nil
function M.destroy_by_bufnr(bufnr)
  if bufnr == nil or bufnr < 1 then
    return
  end

  local bufnr_next = nil ---@type integer|nil
  local target_meta = nil ---@type eve.builtin.term.IMeta|nil
  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
    if termmeta ~= nil then
      if termmeta.bufnr == bufnr then
        target_meta = termmeta
        break
      end
    end
  end

  if target_meta ~= nil then
    if target_meta.jobid ~= nil then
      vim.fn.jobstop(target_meta.jobid)
      target_meta.jobid = nil
    end
    eve.buf.close(bufnr)
  end

  if bufnr_next ~= nil then
    M.switch(bufnr_next)
  end
end

---@param name                          string
---@return nil
function M.destroy_by_name(name)
  local N = 0 ---@type integer
  local k = 0 ---@type integer
  local target_meta = nil ---@type eve.builtin.term.IMeta|nil
  for index = 1, N, 1 do
    local termuuid = termlist[index] ---@type string
    local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
    if termmeta ~= nil then
      if termmeta.name == name then
        target_meta = termmeta
      else
        k = k + 1
        termlist[k] = termuuid ---@type string
      end
    end
  end
  std.table.truncate_inline(termlist, k)

  if target_meta ~= nil then
    if target_meta.jobid ~= nil then
      vim.fn.jobstop(target_meta.jobid)
      target_meta.jobid = nil
    end
    eve.buf.close(target_meta.bufnr)
  end
end

---@return fun(): eve.builtin.term.IMeta|nil, integer|nil
function M:iterator()
  local index = 0 ---@type integer

  ---@return eve.builtin.term.IMeta|nil
  ---@return integer|nil
  return function()
    index = index + 1 ---@type integer
    local termuuid = termlist[index] ---@type string|nil
    if termuuid == nil then
      return nil, nil
    end

    local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
    return termmeta, index
  end
end

---@param bufnr                         integer|nil
---@return eve.builtin.term.IMeta|nil
function M.resolve_by_bufnr(bufnr)
  if bufnr == nil or bufnr < 1 then
    return
  end

  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
    if termmeta ~= nil and termmeta.bufnr == bufnr then
      return termmeta
    end
  end
end

---@param name                          string
---@return eve.builtin.term.IMeta|nil
function M.resolve_by_name(name)
  for index = 1, #termlist, 1 do
    local uuid = termlist[index] ---@type string
    local termmeta = metamap[uuid] ---@type eve.builtin.term.IMeta|nil
    if termmeta ~= nil and termmeta.name == name then
      return termmeta
    end
  end
end

---@param bufnr                         integer|nil
---@return nil
function M.switch(bufnr)
  if bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal" then
    o_bufnr:next(bufnr)
    return true
  end

  local bufnr_current = o_bufnr:snapshot() ---@type integer|nil
  if bufnr_current == nil or not vim.api.nvim_buf_is_valid(bufnr_current) then
    for index = 1, #termlist, 1 do
      local termuuid = termlist[index] ---@type string
      local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
      if termmeta ~= nil and termmeta.bufnr > 0 and vim.api.nvim_buf_is_valid(termmeta.bufnr) then
        o_bufnr:next(termmeta.bufnr)
        return
      end
    end
  end
end

---@param termmeta                      eve.builtin.term.IMeta
---@param params                        eve.builtin.term.IUpdateParams
---@return boolean
function M.update(termmeta, params)
  if params.name ~= nil then
    termmeta.name = params.name
  end
  if params.cmd ~= nil then
    termmeta.cmd = params.cmd
  end
  if params.cwd ~= nil then
    termmeta.cwd = params.cwd
  end
  if params.env ~= nil then
    termmeta.env = params.env
  end
  return true
end

---@param termuuid                      string
---@return nil
function M.start_as_needed(termuuid)
  local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
  if termmeta == nil then
    std.reporter.error({
      from = __module_name__,
      subject = "Start Terminal",
      message = "Terminal metadata not found.",
      details = { termuuid = termuuid },
    })
    return
  end

  local bufnr = termmeta.bufnr ---@type integer
  if bufnr <= 0 or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].filetype = eve.filetype.TERM
    vim.bo[bufnr].swapfile = false
    eve.nvim.bindkeys(termmeta.keymaps, { bufnr = bufnr, noremap = true, silent = true })
    termmeta.bufnr = bufnr
  end

  if termmeta.jobid ~= nil and vim.fn.jobwait({ termmeta.jobid }, 0)[1] == -1 then
    return
  end

  vim.schedule(function()
    termmeta.jobid = nil

    local cmd = eve.shell.format_command(termmeta.cmd) ---@type string
    local jobid = vim.fn.jobstart(cmd, {
      cwd = termmeta.cwd,
      env = termmeta.env,
      term = true,
    })
    if jobid <= 0 then
      return
    end

    termmeta.jobid = jobid

    -- Clean up job reference when terminal closes
    vim.api.nvim_create_autocmd("TermClose", {
      once = true,
      buffer = bufnr,
      callback = function()
        termmeta.jobid = nil
        eve.buf.close(bufnr)
      end,
    })
  end)
end

----------------------------------------------------------------------------------------------------

---@param bufnr                         integer|nil
---@return nil
function M.on_close(bufnr)
  local termmeta = M.resolve_by_bufnr(bufnr) ---@type eve.builtin.term.IMeta|nil
  if termmeta == nil then
    return
  end

  if termmeta.jobid ~= nil then
    vim.fn.jobstop(termmeta.jobid)
    termmeta.jobid = nil
  end

  local k = 0 ---@type integer
  local bufnr_next = nil ---@type integer|nil
  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    if termuuid ~= termmeta.uuid then
      k = k + 1
      termlist[k] = termuuid ---@type string

      if bufnr_next == nil then
        local meta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
        if meta ~= nil and meta.bufnr > 0 and vim.api.nvim_buf_is_valid(meta.bufnr) then
          bufnr_next = meta.bufnr ---@type integer|nil
        end
      end
    end
  end
  std.table.truncate_inline(termlist, k)

  if bufnr_next ~= nil then
    M.switch(bufnr_next)
  end

  termmeta.on_closed()
end

return M
