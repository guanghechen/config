---@class era.searcher.__mods
local __mods = {
  BufferSearcher = "era.searcher.buffer",

  Finder = "era.searcher.finder",
  Preview = "era.searcher.preview",
  Result = "era.searcher.result",

  BasicComposer = "era.searcher.composer.basic",
  FiletreeComposer = "era.searcher.composer.filetree",

  FiletreeView = "era.searcher.view.filetree",
  PlainfileView = "era.searcher.view.plainfile",
}

---@class era.searcher
---@field public __mods                 era.searcher.__mods
---
---@field public BufferSearcher         era.searcher.buffer.Searcher
---
---@field public Finder                 era.searcher.Finder
---@field public Preview                era.searcher.Preview
---@field public Result                 era.searcher.Result
---
---@field public BasicComposer          era.searcher.BasicComposer
---@field public FiletreeComposer       era.searcher.FiletreeComposer
---
---@field public FiletreeView           era.searcher.FiletreeView
---@field public PlainfileView          era.searcher.PlainfileView
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
