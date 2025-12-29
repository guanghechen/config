---@class era.picker.__mods
local __mods = {
  Finder = "era.picker.finder",
  Preview = "era.picker.preview",
  Result = "era.picker.result",

  BasicComposer = "era.picker.composer.basic",
  FiletreeComposer = "era.picker.composer.filetree",
  ListComposer = "era.picker.composer.list",
  TreeComposer = "era.picker.composer.tree",

  TreeView = "era.picker.view.tree",
  FiletreeView = "era.picker.view.filetree",
}

---@class era.picker
---@field public __mods                 era.picker.__mods
---
---@field public Finder                 era.picker.Finder
---@field public Preview                era.picker.Preview
---@field public Result                 era.picker.Result
---
---@field public BasicComposer          era.picker.BasicComposer
---@field public FiletreeComposer       era.picker.FiletreeComposer
---@field public ListComposer           era.picker.ListComposer
---@field public TreeComposer           era.picker.TreeComposer
---
---@field public TreeView               era.picker.TreeView
---@field public FiletreeView           era.picker.FiletreeView
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
