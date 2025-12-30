---@class era.m.picker.__mods
local __mods = {
  Finder = "era.m.picker.finder",
  Preview = "era.m.picker.preview",
  Result = "era.m.picker.result",

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
