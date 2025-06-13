---@class eve.ux.picker.__mods
local __mods = {
  Finder = "eve.ux.picker.finder",
  Preview = "eve.ux.picker.preview",
  Result = "eve.ux.picker.result",

  BasicComposer = "eve.ux.picker.composer.basic",
  FiletreeComposer = "eve.ux.picker.composer.filetree",
  ListComposer = "eve.ux.picker.composer.list",

  ListRetriever = "eve.ux.picker.retriever.list",
  TreeRetriever = "eve.ux.picker.retriever.tree",
}

---@class eve.ux.picker
---@field public __mods                 eve.ux.picker.__mods
---
---@field public Finder                 eve.ux.picker.Finder
---@field public Preview                eve.ux.picker.Preview
---@field public Result                 eve.ux.picker.Result
---
---@field public BasicComposer          eve.ux.picker.BasicComposer
---@field public FiletreeComposer       eve.ux.picker.FiletreeComposer
---@field public ListComposer           eve.ux.picker.ListComposer
---
---@field public ListRetriever          eve.ux.picker.ListRetriever
---@field public TreeRetriever          eve.ux.picker.TreeRetriever
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
