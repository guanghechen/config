---@class ux.searcher.__mods
local __mods = {
  BufferSearcher = "ux.searcher.buffer",

  Finder = "ux.searcher.finder",
  Preview = "ux.searcher.preview",
  Result = "ux.searcher.result",

  BasicComposer = "ux.searcher.composer.basic",
  FiletreeComposer = "ux.searcher.composer.filetree",

  FiletreeView = "ux.searcher.view.filetree",
  PlainfileView = "ux.searcher.view.plainfile",
}

---@class ux.searcher
---@field public __mods                 ux.searcher.__mods
---
---@field public BufferSearcher         ux.searcher.buffer.Searcher
---
---@field public Finder                 ux.searcher.Finder
---@field public Preview                ux.searcher.Preview
---@field public Result                 ux.searcher.Result
---
---@field public BasicComposer          ux.searcher.BasicComposer
---@field public FiletreeComposer       ux.searcher.FiletreeComposer
---
---@field public FiletreeView           ux.searcher.FiletreeView
---@field public PlainfileView          ux.searcher.PlainfileView
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
