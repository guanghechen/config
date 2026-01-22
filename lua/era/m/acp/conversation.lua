---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.conversation" ---@type string

local S = era.m.acp

---@class era.m.acp.conversation
---@field sanitize_session fun(session_data: era.m.acp.session.ISessionSerializedData): era.m.acp.session.ISessionSerializedData
---@field from_session fun(session: era.m.acp.Session): era.m.acp.conversation.IConversation
---@field normalize fun(data: any): era.m.acp.conversation.IConversation|nil
---@field to_session fun(conversation: era.m.acp.conversation.IConversation): era.m.acp.Session|nil
---@field title_from_session fun(session: era.m.acp.Session): string

---@class era.m.acp.conversation.IConversation
---@field public id                     string
---@field public title                  string
---@field public provider               era.m.acp.ProviderName
---@field public model                  string
---@field public cwd                    string
---@field public created_at             integer
---@field public updated_at             integer
---@field public session                era.m.acp.session.ISessionSerializedData
---@field public version                integer

---@class era.m.acp.conversation.IIndexItem
---@field public id                     string
---@field public title                  string
---@field public provider               era.m.acp.ProviderName
---@field public model                  string
---@field public cwd                    string
---@field public updated_at             integer

local M = {}

local DEFAULT_TITLE = "untitled"
local VERSION = 1

---@param blocks                        era.m.acp.IContentBlock[]
---@return era.m.acp.IContentBlock[]
local function sanitize_blocks(blocks)
  local sanitized = {} ---@type era.m.acp.IContentBlock[]
  for _, block in ipairs(blocks) do
    if block.type == "text" then
      sanitized[#sanitized + 1] = {
        type = "text",
        text = block.text,
      }
    elseif block.type == "resource" then
      sanitized[#sanitized + 1] = {
        type = "resource",
        resource = vim.deepcopy(block.resource),
      }
    end
  end
  return sanitized
end

---@param session_data                  era.m.acp.session.ISessionSerializedData
---@return era.m.acp.session.ISessionSerializedData
function M.sanitize_session(session_data)
  local sanitized = vim.deepcopy(session_data) ---@type era.m.acp.session.ISessionSerializedData
  if type(sanitized.messages) ~= "table" then
    sanitized.messages = {}
    return sanitized
  end

  for _, msg in ipairs(sanitized.messages) do
    if type(msg) == "table" and type(msg.content) == "table" then
      ---@cast msg { content: era.m.acp.IContentBlock[] }
      msg.content = sanitize_blocks(msg.content)
    end
  end
  return sanitized
end

---@param session                       era.m.acp.Session
---@return era.m.acp.conversation.IConversation
function M.from_session(session)
  local serialized = M.sanitize_session(session:serialize())
  local config = S.config.provider_configs[serialized.provider]
  local title = session.title or DEFAULT_TITLE
  local created_at = session.created_at or os.time()
  local updated_at = session.updated_at or created_at

  ---@type era.m.acp.conversation.IConversation
  return {
    id = serialized.id,
    title = title,
    provider = serialized.provider,
    model = (config and config.model) or "-",
    cwd = serialized.cwd,
    created_at = created_at,
    updated_at = updated_at,
    session = serialized,
    version = VERSION,
  }
end

---@param data                          any
---@return era.m.acp.conversation.IConversation|nil
function M.normalize(data)
  if type(data) ~= "table" then
    return nil
  end

  local id = type(data.id) == "string" and data.id or nil
  local provider = type(data.provider) == "string" and data.provider or nil
  local cwd = type(data.cwd) == "string" and data.cwd or nil
  local title = type(data.title) == "string" and data.title or DEFAULT_TITLE
  local created_at = type(data.created_at) == "number" and data.created_at or os.time()
  local updated_at = type(data.updated_at) == "number" and data.updated_at or created_at
  local session = type(data.session) == "table" and data.session or nil

  if id == nil or provider == nil or cwd == nil or session == nil then
    return nil
  end

  ---@type era.m.acp.conversation.IConversation
  return {
    id = id,
    title = title,
    provider = provider,
    model = type(data.model) == "string" and data.model or "-",
    cwd = cwd,
    created_at = created_at,
    updated_at = updated_at,
    session = session,
    version = type(data.version) == "number" and data.version or VERSION,
  }
end

---@param conversation                  era.m.acp.conversation.IConversation
---@return era.m.acp.Session|nil
function M.to_session(conversation)
  local session = S.session.from_serialized(conversation.session)
  if session == nil then
    return nil
  end

  session.title = conversation.title or DEFAULT_TITLE
  session.created_at = conversation.created_at or os.time()
  session.updated_at = conversation.updated_at or session.created_at
  return session
end

---@param session                       era.m.acp.Session
---@return string
function M.title_from_session(session)
  local title = session.title
  if title == nil or title == "" then
    return DEFAULT_TITLE
  end
  return title
end

return M
