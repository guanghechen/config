---@class era.m.notepad.__mods
local __mods = {
  action = "era.m.notepad.action",
  FolderSource = "era.m.notepad.source-folder",
  JsonSource = "era.m.notepad.source-json",
  state = "era.m.notepad.state",
  View = "era.m.notepad.view",
}

---@class era.m.notepad
---@field public __mods                 era.m.notepad.__mods
---@field public action                 era.m.notepad.action
---@field public FolderSource           era.m.notepad.state.source.Folder
---@field public JsonSource             era.m.notepad.state.source.Json
---@field public state                  era.m.notepad.state
---@field public View                   era.m.notepad.View
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local mod = __mods[k] ---@type string|nil
    if mod == nil then
      return rawget(t, k)
    end
    return require(mod)
  end,
})

-- Feature loading precedes its buffers' FileType events while staying off the startup path.
vim.treesitter.language.register("markdown", stl.filetype.NOTEPAD)

return M
