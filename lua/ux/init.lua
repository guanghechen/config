---@class ux.__mods
local __mods = {
  fn = "ux.fn",
  nvimbar = "ux.nvimbar",
  picker = "ux.picker",
  retriever = "ux.retriever",
  searcher = "ux.searcher",
  view = "ux.view",
  widget = "ux.widget",

  Board = "ux.board",
  Select = "ux.select",
  Setting = "ux.setting",
  Textarea = "ux.textarea",
}

---@class ux
---@field public __mods                 ux.__mods
---@field public fn                     ux.fn
---@field public nvimbar                ux.nvimbar
---@field public picker                 ux.picker
---@field public retriever              ux.retriever
---@field public searcher               ux.searcher
---@field public view                   ux.view
---@field public widget                 ux.widget
---
---@field public Board                  ux.Board
---@field public Select                 ux.Select
---@field public Setting                ux.Setting
---@field public Textarea               ux.Textarea
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
