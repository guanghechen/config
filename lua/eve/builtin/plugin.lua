---@class eve.builtin.plugin
local M = {}

---@param filepaths                     string[]|nil
---@return nil
function M.avante_add_files(filepaths)
  if filepaths == nil or #filepaths == 0 then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.tab.focus_win_sourcefile(tabnr)

  local sidebar = require("avante").get()
  if sidebar == nil or not sidebar:is_open() then
    require("avante.api").ask()
    sidebar = require("avante").get()

    if sidebar == nil or not sidebar:is_open() then
      return
    end
  end

  vim.schedule(function()
    for _, filepath in ipairs(filepaths) do
      local relative_path = require("avante.utils").relative_path(filepath) ---@type string
      sidebar.file_selector:add_selected_file(relative_path)
    end

    sidebar.file_selector:remove_selected_file("neo-tree filesystem [1]")
    sidebar.file_selector:remove_selected_file("untitled-1")
  end)
end

return M
