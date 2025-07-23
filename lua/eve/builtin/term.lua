local __module_name__ = "eve.builtin.term" ---@type string

---@class eve.builtin.term.IMeta
---@field public uuid                   string
---@field public bufnr                  integer
---@field public name                   string
---@field public cmd                    string[]|string
---@field public cwd                    string
---@field public env                    table<string, string>|nil
---@field public permanent              boolean
---@field public hidewipe               boolean
---@field public keymaps                std.t.IKeymap[]
---@field public jobid                  integer|nil
---@field public on_closed              fun(): nil
---@field public on_focused             fun(): nil
---@field public on_resized             fun(): nil

---@class eve.builtin.term.ICreateParams
---@field public uuid                   string
---@field public name                   string
---@field public cmd                    ?string[]|string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public permanent              ?boolean
---@field public hidewipe               ?boolean
---@field public keymaps                ?std.t.IKeymap[]
---@field public on_closed              ?fun(): nil
---@field public on_focused             ?fun(): nil
---@field public on_resized             ?fun(): nil

---@class eve.builtin.term.IUpdateParams
---@field public name                   ?string
---@field public cmd                    ?string[]|string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public on_closed              ?fun(): nil
---@field public on_focused             ?fun(): nil
---@field public on_resized             ?fun(): nil

local metamap = {} ---@type table<string, eve.builtin.term.IMeta>
local termlist = {} ---@type string[]
local o_termuuid = std.Observable.from_value("") ---@type std.collection.Observable

---@class eve.builtin.term
---@field public o_termuuid             std.collection.IObservable
local M = {}

M.o_termuuid = o_termuuid ---@type std.collection.IObservable

---@param termuuid                      string
---@return boolean
function M.append(termuuid)
  local N = #termlist ---@type integer
  for index = 1, N, 1 do
    if termlist[index] == termuuid then
      return false
    end
  end

  termlist[#termlist + 1] = termuuid ---@type string
  return true
end

---@param index                         integer
---@return string|nil
---@return eve.builtin.term.IMeta|nil
function M.at(index)
  local termuuid = termlist[index] ---@type string|nil
  if termuuid then
    return termuuid, metamap[termuuid]
  end
end

---@return integer
---@return string|nil
function M.current()
  local termuuid = o_termuuid:snapshot() ---@type string
  local index = M.indexof(termuuid) ---@type integer
  return index, termuuid
end

---@param index                         integer
---@return boolean
function M.focus(index)
  local termuuid = termlist[index] ---@type string|nil
  if termuuid == nil then
    return false
  end
  o_termuuid:next(termuuid)
  return true
end

---@param termuuid                      string
---@return eve.builtin.term.IMeta|nil
function M.get(termuuid)
  return metamap[termuuid]
end

---@param termuuid                      string
---@return boolean
function M.has(termuuid)
  return metamap[termuuid] ~= nil
end

---@param termuuid                      string
---@return integer
function M.indexof(termuuid)
  local N = #termlist ---@type integer
  for index = 1, N, 1 do
    if termlist[index] == termuuid then
      return index
    end
  end
  return -1
end

---@param bufnr                         integer|nil
---@return integer
---@return eve.builtin.term.IMeta|nil
function M.indexof_by_bufnr(bufnr)
  if bufnr == nil or bufnr < 1 then
    return -1
  end

  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    local termmeta = metamap[termuuid] ---@type eve.builtin.term.IMeta|nil
    if termmeta ~= nil and termmeta.bufnr == bufnr then
      return index
    end
  end
  return -1
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
      if termmeta ~= nil then
        return termmeta, index
      end

      std.reporter.error({
        from = __module_name__,
        subject = "Invalid termuuid",
        message = string.format("Cannot retrieve the termmeta by the given termuuid: %s", termuuid),
        details = { termuuid = termuuid, index = i },
      })
    end
    return nil, nil
  end
end

---@param termuuid                      string|nil
---@return eve.builtin.term.IMeta|nil
function M.pick_next_term(termuuid)
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

---@param index                         integer
---@param termuuid                      string
function M.put(index, termuuid)
  termlist[index] = termuuid
end

---@return integer
function M.size()
  return #termlist
end

----------------------------------------------------------------------------------------------------

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
  local hidewipe = not not params.hidewipe ---@type boolean
  local on_closed = params.on_closed or std.fn.noop ---@type fun(): nil|nil
  local on_focused = params.on_focused or std.fn.noop ---@type fun(): nil|nil
  local on_resized = params.on_resized or std.fn.noop ---@type fun(): nil|nil

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = eve.filetype.TERM
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false

  if hidewipe then
    vim.bo[bufnr].bufhidden = "wipe"
  end

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = bufnr,
    callback = function()
      vim.schedule(function()
        local _, _termmeta = eve.term.indexof_by_bufnr(bufnr)
        if _termmeta then
          M.on_closed(_termmeta)
        else
          eve.buf.close(bufnr)
        end
      end)
    end,
  })

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
    key = "<C-[>",
    desc = eve.command.definitions.term.focus_left.desc,
    callback = function()
      vim.cmd(eve.command.definitions.term.focus_left.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "v" },
    key = "<C-]>",
    desc = eve.command.definitions.term.focus_right.desc,
    callback = function()
      vim.cmd(eve.command.definitions.term.focus_right.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "v" },
    key = "<C-S-[>",
    desc = eve.command.definitions.term.swap_left.desc,
    callback = function()
      vim.cmd(eve.command.definitions.term.swap_left.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "v" },
    key = "<C-S-]>",
    desc = eve.command.definitions.term.swap_right.desc,
    callback = function()
      vim.cmd(eve.command.definitions.term.swap_right.uuid)
    end,
  }
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
    modes = { "i", "n", "t", "v" },
    key = "<C-w>",
    desc = eve.command.definitions.term.destroy.desc,
    callback = function()
      vim.cmd(eve.command.definitions.term.destroy.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "v" },
    key = "q",
    desc = "term: close",
    callback = function()
      local _, _termmeta = M.indexof_by_bufnr(bufnr)
      if _termmeta ~= nil then
        M.on_closed(_termmeta)
      else
        eve.buf.close(bufnr)
      end
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
    hidewipe = hidewipe,
    on_closed = on_closed,
    on_focused = on_focused,
    on_resized = on_resized,
    jobid = nil,
  }
  metamap[termuuid] = termmeta
  termlist[#termlist + 1] = termuuid

  o_termuuid:next(termuuid)
  return termmeta
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
  if params.on_closed ~= nil then
    termmeta.on_closed = params.on_closed
  end
  if params.on_focused ~= nil then
    termmeta.on_focused = params.on_focused
  end
  if params.on_resized ~= nil then
    termmeta.on_resized = params.on_resized
  end
  return true
end

----------------------------------------------------------------------------------------------------

---@param bufnr                         integer|nil
---@return nil
function M.on_buf_deleted(bufnr)
  local _, termmeta = M.indexof_by_bufnr(bufnr) ---@type integer
  if termmeta ~= nil then
    M.on_closed(termmeta)
  end
end

---@param termmeta                      eve.builtin.term.IMeta
---@return nil
function M.on_closed(termmeta)
  if termmeta.jobid ~= nil then
    vim.fn.jobstop(termmeta.jobid)
    termmeta.jobid = nil
  end

  local bufnr = termmeta.bufnr ---@type integer
  termmeta.bufnr = 0

  local next_termmeta = M.pick_next_term(termmeta.uuid) ---@type eve.builtin.term.IMeta|nil
  if next_termmeta ~= nil then
    o_termuuid:next(next_termmeta.uuid)
  else
    o_termuuid:next("")
  end

  local k = 0 ---@type integer
  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    if termuuid ~= termmeta.uuid then
      k = k + 1
      termlist[k] = termuuid ---@type string
    end
  end
  std.table.truncate_inline(termlist, k)

  if not termmeta.permanent then
    metamap[termmeta.uuid] = nil
  end

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    eve.buf.close(bufnr)
  end
  termmeta.on_closed()
end

---@param termmeta                      eve.builtin.term.IMeta
---@return nil
function M.on_focused(termmeta)
  termmeta.on_focused()
end

return M
