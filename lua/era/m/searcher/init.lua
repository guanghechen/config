---@alias era.m.searcher.result.IDraw era.view.picker.result.IDraw
---@alias era.m.searcher.result.IIsSelected era.view.picker.result.IIsSelected
---@alias era.m.searcher.result.IOnDrawed era.view.picker.result.IOnDrawed
---@alias era.m.searcher.result.IStatusSnapshot era.view.picker.result.IStatusSnapshot
---@alias era.m.searcher.result.IDrawResult era.view.picker.result.IDrawResult
---@alias era.m.searcher.result.IFlagItemRaw era.view.picker.result.IFlagItemRaw
---@alias era.m.searcher.result.IFlagItem era.view.picker.result.IFlagItem
---@alias era.m.searcher.result.IWinOpts era.view.picker.result.IWinOpts
---@alias era.m.searcher.IResultProps era.view.picker.result.IProps
---@alias era.m.searcher.Result era.view.PickerResult
---@alias era.m.searcher.preview.IDraw era.view.picker.preview.IDraw
---@alias era.m.searcher.preview.IOnDrawed era.view.picker.preview.IOnDrawed
---@alias era.m.searcher.preview.IDrawResult era.view.picker.preview.IDrawResult
---@alias era.m.searcher.preview.IWinOpts era.view.picker.preview.IWinOpts
---@alias era.m.searcher.IPreviewProps era.view.picker.preview.IProps
---@alias era.m.searcher.Preview era.view.PickerPreview

---@class era.m.searcher.__mods
local __mods = {
  BufferSearcher = "era.m.searcher.buffer",
  FileSearch = "era.m.searcher.file_search",

  Finder = "era.m.searcher.finder",
  Preview = "era.view.picker.preview",
  Result = "era.view.picker.result",

  BasicComposer = "era.m.searcher.composer.basic",
  FiletreeComposer = "era.m.searcher.composer.filetree",

  FiletreeView = "era.m.searcher.view.filetree",
  PlainfileView = "era.m.searcher.view.plainfile",
}

---@class era.m.searcher
---@field public __mods                 era.m.searcher.__mods
---
---@field public BufferSearcher         era.m.searcher.buffer.Searcher
---@field public FileSearch             era.m.searcher.FileSearch
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
