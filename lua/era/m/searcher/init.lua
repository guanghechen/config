---@class era.m.searcher.__mods
local __mods = {
  BufferSearcher = "era.m.searcher.buffer",

  Finder = "era.m.searcher.finder",
  Preview = "era.m.searcher.preview",
  Result = "era.m.searcher.result",

  BasicComposer = "era.m.searcher.composer.basic",
  FiletreeComposer = "era.m.searcher.composer.filetree",

  FiletreeView = "era.m.searcher.view.filetree",
  PlainfileView = "era.m.searcher.view.plainfile",
}

---@class era.m.searcher
---@field public __mods                 era.m.searcher.__mods
---
---@field public BufferSearcher         era.m.searcher.buffer.Searcher
---
---@field public Finder                 era.m.searcher.Finder
---@field public Preview                era.m.searcher.Preview
---@field public Result                 era.m.searcher.Result
---
---@field public BasicComposer          era.m.searcher.BasicComposer
---@field public FiletreeComposer       era.m.searcher.FiletreeComposer
---
---@field public FiletreeView           era.m.searcher.FiletreeView
---@field public PlainfileView          era.m.searcher.PlainfileView
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
