---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.acp.conversation_store" ---@type string

local S = era.m.acp

---@class era.m.acp.conversation_store
---@field save fun(conversation: era.m.acp.conversation.IConversation): nil
---@field load fun(id: string): era.m.acp.conversation.IConversation|nil
---@field load_latest fun(): era.m.acp.conversation.IConversation|nil

local M = {}

---@type table<string, { index: era.m.acp.conversation.IIndexItem[], conversations: table<string, era.m.acp.conversation.IConversation> }>
local _stores = {}

---@return string
local function workspace_key()
  return dot.path.workspace()
end

---@return { index: era.m.acp.conversation.IIndexItem[], conversations: table<string, era.m.acp.conversation.IConversation> }
local function get_store()
  local key = workspace_key()
  if _stores[key] == nil then
    _stores[key] = {
      index = {},
      conversations = {},
    }
  end
  return _stores[key]
end

---@param conversation                  era.m.acp.conversation.IConversation
---@return nil
function M.save(conversation)
  if conversation == nil or conversation.id == nil then
    return
  end

  local store = get_store()
  store.conversations[conversation.id] = vim.deepcopy(conversation)

  local items = store.index
  local updated = false
  for _, item in ipairs(items) do
    if item.id == conversation.id then
      item.title = conversation.title
      item.provider = conversation.provider
      item.model = conversation.model
      item.cwd = conversation.cwd
      item.updated_at = conversation.updated_at
      updated = true
      break
    end
  end

  if not updated then
    items[#items + 1] = {
      id = conversation.id,
      title = conversation.title,
      provider = conversation.provider,
      model = conversation.model,
      cwd = conversation.cwd,
      updated_at = conversation.updated_at,
    }
  end
end

---@param id                            string
---@return era.m.acp.conversation.IConversation|nil
function M.load(id)
  if id == nil or id == "" then
    return nil
  end

  local store = get_store()
  local conversation = store.conversations[id]
  return S.conversation.normalize(conversation)
end

---@return era.m.acp.conversation.IConversation|nil
function M.load_latest()
  local store = get_store()
  local items = store.index
  if #items == 0 then
    return nil
  end

  local latest = nil ---@type era.m.acp.conversation.IIndexItem|nil
  for _, item in ipairs(items) do
    if latest == nil or (item.updated_at or 0) > (latest.updated_at or 0) then
      latest = item
    end
  end

  if latest == nil then
    return nil
  end

  return M.load(latest.id)
end

return M
