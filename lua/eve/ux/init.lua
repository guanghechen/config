---@class eve.ux.__mods
local __mods = {
  Search = "eve.ux.search.search",
  SearchContext = "eve.ux.search.context",
  SearchInput = "eve.ux.search.input",
  SearchMain = "eve.ux.search.main",
  SearchPreview = "eve.ux.search.preview",

  Select = "eve.ux.select",
  SelectPopup = "eve.ux.select_popup",

  Board = "eve.ux.board",
  Setting = "eve.ux.setting",
  Terminal = "eve.ux.terminal",
  Textarea = "eve.ux.textarea",
}

---@class eve.ux
---@field public __mods                 eve.ux.__mods
---@field public fn                     eve.ux.fn
---@field public nvimbar                eve.ux.nvimbar
---@field public picker                 eve.ux.picker
---@field public view                   eve.ux.view
---
---@field public Search                 eve.ux.Search
---@field public SearchContext          eve.ux.SearchContext
---@field public SearchInput            eve.ux.SearchInput
---@field public SearchMain             eve.ux.SearchMain
---@field public SearchPreview          eve.ux.SearchPreview
---
---@field public Select                 eve.ux.Select
---@field public SelectPopup            eve.ux.SelectPopup
---
---@field public Board                  eve.ux.Board
---@field public Setting                eve.ux.Setting
---@field public Terminal               eve.ux.Terminal
---@field public Textarea               eve.ux.Textarea
local M = setmetatable({
  __mods = __mods,
  fn = require("eve.ux.fn"),
  nvimbar = require("eve.ux.nvimbar"),
  picker = require("eve.ux.picker"),
  view = require("eve.ux.view"),
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
