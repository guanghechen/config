---@class dot.module.searcher.__mods
local __mods = {
  BufferSearcher = "dot.module.searcher.buffer",

  Finder = "dot.module.searcher.finder",
  Preview = "dot.module.searcher.preview",
  Result = "dot.module.searcher.result",

  BasicComposer = "dot.module.searcher.composer.basic",
  FiletreeComposer = "dot.module.searcher.composer.filetree",

  FiletreeView = "dot.module.searcher.view.filetree",
  PlainfileView = "dot.module.searcher.view.plainfile",
}

---@class dot.module.searcher
---@field public __mods                 dot.module.searcher.__mods
---
---@field public BufferSearcher         dot.module.searcher.buffer.Searcher
---
---@field public Finder                 dot.module.searcher.Finder
---@field public Preview                dot.module.searcher.Preview
---@field public Result                 dot.module.searcher.Result
---
---@field public BasicComposer          dot.module.searcher.BasicComposer
---@field public FiletreeComposer       dot.module.searcher.FiletreeComposer
---
---@field public FiletreeView           dot.module.searcher.FiletreeView
---@field public PlainfileView          dot.module.searcher.PlainfileView
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
