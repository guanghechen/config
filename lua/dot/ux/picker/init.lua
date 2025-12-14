---@class dot.ux.picker.__mods
local __mods = {
  Finder = "dot.ux.picker.finder",
  Preview = "dot.ux.picker.preview",
  Result = "dot.ux.picker.result",

  BasicComposer = "dot.ux.picker.composer.basic",
  FiletreeComposer = "dot.ux.picker.composer.filetree",
  ListComposer = "dot.ux.picker.composer.list",
  TreeComposer = "dot.ux.picker.composer.tree",

  TreeView = "dot.ux.picker.view.tree",
  FiletreeView = "dot.ux.picker.view.filetree",
}

---@class dot.ux.picker
---@field public __mods                 dot.ux.picker.__mods
---
---@field public Finder                 dot.ux.picker.Finder
---@field public Preview                dot.ux.picker.Preview
---@field public Result                 dot.ux.picker.Result
---
---@field public BasicComposer          dot.ux.picker.BasicComposer
---@field public FiletreeComposer       dot.ux.picker.FiletreeComposer
---@field public ListComposer           dot.ux.picker.ListComposer
---@field public TreeComposer           dot.ux.picker.TreeComposer
---
---@field public TreeView               dot.ux.picker.TreeView
---@field public FiletreeView           dot.ux.picker.FiletreeView
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
