---@class eve.state.notepad
local M = {}

-- Workspace notepad source instance (JSON-backed, workspace-scoped)
---@type std.t.INotepadSource
M.workspace = std.source.NotepadJsonSource.new({
  filepath = std.path.locate_workspace_filepath("notepad.json"),
  default_item_name = eve.setting.BUF_UNTITLED,
})

return M

