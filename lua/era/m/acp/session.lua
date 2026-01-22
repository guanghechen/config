---@class era.m.acp.session.ISessionOpts
---@field public id                     ?string
---@field public cwd                    string
---@field public provider               era.m.acp.ProviderName

---@class era.m.acp.session.ISessionSerializedData
---@field public id                     string
---@field public cwd                    string
---@field public provider               era.m.acp.ProviderName
---@field public messages               era.m.acp.IMessage[]
---@field public auto_approve_all       boolean
---@field public last_session_id        ?string

---@class era.m.acp.Session
---@field public id                     string
---@field public cwd                    string
---@field public provider               era.m.acp.ProviderName
---@field public messages               era.m.acp.IMessage[]
---@field public title                  string
---@field public created_at             integer
---@field public updated_at             integer
---@field public abort                  stl.c.Observable
---@field public generating             stl.c.Observable
---@field public changed                stl.c.Observable
---@field public plan                   stl.c.Observable
---@field public context_files          stl.c.Observable
---@field public auto_approve_all       boolean
---@field public last_session_id        ?string
---@field protected _disposed           boolean
---@field protected _pending_tool_calls table<string, era.m.acp.IToolCall>
---@field protected _current_tool_call  ?era.m.acp.IToolCall
---@field protected _expanded_tool_ids  table<string, boolean>
local M = {}
M.__index = M

---@param opts                          era.m.acp.session.ISessionOpts
---@return era.m.acp.Session
function M.new(opts)
  local self = setmetatable({}, M)
  self.id = opts.id or yoz.fn.uuid()
  self.cwd = opts.cwd
  self.provider = opts.provider
  self.messages = {}
  self.title = "untitled"
  self.created_at = os.time()
  self.updated_at = self.created_at
  self.abort = stl.c.Observable.from_value(false)
  self.generating = stl.c.Observable.from_value(false)
  self.changed = stl.c.Observable.from_value(nil)
  self.plan = stl.c.Observable.from_value(nil)
  self.context_files = stl.c.Observable.from_value({})
  self.auto_approve_all = false
  self.last_session_id = nil
  self._disposed = false
  self._pending_tool_calls = {}
  self._current_tool_call = nil
  self._expanded_tool_ids = {}
  return self
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  self:cancel()
  self.abort:dispose()
  self.generating:dispose()
  self.changed:dispose()
  self.plan:dispose()
  self.context_files:dispose()
  self.messages = {}
  self._pending_tool_calls = {}
  self._current_tool_call = nil
  self._expanded_tool_ids = {}
end

---@param content                       string|era.m.acp.IContentBlock[]
---@return era.m.acp.IMessage
function M:add_user_message(content)
  ---@type era.m.acp.IMessage
  local msg = {
    id = yoz.fn.uuid(),
    role = "user",
    content = content,
    timestamp = os.time(),
  }
  self.messages[#self.messages + 1] = msg
  self.changed:next({ kind = "user_message", id = msg.id })
  return msg
end

---@param content_blocks                era.m.acp.IContentBlock[]
---@return era.m.acp.IMessage
function M:add_user_message_with_content(content_blocks)
  return self:add_user_message(content_blocks)
end

---@param content                       string
---@param tool_calls                    ?era.m.acp.IToolCall[]
---@return era.m.acp.IMessage
function M:add_assistant_message(content, tool_calls)
  ---@type era.m.acp.IMessage
  local msg = {
    id = yoz.fn.uuid(),
    role = "assistant",
    content = content,
    tool_calls = tool_calls,
    timestamp = os.time(),
  }
  self.messages[#self.messages + 1] = msg
  self.changed:next({ kind = "assistant_message", id = msg.id })
  return msg
end

---@param id                            string
---@param name                          string
---@return era.m.acp.IToolCall
function M:start_tool_call(id, name)
  ---@type era.m.acp.IToolCall
  local tool_call = {
    id = id,
    name = name,
    arguments = {},
    arguments_json = "",
    status = "pending",
  }
  self._pending_tool_calls[id] = tool_call
  self._current_tool_call = tool_call
  return tool_call
end

---@param id                            string
---@param delta                         string
---@return nil
function M:append_tool_arguments(id, delta)
  local tool_call = self._pending_tool_calls[id]
  if tool_call ~= nil then
    tool_call.arguments_json = (tool_call.arguments_json or "") .. delta
  end
end

---@param id                            string
---@return era.m.acp.IToolCall|nil
function M:finish_tool_call(id)
  local tool_call = self._pending_tool_calls[id]
  if tool_call ~= nil and tool_call.arguments_json then
    local ok, args = pcall(vim.json.decode, tool_call.arguments_json)
    if ok and type(args) == "table" then
      tool_call.arguments = args
    end
    tool_call.status = "running"
  end
  self._current_tool_call = nil
  return tool_call
end

---@return era.m.acp.IToolCall[]
function M:get_pending_tool_calls()
  local calls = {} ---@type era.m.acp.IToolCall[]
  for _, call in pairs(self._pending_tool_calls) do
    if call.status == "running" then
      calls[#calls + 1] = call
    end
  end
  return calls
end

---@return boolean
function M:has_pending_tool_calls()
  return next(self._pending_tool_calls) ~= nil
end

---@return nil
function M:cancel()
  self.abort:next(true)
end

---@return nil
function M:reset_abort()
  self.abort:next(false)
end

---@return nil
function M:clear()
  self.messages = {}
  self._pending_tool_calls = {}
  self._current_tool_call = nil
  self._expanded_tool_ids = {}
  self.abort:next(false)
  self.generating:next(false)
  self.plan:next(nil)
  self.context_files:next({})
  self.auto_approve_all = false
  self.changed:next({ kind = "clear" })
end

---@param plan                          era.m.acp.IPlan
---@return nil
function M:update_plan(plan)
  self.plan:next(plan)
end

---@param file                          era.m.acp.IContextFile
---@return nil
function M:add_context_file(file)
  local current_files = self.context_files:snapshot() or {}
  local new_files = vim.deepcopy(current_files)
  new_files[#new_files + 1] = file
  self.context_files:next(new_files)
end

---@param tool_id                       string
---@return nil
function M:toggle_tool_expanded(tool_id)
  self._expanded_tool_ids[tool_id] = not self._expanded_tool_ids[tool_id]
end

---@param tool_id                       string
---@return boolean
function M:is_tool_expanded(tool_id)
  return self._expanded_tool_ids[tool_id] == true
end

---@param tool_id                       string
---@param result                        era.m.acp.IToolResult
---@return nil
function M:set_tool_result(tool_id, result)
  for _, msg in ipairs(self.messages) do
    if msg.tool_calls then
      for _, tc in ipairs(msg.tool_calls) do
        if tc.id == tool_id then
          tc.result = result.output
          tc.error = result.error
          tc.status = result.is_error and "error" or "completed"
          return
        end
      end
    end
  end

  local tool_call = self._pending_tool_calls[tool_id]
  if tool_call then
    tool_call.result = result.output
    tool_call.error = result.error
    tool_call.status = result.is_error and "error" or "completed"
  end
  self.changed:next({ kind = "tool_result", id = tool_id })
end

---@return era.m.acp.session.ISessionSerializedData
function M:serialize()
  return {
    id = self.id,
    cwd = self.cwd,
    provider = self.provider,
    messages = vim.deepcopy(self.messages),
    auto_approve_all = self.auto_approve_all,
    last_session_id = self.last_session_id,
  }
end

---@param data                          era.m.acp.session.ISessionSerializedData
---@return era.m.acp.Session
function M.from_serialized(data)
  local session = M.new({
    id = data.id,
    cwd = data.cwd,
    provider = data.provider,
  })
  session.messages = data.messages or {}
  session.auto_approve_all = data.auto_approve_all or false
  session.last_session_id = data.last_session_id
  return session
end

return M
