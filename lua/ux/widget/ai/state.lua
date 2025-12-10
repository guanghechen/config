local __module_name__ = "ux.widget.ai.state" ---@type string

local config = require("ux.widget.ai.config")

---@class ux.widget.ai.state
local M = {}

---@type ux.widget.ai.IAttachedSource[]
local _attached_sources = {}

---@type ark.c.Observable
M.o_attached = ark.c.Observable.from_value(0)

std.fn.observe({ M.o_attached }, function()
  std.status.dirtier_statusline:mark_dirty()
end, true)

---@return ux.widget.ai.IAttachedSource[]
function M.get_attached()
  return vim.list_slice(_attached_sources)
end

---@return integer
function M.get_attached_count()
  return #_attached_sources
end

---@param source                        ux.widget.ai.ISource
---@return boolean
function M.is_attached(source)
  for _, attached in ipairs(_attached_sources) do
    if attached.id == source.id then
      return true
    end
  end
  return false
end

---@param source                        ux.widget.ai.ISource
---@return nil
function M.attach(source)
  if M.is_attached(source) then
    return
  end

  _attached_sources[#_attached_sources + 1] = vim.tbl_extend("force", source, { attached_at = vim.uv.now() })
  M.o_attached:next(#_attached_sources)

  local agent_label = config.agent_labels[source.agent] or source.agent
  ark.reporter.info({
    from = __module_name__,
    subject = "Agent Attached",
    message = string.format("Attached to %s.", agent_label),
  })
end

---@param source_id                     string
---@param close_terminal                ?boolean
---@return nil
function M.detach(source_id, close_terminal)
  local new_sources = {} ---@type ux.widget.ai.IAttachedSource[]
  local detached_source ---@type ux.widget.ai.IAttachedSource|nil

  for _, attached in ipairs(_attached_sources) do
    if attached.id ~= source_id then
      new_sources[#new_sources + 1] = attached
    else
      detached_source = attached
    end
  end

  if detached_source then
    _attached_sources = new_sources
    M.o_attached:next(#_attached_sources)

    local agent_label = config.agent_labels[detached_source.agent] or detached_source.agent
    ark.reporter.info({
      from = __module_name__,
      subject = "Agent Detached",
      message = string.format("Detached from %s.", agent_label),
    })

    if close_terminal ~= false and detached_source.type == "tmux" and detached_source.tmux_pane then
      local term = require("ux.widget.ai.term")
      local term_uuid = string.format("ai:%s:%s", detached_source.agent, detached_source.tmux_pane.pane_id)
      local termmeta = term.get(term_uuid)
      if termmeta then
        term.on_closed(termmeta)
      end
    end
  end
end

---@return nil
function M.detach_all()
  if #_attached_sources > 0 then
    _attached_sources = {}
    M.o_attached:next(0)

    ark.reporter.info({
      from = __module_name__,
      subject = "Agent Detached",
      message = "Detached from all agents.",
    })
  end
end

---@return string[]
function M.get_attached_names()
  local names = {} ---@type string[]
  local seen = {} ---@type table<string, boolean>

  for _, attached in ipairs(_attached_sources) do
    if not seen[attached.agent] then
      seen[attached.agent] = true
      names[#names + 1] = attached.agent
    end
  end

  table.sort(names)
  return names
end

---@param term_uuid                     string
---@return nil
function M.detach_by_term_uuid(term_uuid)
  local pane_id = term_uuid:match("^ai:[^:]+:(%%[^:]+)$")
  if pane_id then
    M.detach("tmux:" .. pane_id, false)
  else
    M.detach(term_uuid, false)
  end
end

return M
