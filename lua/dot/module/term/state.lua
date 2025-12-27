local __module_name__ = "dot.module.term.state" ---@type string

require("dot.module.term.types")

local DEFAULT_TERM_TYPE = "5fd8db97-7c8c-4629-a99a-a2696709018b" ---@type string

local metamap = {} ---@type table<string, dot.module.term.IMeta>
local termlist = {} ---@type string[]

---@class dot.module.term.state
---@field public o_termuuid             ark.c.Observable
---@field protected __remove__          fun(termuuid: string): nil
---@field protected __unregister__      fun(termuuid: string): nil
local M = {}

M.o_termuuid = ark.c.Observable.from_value("") ---@type ark.c.Observable

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
---@return dot.module.term.IMeta|nil
function M.at(index)
  local termuuid = termlist[index] ---@type string|nil
  if termuuid then
    return termuuid, metamap[termuuid]
  end
end

---@return integer
---@return string|nil
function M.current()
  local termuuid = M.o_termuuid:snapshot() ---@type string
  local index = M.indexof(termuuid) ---@type integer
  return index, termuuid
end

---@param typ                           string
---@return integer
---@return dot.module.term.IMeta|nil
function M.find_index_by_type(typ)
  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    local termmeta = metamap[termuuid] ---@type dot.module.term.IMeta|nil
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
  M.o_termuuid:next(termuuid)
  return true
end

---@param termuuid                      string
---@return dot.module.term.IMeta|nil
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
---@return dot.module.term.IMeta|nil
function M.indexof_by_bufnr(bufnr)
  if bufnr == nil or bufnr < 1 then
    return -1
  end

  for index = 1, #termlist, 1 do
    local termuuid = termlist[index] ---@type string
    local termmeta = metamap[termuuid] ---@type dot.module.term.IMeta|nil
    if termmeta ~= nil and termmeta.bufnr == bufnr then
      return index, termmeta
    end
  end
  return -1
end

---@return fun(): dot.module.term.IMeta|nil, integer|nil
function M:iterator()
  local i = 0 ---@type integer

  ---@return dot.module.term.IMeta|nil
  ---@return integer|nil
  return function()
    while i < #termlist do
      i = i + 1
      local termuuid = termlist[i] ---@type string|nil
      if termuuid == nil then
        return nil, nil
      end

      local termmeta = metamap[termuuid] ---@type dot.module.term.IMeta|nil
      if termmeta ~= nil then
        return termmeta, i
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
---@return dot.module.term.IMeta|nil
function M.pick_next_term(termuuid)
  for index = 1, #termlist, 1 do
    local uuid = termlist[index] ---@type string
    if uuid ~= termuuid then
      local termmeta = metamap[uuid] ---@type dot.module.term.IMeta|nil
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

---@param params                        dot.module.term.ICreateParams
---@return dot.module.term.IMeta
function M.create(params)
  local termuuid = params.uuid ---@type string
  if termuuid == nil or #termuuid < 1 then
    error(string.format("Invalid UUID: '%s'", termuuid), 2)
  end

  local typ = params.type or DEFAULT_TERM_TYPE ---@type string

  local termmeta = metamap[termuuid] ---@type dot.module.term.IMeta|nil
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
  vim.bo[bufnr].filetype = ark.filetype.TERM
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
        local _, _termmeta = dot.term.state.indexof_by_bufnr(bufnr)
        if _termmeta then
          dot.term.event.on_closed(_termmeta)
        else
          dot.buf.close(bufnr)
        end
      end)
    end,
  })

  ---@type dot.module.term.IMeta
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
        definition:execute()
      end,
    }
  end
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-,>",
    aliases = { "<C-[>" },
    desc = dot.command.definitions.term.focus_left.desc,
    callback = function()
      dot.command.definitions.term.focus_left:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-.>",
    aliases = { "<C-]>" },
    desc = dot.command.definitions.term.focus_right.desc,
    callback = function()
      dot.command.definitions.term.focus_right:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-S-,>",
    aliases = { "<C-S-[>" },
    desc = dot.command.definitions.term.swap_left.desc,
    callback = function()
      dot.command.definitions.term.swap_left:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-S-.>",
    aliases = { "<C-S-]>" },
    desc = dot.command.definitions.term.swap_right.desc,
    callback = function()
      dot.command.definitions.term.swap_right:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-n>",
    desc = dot.command.definitions.term.rename.desc,
    callback = function()
      dot.command.definitions.term.rename:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-/>",
    desc = dot.command.definitions.term.create.desc,
    callback = function()
      dot.command.definitions.term.create:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-d>",
    desc = dot.command.definitions.term.destroy.desc,
    callback = function()
      dot.command.definitions.term.destroy:execute()
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
      dot.term.event.on_closed(termmeta)
    end,
  }
  ark.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

  metamap[termuuid] = termmeta
  termlist[#termlist + 1] = termuuid

  M.o_termuuid:next(termuuid)
  return termmeta
end

---@param termmeta                      dot.module.term.IMeta
---@param params                        dot.module.term.IUpdateParams
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

---@protected
---@param termuuid                      string
---@return nil
function M.__remove__(termuuid)
  local k = 0 ---@type integer
  for index = 1, #termlist, 1 do
    local uuid = termlist[index] ---@type string
    if uuid ~= termuuid then
      k = k + 1
      termlist[k] = uuid ---@type string
    end
  end
  ark.table.truncate_inline(termlist, k)
end

---@protected
---@param termuuid                      string
---@return nil
function M.__unregister__(termuuid)
  metamap[termuuid] = nil
end

return M
