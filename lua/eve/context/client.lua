local Observable = require("eve.collection.observable")

---@class eve.context.client : t.eve.context.client
local M = {}

---@return t.eve.context.client.data
function M.defaults()
  ---@type t.eve.context.data.theme
  local theme = {
    theme = "one_half",
    mode = "dark",
    transparency = false,
    relativenumber = true,
    auto_integration = false,
  }

  ---@type t.eve.context.client.data
  local data = {
    theme = theme,
  }
  return data
end

---@return t.eve.context.client.data
function M.dump()
  if M.state == nil then
    error("[eve.context.client] the state is not initialized.")
    return M.defaults()
  end

  local state = M.state ---@type t.eve.context.client.state

  ---@type t.eve.context.data.theme
  local theme = {
    theme = state.theme.theme:snapshot(),
    mode = state.theme.mode:snapshot(),
    transparency = state.theme.transparency:snapshot(),
    relativenumber = state.theme.relativenumber:snapshot(),
    auto_integration = state.theme.auto_integration:snapshot(),
  }

  ---@type t.eve.context.client.data
  local data = {
    theme = theme,
  }
  return data
end

---@param data                          t.eve.context.client.data
---@return nil
function M.load(data)
  if M.state == nil then
    ---@type t.eve.context.state.theme
    local theme = {
      theme = Observable.from_value(data.theme.theme),
      mode = Observable.from_value(data.theme.mode),
      transparency = Observable.from_value(data.theme.transparency),
      relativenumber = Observable.from_value(data.theme.relativenumber),
      auto_integration = Observable.from_value(data.theme.auto_integration),
    }

    ---@type t.eve.context.client.state
    local state = {
      theme = theme,
    }
    M.state = state
  else
    local state = M.state ---@type t.eve.context.client.state

    ---! theme
    state.theme.theme:next(data.theme.theme)
    state.theme.mode:next(data.theme.mode)
    state.theme.transparency:next(data.theme.transparency)
    state.theme.relativenumber:next(data.theme.relativenumber)
    state.theme.auto_integration:next(data.theme.auto_integration)
  end
end

---@param data                          any
---@return t.eve.context.client.data
function M.normalize(data)
  local resolved = M.defaults() ---@type t.eve.context.client.data

  if type(data) ~= "table" then
    return resolved
  end
  ---@cast data t.eve.context.client.data

  if type(data.theme) == "table" then
    if type(data.theme.theme) == "string" then
      resolved.theme.theme = data.theme.theme
    end
    if type(data.theme.mode) == "string" then
      resolved.theme.mode = data.theme.mode
    end
    if type(data.theme.transparency) == "boolean" then
      resolved.theme.transparency = data.theme.transparency
    end
    if type(data.theme.relativenumber) == "boolean" then
      resolved.theme.relativenumber = data.theme.relativenumber
    end
    if type(data.theme.auto_integration) == "boolean" then
      resolved.theme.auto_integration = data.theme.auto_integration
    end
  end

  return resolved
end

---@param data                          t.eve.context.client.data
---@return boolean
function M.equals(data)
  local cur = M.dump() ---@type t.eve.context.client.data

  ---compare theme data
  if
    data.theme.theme ~= cur.theme.theme
    or data.theme.mode ~= cur.theme.mode
    or data.theme.transparency ~= cur.theme.transparency
    or data.theme.relativenumber ~= cur.theme.relativenumber
    or data.theme.auto_integration ~= cur.theme.auto_integration
  then
    return false
  end

  return true
end

return M
