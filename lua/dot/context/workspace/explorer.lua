---@alias dot.context.explorer.ViewtypeEnum
---| "tree"
---| "list"

---@class dot.context.explorer.data
---@field public flag_foldempty         boolean
---@field public flag_selected          boolean
---@field public flag_show_hidden       boolean
---@field public flag_viewtype          dot.context.explorer.ViewtypeEnum
---@field public trash                  boolean
---@field public width                  integer

---@class dot.context.explorer.state
---@field public flag_foldempty         stl.c.Observable
---@field public flag_selected          stl.c.Observable
---@field public flag_show_hidden       stl.c.Observable
---@field public flag_viewtype          stl.c.Observable
---@field public trash                  stl.c.Observable
---@field public width                  stl.c.Observable

---@class dot.context.explorer : dot.context.explorer.state
---@field public defaults               fun(): dot.context.explorer.data
---@field public dump                   fun(): dot.context.explorer.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.explorer.data
local M = {}

---@return dot.context.explorer.data
function M.defaults()
  ---@type dot.context.explorer.data
  return {
    flag_foldempty = true,
    flag_selected = false,
    flag_show_hidden = true,
    flag_viewtype = "tree",
    trash = false,
    width = 30,
  }
end

---@param data                          any
---@return dot.context.explorer.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.explorer.data
  if type(data) == "table" then
    if type(data.flag_foldempty) == "boolean" then
      resolved.flag_foldempty = data.flag_foldempty
    end
    if type(data.flag_selected) == "boolean" then
      resolved.flag_selected = data.flag_selected
    end
    if type(data.flag_show_hidden) == "boolean" then
      resolved.flag_show_hidden = data.flag_show_hidden
    end
    if type(data.flag_viewtype) == "string" then
      if data.flag_viewtype == "tree" or data.flag_viewtype == "list" then
        resolved.flag_viewtype = data.flag_viewtype
      end
    end
    if type(data.trash) == "boolean" then
      resolved.trash = data.trash
    end
    if type(data.width) == "number" and data.width > 0 then
      resolved.width = math.floor(data.width)
    end
  end

  ---@type dot.context.explorer.data
  return resolved
end

---@return dot.context.explorer.data
function M.dump()
  ---@type dot.context.explorer.data
  return {
    flag_foldempty = M.flag_foldempty:snapshot(),
    flag_selected = M.flag_selected:snapshot(),
    flag_show_hidden = M.flag_show_hidden:snapshot(),
    flag_viewtype = M.flag_viewtype:snapshot(),
    trash = M.trash:snapshot(),
    width = M.width:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.explorer.data

  M.flag_foldempty:next(data.flag_foldempty)
  M.flag_selected:next(data.flag_selected)
  M.flag_show_hidden:next(data.flag_show_hidden)
  M.flag_viewtype:next(data.flag_viewtype)
  M.trash:next(data.trash)
  M.width:next(data.width)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.explorer.data

---@type stl.c.Observable
M.flag_foldempty = stl.c.Observable.from_value(_defaults.flag_foldempty)

---@type stl.c.Observable
M.flag_selected = stl.c.Observable.from_value(_defaults.flag_selected)

---@type stl.c.Observable
M.flag_show_hidden = stl.c.Observable.from_value(_defaults.flag_show_hidden)

---@type stl.c.Observable
M.flag_viewtype = stl.c.Observable.from_value(_defaults.flag_viewtype)

---@type stl.c.Observable
M.trash = stl.c.Observable.from_value(_defaults.trash)

---@type stl.c.Observable
M.width = stl.c.Observable.from_value(_defaults.width)

return M
