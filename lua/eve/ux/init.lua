---@class eve.ux.__mods
local __mods = {
  fn = "eve.ux.fn",
  nvimbar = "eve.ux.nvimbar",
  picker = "eve.ux.picker",
  retriever = "eve.ux.retriever",
  searcher = "eve.ux.searcher",
  view = "eve.ux.view",
  widget = "eve.ux.widget",

  Board = "eve.ux.board",
  Select = "eve.ux.select",
  Setting = "eve.ux.setting",
  Textarea = "eve.ux.textarea",
}

---@class eve.ux
---@field public __mods                 eve.ux.__mods
---@field public fn                     eve.ux.fn
---@field public nvimbar                eve.ux.nvimbar
---@field public picker                 eve.ux.picker
---@field public retriever              eve.ux.retriever
---@field public searcher               eve.ux.searcher
---@field public view                   eve.ux.view
---@field public widget                 eve.ux.widget
---
---@field public Board                  eve.ux.Board
---@field public Select                 eve.ux.Select
---@field public Setting                eve.ux.Setting
---@field public Textarea               eve.ux.Textarea
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
