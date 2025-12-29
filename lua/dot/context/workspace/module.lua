---@class dot.context.module.data
---@field public notepad_source         string
---@field public paste_image_filepath   string

---@class dot.context.module.state
---@field public notepad_source         stl.c.Observable
---@field public paste_image_filepath   stl.c.Observable

---@class dot.context.module : dot.context.module.state
---@field public defaults               fun(): dot.context.module.data
---@field public dump                   fun(): dot.context.module.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.module.data
local M = {}

---@return dot.context.module.data
function M.defaults()
  ---@type dot.context.module.data
  return {
    notepad_source = "workspace",
    paste_image_filepath = "local/img/screenshot.png",
  }
end

---@param data                          any
---@return dot.context.module.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.module.data
  if type(data) == "table" then
    if type(data.notepad_source) == "string" then
      resolved.notepad_source = data.notepad_source
    end
    if type(data.paste_image_filepath) == "string" then
      resolved.paste_image_filepath = data.paste_image_filepath
    end
  end

  ---@type dot.context.module.data
  return resolved
end

---@return dot.context.module.data
function M.dump()
  ---@type dot.context.module.data
  return {
    notepad_source = M.notepad_source:snapshot(),
    paste_image_filepath = M.paste_image_filepath:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.module.data

  M.notepad_source:next(data.notepad_source)
  M.paste_image_filepath:next(data.paste_image_filepath)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.module.data
M.notepad_source = stl.c.Observable.from_value(_defaults.notepad_source)
M.paste_image_filepath = stl.c.Observable.from_value(_defaults.paste_image_filepath)

return M
