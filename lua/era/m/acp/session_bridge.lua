---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.session_bridge" ---@type string

local S = era.m.acp

---@class era.m.acp.session_bridge
---@field attach fun(session: era.m.acp.Session): nil
---@field detach fun(session: era.m.acp.Session): nil
---@field rename_title fun(session: era.m.acp.Session, title: string): nil

local M = {}

---@type table<string, { session: era.m.acp.Session, sub: stl.c.IUnsubscribable, debounced: stl.timer.IDisposableCallable }>
local _bridges = {}

local DEBOUNCE_MS = 400

---@param session                       era.m.acp.Session
---@return nil
local function save_session(session)
  session.updated_at = os.time()
  local conversation = S.conversation.from_session(session)
  S.conversation_store.save(conversation)
end

---@param session                       era.m.acp.Session
---@return nil
function M.attach(session)
  if session == nil then
    return
  end

  if _bridges[session.id] ~= nil then
    return
  end

  local debounced = stl.timer.debounce(function()
    save_session(session)
  end, DEBOUNCE_MS)

  local sub = session.changed:subscribe(stl.c.Subscriber.new({
    on_next = function()
      debounced()
    end,
  }), true)

  _bridges[session.id] = {
    session = session,
    sub = sub,
    debounced = debounced,
  }
end

---@param session                       era.m.acp.Session
---@return nil
function M.detach(session)
  if session == nil then
    return
  end

  local bridge = _bridges[session.id]
  if bridge == nil then
    return
  end

  bridge.sub:unsubscribe()
  bridge.debounced:dispose()
  _bridges[session.id] = nil
end

---@param session                       era.m.acp.Session
---@param title                         string
---@return nil
function M.rename_title(session, title)
  if session == nil then
    return
  end

  session.title = title
  save_session(session)
end

return M
