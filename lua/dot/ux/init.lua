---@class dot.ux.__mods
local __mods = {
  picker = "dot.ux.picker",
  retriever = "dot.ux.retriever",
  searcher = "dot.ux.searcher",
  view = "dot.ux.view",
  widget = "dot.ux.widget",

  Board = "dot.ux.board",
  Select = "dot.ux.select",
  Setting = "dot.ux.setting",
  Textarea = "dot.ux.textarea",
}

---@class dot.ux
---@field public __mods                 dot.ux.__mods
---@field public picker                 dot.ux.picker
---@field public retriever              dot.ux.retriever
---@field public searcher               dot.ux.searcher
---@field public view                   dot.ux.view
---@field public widget                 dot.ux.widget
---
---@field public Board                  dot.ux.Board
---@field public Select                 dot.ux.Select
---@field public Setting                dot.ux.Setting
---@field public Textarea               dot.ux.Textarea
local M = setmetatable({ __mods = __mods }, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
