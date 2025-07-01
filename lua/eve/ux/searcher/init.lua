---@class eve.ux.searcher.__mods
local __mods = {
  Finder = "eve.ux.searcher.finder",
  Preview = "eve.ux.searcher.preview",
  Result = "eve.ux.searcher.result",

  BasicComposer = "eve.ux.searcher.composer.basic",
  FiletreeComposer = "eve.ux.searcher.composer.filetree",

  FiletreeView = "eve.ux.searcher.view.filetree",
  PlainfileView = "eve.ux.searcher.view.plainfile",
}

---@class eve.ux.searcher
---@field public __mods                 eve.ux.searcher.__mods
---
---@field public Finder                 eve.ux.searcher.Finder
---@field public Preview                eve.ux.searcher.Preview
---@field public Result                 eve.ux.searcher.Result
---
---@field public BasicComposer          eve.ux.searcher.BasicComposer
---@field public FiletreeComposer       eve.ux.searcher.FiletreeComposer
---
---@field public FiletreeView           eve.ux.searcher.FiletreeView
---@field public PlainfileView          eve.ux.searcher.PlainfileView
local M = setmetatable({
  __mods = __mods,
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
