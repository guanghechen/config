---@class eve.ux.search2.__mods
local __mods = {
  Finder = "eve.ux.search2.finder",
  Preview = "eve.ux.search2.preview",
  Result = "eve.ux.search2.result",

  BasicComposer = "eve.ux.search2.composer.basic",
  FiletreeComposer = "eve.ux.search2.composer.filetree",

  FiletreeView = "eve.ux.search2.view.filetree",
}

---@class eve.ux.search2
---@field public __mods                 eve.ux.search2.__mods
---
---@field public Finder                 eve.ux.search2.Finder
---@field public Preview                eve.ux.search2.Preview
---@field public Result                 eve.ux.search2.Result
---
---@field public BasicComposer          eve.ux.search2.BasicComposer
---@field public FiletreeComposer       eve.ux.search2.FiletreeComposer
---
---@field public FiletreeView           eve.ux.search2.FiletreeView
local M = setmetatable({
  __mods = __mods,
  fn = require("eve.ux.fn"),
  nvimbar = require("eve.ux.nvimbar"),
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
