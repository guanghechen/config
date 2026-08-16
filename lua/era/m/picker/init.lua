---@alias era.m.picker.result.IDraw era.view.picker.result.IDraw
---@alias era.m.picker.result.IIsSelected era.view.picker.result.IIsSelected
---@alias era.m.picker.result.IOnDrawed era.view.picker.result.IOnDrawed
---@alias era.m.picker.result.IDrawResult era.view.picker.result.IDrawResult
---@alias era.m.picker.result.IFlagItemRaw era.view.picker.result.IFlagItemRaw
---@alias era.m.picker.result.IFlagItem era.view.picker.result.IFlagItem
---@alias era.m.picker.result.IWinOpts era.view.picker.result.IWinOpts
---@alias era.m.picker.IResultProps era.view.picker.result.IProps
---@alias era.m.picker.Result era.view.PickerResult
---@alias era.m.picker.preview.IDraw era.view.picker.preview.IDraw
---@alias era.m.picker.preview.IOnDrawed era.view.picker.preview.IOnDrawed
---@alias era.m.picker.preview.IDrawResult era.view.picker.preview.IDrawResult
---@alias era.m.picker.preview.IWinOpts era.view.picker.preview.IWinOpts
---@alias era.m.picker.IPreviewProps era.view.picker.preview.IProps
---@alias era.m.picker.Preview era.view.PickerPreview

---@class era.m.picker.__mods
local __mods = {
  Finder = "era.m.picker.finder",
  Preview = "era.view.picker.preview",
  Result = "era.view.picker.result",

  BasicComposer = "era.m.picker.composer.basic",
  FiletreeComposer = "era.m.picker.composer.filetree",
  ListComposer = "era.m.picker.composer.list",
  TreeComposer = "era.m.picker.composer.tree",

  TreeView = "era.m.picker.view.tree",
  FiletreeView = "era.m.picker.view.filetree",
}

---@class era.m.picker
---@field public __mods                 era.m.picker.__mods
---
---@field public Finder                 era.m.picker.Finder
---@field public Preview                era.m.picker.Preview
---@field public Result                 era.m.picker.Result
---
---@field public BasicComposer          era.m.picker.BasicComposer
---@field public FiletreeComposer       era.m.picker.FiletreeComposer
---@field public ListComposer           era.m.picker.ListComposer
---@field public TreeComposer           era.m.picker.TreeComposer
---
---@field public TreeView               era.m.picker.TreeView
---@field public FiletreeView           era.m.picker.FiletreeView
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
