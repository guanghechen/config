---@class dot.module.picker.__mods
local __mods = {
  Finder = "dot.module.picker.finder",
  Preview = "dot.module.picker.preview",
  Result = "dot.module.picker.result",

  BasicComposer = "dot.module.picker.composer.basic",
  FiletreeComposer = "dot.module.picker.composer.filetree",
  ListComposer = "dot.module.picker.composer.list",
  TreeComposer = "dot.module.picker.composer.tree",

  TreeView = "dot.module.picker.view.tree",
  FiletreeView = "dot.module.picker.view.filetree",
}

---@class dot.module.picker
---@field public __mods                 dot.module.picker.__mods
---
---@field public Finder                 dot.module.picker.Finder
---@field public Preview                dot.module.picker.Preview
---@field public Result                 dot.module.picker.Result
---
---@field public BasicComposer          dot.module.picker.BasicComposer
---@field public FiletreeComposer       dot.module.picker.FiletreeComposer
---@field public ListComposer           dot.module.picker.ListComposer
---@field public TreeComposer           dot.module.picker.TreeComposer
---
---@field public TreeView               dot.module.picker.TreeView
---@field public FiletreeView           dot.module.picker.FiletreeView
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
