---@class std.source.__mods
local source__mods = {
  NotepadJsonSource = "std.source.notepad-json",
  NotepadFolderSource = "std.source.notepad-folder",
}

---@class std.source
---@field public __mods                 std.source.__mods
---@field public NotepadJsonSource      std.source.NotepadJsonSource
---@field public NotepadFolderSource    std.source.NotepadFolderSource
local source = setmetatable({ __mods = source__mods }, {
  __index = function(t, k)
    local m = source__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@class std.__mods
local __mods = {
  notepad = "std.notepad",
  uri = "std.uri",

  Filetree = "std.collection.filetree",
  Tree = "std.collection.tree",
}

---@class std
---@field public __mods                 std.__mods
---@field public source                 std.source
---
---@field public notepad                std.notepad
---@field public uri                    std.uri
---
---@field public Filetree               std.collection.Filetree
---@field public Tree                   std.collection.Tree
local M = setmetatable({
  __mods = __mods,
  source = source,
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
