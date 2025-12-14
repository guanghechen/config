local __module_name__ = "dot.term" ---@type string

local DEFAULT_TERM_TYPE = "5fd8db97-7c8c-4629-a99a-a2696709018b" ---@type string

---@class dot.t.ITermMeta
---@field public uuid                   string
---@field public type                   string
---@field public name                   string
---@field public bufnr                  integer
---@field public cmd                    string[]|string
---@field public cwd                    string
---@field public env                    table<string, string>|nil
---@field public permanent              boolean
---@field public hidewipe               boolean
---@field public keymaps                ark.t.IKeymap[]
---@field public jobid                  integer|nil
---@field public on_closed              fun(): nil
---@field public on_focused             fun(): nil
---@field public on_resized             fun(): nil

---@class dot.t.ITermCreateParams
---@field public uuid                   string
---@field public type                   string
---@field public name                   string
---@field public cmd                    ?string[]|string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public permanent              ?boolean
---@field public hidewipe               ?boolean
---@field public keymaps                ?ark.t.IKeymap[]
---@field public on_closed              ?fun(): nil
---@field public on_focused             ?fun(): nil
---@field public on_resized             ?fun(): nil

---@class dot.t.ITermUpdateParams
---@field public name                   ?string
---@field public type                   ?string
---@field public cmd                    ?string[]|string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public on_closed              ?fun(): nil
---@field public on_focused             ?fun(): nil
---@field public on_resized             ?fun(): nil

local metamap = {} ---@type table<string, dot.t.ITermMeta>
local termlist = {} ---@type string[]
local o_termuuid = ark.c.Observable.from_value("") ---@type ark.c.Observable

---@class dot.term
---@field public o_termuuid             ark.c.Observable
local M = {}

M.o_termuuid = o_termuuid ---@type ark.c.Observable

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
---@return dot.t.ITermMeta|nil
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

---@param typ                           string
---@return integer
---@return dot.t.ITermMeta|nil
function M.find_index_by_type(typ)
  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    local termmeta = metamap[termuuid] ---@type dot.t.ITermMeta|nil
    if termmeta ~= nil and termmeta.type == typ then
      return index, termmeta
    end
  end
  return -1
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
---@return dot.t.ITermMeta|nil
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
---@return dot.t.ITermMeta|nil
function M.indexof_by_bufnr(bufnr)
  if bufnr == nil or bufnr < 1 then
    return -1
  end

  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    local termmeta = metamap[termuuid] ---@type dot.t.ITermMeta|nil
    if termmeta ~= nil and termmeta.bufnr == bufnr then
      return index, termmeta
    end
  end
  return -1
end

---@return fun(): dot.t.ITermMeta|nil, integer|nil
function M:iterator()
  local i = 0 ---@type integer
  local index = 0 ---@type integer

  ---@return dot.t.ITermMeta|nil
  ---@return integer|nil
  return function()
    while i < #termlist do
      i = i + 1 ---@type integer
      local termuuid = termlist[i] ---@type string|nil
      if termuuid == nil then
        return nil, nil
      end

      local termmeta = metamap[termuuid] ---@type dot.t.ITermMeta|nil
      if termmeta ~= nil then
        return termmeta, index
      end

      ark.reporter.error({
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
---@return dot.t.ITermMeta|nil
function M.pick_next_term(termuuid)
  for index = 1, #termlist, 1 do
    local uuid = termlist[index] ---@type string
    if uuid ~= termuuid then
      local termmeta = metamap[uuid] ---@type dot.t.ITermMeta|nil
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

---@param params                        dot.t.ITermCreateParams
---@return dot.t.ITermMeta
function M.create(params)
  local termuuid = params.uuid ---@type string
  if termuuid == nil or #termuuid < 1 then
    error(string.format("Invalid UUID: '%s'", termuuid), 2)
  end

  local typ = params.type or DEFAULT_TERM_TYPE ---@type string

  local termmeta = metamap[termuuid] ---@type dot.t.ITermMeta|nil
  if termmeta ~= nil then
    ark.reporter.error({
      from = __module_name__,
      subject = "Duplicate UUID",
      message = string.format("A terminal with UUID '%s' already exists.", termuuid),
      details = { params = params },
    })
    return termmeta
  end

  local name = params.name ---@type string
  local cmd = params.cmd or vim.env.SHELL or vim.o.shell ---@type string[]|string
  local cwd = params.cwd or dot.path.cwd() ---@type string
  local env = params.env ---@type table<string, string>|nil
  local permanent = not not params.permanent ---@type boolean
  local hidewipe = not not params.hidewipe ---@type boolean
  local on_closed = params.on_closed or ark.fn.noop ---@type fun(): nil|nil
  local on_focused = params.on_focused or ark.fn.noop ---@type fun(): nil|nil
  local on_resized = params.on_resized or ark.fn.noop ---@type fun(): nil|nil
  local keymaps = params.keymaps and vim.list_slice(params.keymaps) or {} ---@type ark.t.IKeymap[]

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = dot.filetype.TERM
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
        local _, _termmeta = dot.term.indexof_by_bufnr(bufnr)
        if _termmeta then
          M.on_closed(_termmeta)
        else
          dot.buf.close(bufnr)
        end
      end)
    end,
  })

  ---@type dot.t.ITermMeta
  termmeta = {
    uuid = termuuid,
    type = typ,
    name = name,
    bufnr = bufnr,
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

  for i = 1, 9 do
    local key = string.format("<C-%d>", i) ---@type string
    local definition = dot.command.definitions.term["focus_" .. tostring(i)] ---@type dot.command.IDefinition
    keymaps[#keymaps + 1] = {
      modes = { "i", "n", "t", "x" },
      key = key,
      desc = definition.desc,
      callback = function()
        dot.command.execute(definition.uuid)
      end,
    }
  end
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-,>",
    aliases = { "<C-[>" },
    desc = dot.command.definitions.term.focus_left.desc,
    callback = function()
      dot.command.execute(dot.command.definitions.term.focus_left.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-.>",
    aliases = { "<C-]>" },
    desc = dot.command.definitions.term.focus_right.desc,
    callback = function()
      dot.command.execute(dot.command.definitions.term.focus_right.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-S-,>",
    aliases = { "<C-S-[>" },
    desc = dot.command.definitions.term.swap_left.desc,
    callback = function()
      dot.command.execute(dot.command.definitions.term.swap_left.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-S-.>",
    aliases = { "<C-S-]>" },
    desc = dot.command.definitions.term.swap_right.desc,
    callback = function()
      dot.command.execute(dot.command.definitions.term.swap_right.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-n>",
    desc = dot.command.definitions.term.rename.desc,
    callback = function()
      dot.command.execute(dot.command.definitions.term.rename.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-/>",
    desc = dot.command.definitions.term.create.desc,
    callback = function()
      dot.command.execute(dot.command.definitions.term.create.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-d>",
    desc = dot.command.definitions.term.destroy.desc,
    callback = function()
      dot.command.execute(dot.command.definitions.term.destroy.uuid)
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<esc>",
    desc = "term: feedback esc to terminal (fix the conflict caused by  the csi u)",
    expr = true,
    replace_keycodes = true,
    callback = function()
      return "<esc>"
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "n", "x" },
    key = "q",
    desc = "term: close",
    callback = function()
      M.on_closed(termmeta)
    end,
  }
  ark.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  metamap[termuuid] = termmeta
  termlist[#termlist + 1] = termuuid

  o_termuuid:next(termuuid)
  return termmeta
end

---@param termmeta                      dot.t.ITermMeta
---@param params                        dot.t.ITermUpdateParams
---@return boolean
function M.update(termmeta, params)
  if params.name ~= nil then
    termmeta.name = params.name
  end
  if params.type ~= nil then
    termmeta.type = params.type
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

---@param termmeta                      dot.t.ITermMeta
---@return nil
function M.on_closed(termmeta)
  if termmeta.jobid ~= nil then
    vim.fn.jobstop(termmeta.jobid)
    termmeta.jobid = nil
  end

  local bufnr = termmeta.bufnr ---@type integer
  termmeta.bufnr = 0

  local next_termmeta = M.pick_next_term(termmeta.uuid) ---@type dot.t.ITermMeta|nil
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
  ark.table.truncate_inline(termlist, k)

  if not termmeta.permanent then
    metamap[termmeta.uuid] = nil
  end

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    dot.buf.close(bufnr)
  end
  termmeta.on_closed()

  vim.schedule(function()
    vim.cmd("checktime")
  end)
end

---@param termmeta                      dot.t.ITermMeta
---@return nil
function M.on_focused(termmeta)
  termmeta.on_focused()
end

return M
