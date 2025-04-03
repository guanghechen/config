---@class eve.ux.__mods
local __mods = {
  Nvimbar = "eve.ux.nvimbar",
  Printer = "eve.ux.printer",
  Search = "eve.ux.search.search",
  SearchContext = "eve.ux.search.context",
  SearchInput = "eve.ux.search.input",
  SearchMain = "eve.ux.search.main",
  SearchPreview = "eve.ux.search.preview",
  Setting = "eve.ux.setting",
  Terminal = "eve.ux.terminal",
  Textarea = "eve.ux.textarea",
}

---@class eve.ux
---@field public __mods                 eve.ux.__mods
---
---@field public Nvimbar                eve.ux.Nvimbar
---@field public Printer                eve.ux.Printer
---@field public Setting                eve.ux.Setting
---@field public Search                 eve.ux.search.Search
---@field public SearchContext          eve.ux.search.Context
---@field public SearchInput            eve.ux.search.Input
---@field public SearchMain             eve.ux.search.Main
---@field public SearchPreview          eve.ux.search.Preview
---@field public Terminal               eve.ux.Terminal
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
