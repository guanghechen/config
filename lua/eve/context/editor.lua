local Observable = require("eve.collection.observable")

---@class eve.context.editor : eve.t.context.editor
local M = {}

---@return eve.t.context.editor.data
function M.defaults()
  ---@type eve.t.context.data.dressing
  local dressing = {
    autopairs = true,
    winsep = true,
  }

  ---@type eve.t.context.data.theme
  local theme = {
    theme = "gruvbox_dark",
    transparency = false,
    relativenumber = true,
  }

  ---@type eve.t.context.editor.data
  local data = {
    dressing = dressing,
    theme = theme,
  }
  return data
end

---@return eve.t.context.editor.data
function M.dump()
  if M.state == nil then
    error("[eve.context.editor] the state is not initialized.")
    return M.defaults()
  end

  local state = M.state ---@type eve.t.context.editor.state

  ---@type eve.t.context.data.dressing
  local dressing = {
    autopairs = state.dressing.autopairs:snapshot(),
    winsep = state.dressing.winsep:snapshot(),
  }

  ---@type eve.t.context.data.theme
  local theme = {
    theme = state.theme.theme:snapshot(),
    transparency = state.theme.transparency:snapshot(),
    relativenumber = state.theme.relativenumber:snapshot(),
  }

  ---@type eve.t.context.editor.data
  local data = {
    dressing = dressing,
    theme = theme,
  }
  return data
end

---@param data                          eve.t.context.editor.data
---@return nil
function M.load(data)
  if M.state == nil then
    ---@type eve.t.context.state.dressing
    local dressing = {
      autopairs = Observable.from_value(data.dressing.autopairs),
      winsep = Observable.from_value(data.dressing.winsep),
    }

    ---@type eve.t.context.state.theme
    local theme = {
      theme = Observable.from_value(data.theme.theme),
      transparency = Observable.from_value(data.theme.transparency),
      relativenumber = Observable.from_value(data.theme.relativenumber),
    }

    ---@type eve.t.context.editor.state
    local state = {
      dressing = dressing,
      theme = theme,
    }
    M.state = state
  else
    local state = M.state ---@type eve.t.context.editor.state

    ---! dressing
    state.dressing.autopairs:next(data.dressing.autopairs)
    state.dressing.winsep:next(data.dressing.winsep)

    ---! theme
    state.theme.theme:next(data.theme.theme)
    state.theme.transparency:next(data.theme.transparency)
    state.theme.relativenumber:next(data.theme.relativenumber)
  end
end

---@param data                          any
---@return eve.t.context.editor.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.t.context.editor.data

  if type(data) ~= "table" then
    return resolved
  end
  ---@cast data eve.t.context.editor.data

  ---resolve dressing data
  if type(data.dressing) == "table" then
    if type(data.dressing.autopairs) == "boolean" then
      resolved.dressing.autopairs = data.dressing.autopairs
    end
    if type(data.dressing.winsep) == "boolean" then
      resolved.dressing.winsep = data.dressing.winsep
    end
  end

  ---resolve theme data
  if type(data.theme) == "table" then
    if type(data.theme.theme) == "string" then
      resolved.theme.theme = data.theme.theme
    end
    if type(data.theme.transparency) == "boolean" then
      resolved.theme.transparency = data.theme.transparency
    end
    if type(data.theme.relativenumber) == "boolean" then
      resolved.theme.relativenumber = data.theme.relativenumber
    end
  end

  return resolved
end

---@param data                          eve.t.context.editor.data
---@return boolean
function M.equals(data)
  local cur = M.dump() ---@type eve.t.context.editor.data

  ---compare dressing data
  if
    data.dressing.autopairs ~= cur.dressing.autopairs --
    or data.dressing.winsep ~= cur.dressing.winsep
  then
    return false
  end

  ---compare theme data
  if
    data.theme.theme ~= cur.theme.theme
    or data.theme.transparency ~= cur.theme.transparency
    or data.theme.relativenumber ~= cur.theme.relativenumber
  then
    return false
  end

  return true
end

return M
