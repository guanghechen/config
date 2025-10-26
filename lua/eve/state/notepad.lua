---@class eve.state.notepad
local M = {}

---@type std.t.INotepadSource|nil
local _workspace_source = nil

---@type std.t.INotepadSource|nil
local _global_source = nil

---@param name                          string
---@return std.t.INotepadSource|nil
function M.retrieve_source(name)
  if name == "workspace" then
    if _workspace_source == nil then
      _workspace_source = std.source.NotepadJsonSource.new({
        name = "workspace",
        filepath = std.path.locate_workspace_filepath("notepad.json"),
        default_item_name = eve.setting.BUF_UNTITLED,
      })
    end
    return _workspace_source
  elseif name == "global" then
    if _global_source == nil then
      _global_source = std.source.NotepadJsonSource.new({
        name = "global",
        filepath = std.path.locate_context_filepath("notepad.json"),
        default_item_name = eve.setting.BUF_UNTITLED,
      })
    end
    return _global_source
  end
  return nil
end

return M
