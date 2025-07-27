---@class eve.builtin.plugin
local M = {}

---@param filepaths                     string[]|nil
---@return nil
function M.add_files_to_ai(filepaths)
  if filepaths == nil or #filepaths == 0 then
    return
  end

  ---FIXME add files to ai
end

return M
