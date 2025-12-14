---@class dot.ux.searcher.__mods
local __mods = {
  BufferSearcher = "dot.ux.searcher.buffer",

  Finder = "dot.ux.searcher.finder",
  Preview = "dot.ux.searcher.preview",
  Result = "dot.ux.searcher.result",

  BasicComposer = "dot.ux.searcher.composer.basic",
  FiletreeComposer = "dot.ux.searcher.composer.filetree",

  FiletreeView = "dot.ux.searcher.view.filetree",
  PlainfileView = "dot.ux.searcher.view.plainfile",
}

---@class dot.ux.searcher
---@field public __mods                 dot.ux.searcher.__mods
---
---@field public BufferSearcher         dot.ux.searcher.buffer.Searcher
---
---@field public Finder                 dot.ux.searcher.Finder
---@field public Preview                dot.ux.searcher.Preview
---@field public Result                 dot.ux.searcher.Result
---
---@field public BasicComposer          dot.ux.searcher.BasicComposer
---@field public FiletreeComposer       dot.ux.searcher.FiletreeComposer
---
---@field public FiletreeView           dot.ux.searcher.FiletreeView
---@field public PlainfileView          dot.ux.searcher.PlainfileView
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
