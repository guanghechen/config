---@class era.m.view.__mods
local __mods = {
  Act = "era.m.view.act",
  Fileinfo = "era.m.view.fileinfo",
  Keysheet = "era.m.view.keysheet",
  Plainfile = "era.m.view.plainfile",
  Printer = "era.m.view.printer",
  Select = "era.m.view.select",
  Setting = "era.m.view.setting",
  Textarea = "era.m.view.textarea",
  Tree = "era.m.view.tree",
}

---@class era.m.view
---@field public __mods                 era.m.view.__mods
---@field public Act                    era.m.view.Act
---@field public Fileinfo               era.m.view.Fileinfo
---@field public Keysheet               era.m.view.Keysheet
---@field public Plainfile              era.m.view.Plainfile
---@field public Printer                era.m.view.Printer
---@field public Select                 era.m.view.Select
---@field public Setting                era.m.view.Setting
---@field public Textarea               era.m.view.Textarea
---@field public Tree                   era.m.view.Tree
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
