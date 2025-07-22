local __module_name__ = "eve.builtin.term" ---@type string

---@class eve.builtin.term.IMeta
---@field public uuid                   string
---@field public bufnr                  integer
---@field public name                   string
---@field public cmd                    string[]|string
---@field public cwd                    string
---@field public env                    table<string, string>|nil
---@field public permanent              boolean
---@field public keymaps                std.t.IKeymap[]
---@field public jobid                  integer|nil
---@field public on_closed              fun(): nil

---@class eve.builtin.term.ICreateParams
---@field public uuid                   string
---@field public name                   string
---@field public cmd                    ?string[]|string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public permanent              ?boolean
---@field public keymaps                ?std.t.IKeymap[]
---@field public on_closed              ?fun(): nil

---@class eve.builtin.term.IUpdateParams
---@field public name                   ?string
---@field public cmd                    ?string[]|string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public on_closed              ?fun(): nil

local metamap = {} ---@type table<string, eve.builtin.term.IMeta>
local termlist = {} ---@type string[]
local o_bufnr = std.Observable.from_value(0) ---@type std.collection.Observable

---@class eve.builtin.term
---@field public o_bufnr                std.collection.IObservable
local M = {}

M.o_bufnr = o_bufnr ---@type std.collection.IObservable

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
  local cmd = params.cmd or vim.env.SHELL or vim.o.shell ---@type string[]|string
  local cwd = params.cwd or std.path.cwd() ---@type string
  local env = params.env ---@type table<string, string>|nil
  local permanent = not not params.permanent ---@type boolean
  local on_closed = params.on_closed or std.fn.noop ---@type fun(): nil|nil

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = eve.filetype.TERM
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false

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
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "v" },
    key = "<C-/>",
    desc = eve.command.definitions.term.create.desc,
    callback = function()
      vim.cmd(eve.command.definitions.term.create.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "v" },
    key = "<C-r>",
    desc = eve.command.definitions.term.rename.desc,
    callback = function()
      vim.cmd(eve.command.definitions.term.rename.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "v" },
    key = "q",
    desc = "term: close",
    callback = function()
      eve.buf.close(bufnr)
    end,
  }
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  ---@type eve.builtin.term.IMeta
  termmeta = {
    uuid = termuuid,
    bufnr = bufnr,
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

  o_bufnr:next(termmeta.bufnr)
  return termmeta
end

---@return eve.builtin.term.IMeta|nil
function M.current()
  local bufnr = o_bufnr:snapshot() ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    for index = 1, #termlist, 1 do
      local uuid = termlist[index] ---@type string
      local termmeta = metamap[uuid] ---@type eve.builtin.term.IMeta|nil
      if termmeta ~= nil and termmeta.bufnr == bufnr then
        return termmeta
      end
    end
  end

  local termmeta = M.__pick_next_termmeta__() ---@type eve.builtin.term.IMeta|nil
  if termmeta ~= nil then
    o_bufnr:next(termmeta.bufnr)
  end
  return termmeta
end

---@param index                         integer
---@return boolean
function M.focus(index)
  local count = 0 ---@type integer
  for i = 1, #termlist, 1 do
    local termuuid = termlist[i] ---@type string
    local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
    if termmeta ~= nil and termmeta.bufnr > 0 and vim.api.nvim_buf_is_valid(termmeta.bufnr) then
      count = count + 1
      if count == index then
        o_bufnr:next(termmeta.bufnr)
        return true
      end
    end
  end
  return false
end

---@return fun(): eve.builtin.term.IMeta|nil, integer|nil
function M:iterator()
  local i = 0 ---@type integer
  local index = 0 ---@type integer

  ---@return eve.builtin.term.IMeta|nil
  ---@return integer|nil
  return function()
    while i < #termlist do
      i = i + 1 ---@type integer
      local termuuid = termlist[i] ---@type string|nil
      if termuuid == nil then
        return nil, nil
      end

      local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
      if termmeta == nil then
        std.reporter.error({
          from = __module_name__,
          subject = "Invalid termuuid",
          message = string.format("Cannot retrieve the termmeta by the given termuuid: %s", termuuid),
          details = { termuuid = termuuid, index = i },
        })
      else
        if termmeta.bufnr > 0 and vim.api.nvim_buf_is_valid(termmeta.bufnr) then
          index = index + 1 ---@type integer
          return termmeta, index
        end
      end
    end
    return nil, nil
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

----------------------------------------------------------------------------------------------------

---@param termmeta                      eve.builtin.term.IMeta
---@return nil
function M.on_closed(termmeta)
  if termmeta.jobid ~= nil then
    vim.fn.jobstop(termmeta.jobid)
    termmeta.jobid = nil
  end

  if not termmeta.permanent then
    local k = 0 ---@type integer
    for index = 1, #termlist, 1 do
      local termuuid = termlist[index] ---@type string
      if termuuid ~= termmeta.uuid then
        k = k + 1
        termlist[k] = termuuid ---@type string
      end
    end
    std.table.truncate_inline(termlist, k)
    metamap[termmeta.uuid] = nil
  end

  local bufnr = termmeta.bufnr ---@type integer
  termmeta.bufnr = 0

  local next_termmeta = M.__pick_next_termmeta__(termmeta.uuid) ---@type eve.builtin.term.IMeta|nil
  if next_termmeta ~= nil then
    o_bufnr:next(next_termmeta.bufnr)
  end

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    eve.buf.close(bufnr)
  end
  termmeta.on_closed()
end

---@param bufnr                         integer|nil
---@return nil
function M.on_buf_deleted(bufnr)
  local termmeta = M.resolve_by_bufnr(bufnr) ---@type eve.builtin.term.IMeta|nil
  if termmeta ~= nil then
    M.on_closed(termmeta)
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@param termuuid                      string|nil
---@return eve.builtin.term.IMeta|nil
function M.__pick_next_termmeta__(termuuid)
  for index = 1, #termlist, 1 do
    local uuid = termlist[index] ---@type string
    if uuid ~= termuuid then
      local termmeta = metamap[uuid] ---@type eve.builtin.term.IMeta|nil
      if termmeta ~= nil and termmeta.bufnr > 0 and vim.api.nvim_buf_is_valid(termmeta.bufnr) then
        return termmeta
      end
    end
  end
end

return M
