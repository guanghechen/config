---@class eve.ux.__mods
local __mods = {
  Board = "eve.ux.board",
  SelectPopup = "eve.ux.select_popup",
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
---@field public SelectPopup            eve.ux.SelectPopup
---@field public Setting                eve.ux.Setting
---@field public Textarea               eve.ux.Textarea
local M = setmetatable({
  __mods = __mods,
  fn = require("eve.ux.fn"),
  nvimbar = require("eve.ux.nvimbar"),
  picker = require("eve.ux.picker"),
  retriever = require("eve.ux.retriever"),
  searcher = require("eve.ux.searcher"),
  view = require("eve.ux.view"),
  widget = require("eve.ux.widget"),
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
