---@class ux.picker.__mods
local __mods = {
  Finder = "ux.picker.finder",
  Preview = "ux.picker.preview",
  Result = "ux.picker.result",

  BasicComposer = "ux.picker.composer.basic",
  FiletreeComposer = "ux.picker.composer.filetree",
  ListComposer = "ux.picker.composer.list",
  TreeComposer = "ux.picker.composer.tree",

  TreeView = "ux.picker.view.tree",
  FiletreeView = "ux.picker.view.filetree",
}

---@class ux.picker
---@field public __mods                 ux.picker.__mods
---
---@field public Finder                 ux.picker.Finder
---@field public Preview                ux.picker.Preview
---@field public Result                 ux.picker.Result
---
---@field public BasicComposer          ux.picker.BasicComposer
---@field public FiletreeComposer       ux.picker.FiletreeComposer
---@field public ListComposer           ux.picker.ListComposer
---@field public TreeComposer           ux.picker.TreeComposer
---
---@field public TreeView               ux.picker.TreeView
---@field public FiletreeView           ux.picker.FiletreeView
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
