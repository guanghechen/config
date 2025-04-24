---@class eve.ux.__mods
local __mods = {
  Search = "eve.ux.search.search",
  SearchContext = "eve.ux.search.context",
  SearchInput = "eve.ux.search.input",
  SearchMain = "eve.ux.search.main",
  SearchPreview = "eve.ux.search.preview",

  Select = "eve.ux.select",
  FileSelect = "eve.ux.select_file",
  SelectPopup = "eve.ux.select_popup",

  Board = "eve.ux.board",
  Nvimbar = "eve.ux.nvimbar",
  Printer = "eve.ux.printer",
  Setting = "eve.ux.setting",
  Terminal = "eve.ux.terminal",
  Textarea = "eve.ux.textarea",
}

---@class eve.ux
---@field public __mods                 eve.ux.__mods
---@field public fn                     eve.ux.fn
---
---@field public Search                 eve.ux.Search
---@field public SearchContext          eve.ux.SearchContext
---@field public SearchInput            eve.ux.SearchInput
---@field public SearchMain             eve.ux.SearchMain
---@field public SearchPreview          eve.ux.SearchPreview
---
---@field public Select                 eve.ux.Select
---@field public FileSelect             eve.ux.FileSelect
---@field public SelectPopup            eve.ux.SelectPopup
---
---@field public Board                  eve.ux.Board
---@field public Nvimbar                eve.ux.Nvimbar
---@field public Printer                eve.ux.Printer
---@field public Setting                eve.ux.Setting
---@field public Terminal               eve.ux.Terminal
---@field public Textarea               eve.ux.Textarea
local M = setmetatable({
  __mods = __mods,
  fn = require("eve.ux.fn"),
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
