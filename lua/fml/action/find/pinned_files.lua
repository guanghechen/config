---@class fml.action.find
local M = {}

---@return nil
function M.find_pinned_files()
  local cwd = std.path.cwd() ---@type string

  eve.ux.fn.select_files({
    cwd = cwd,
    title = "Find pinned files",
    flag_fuzzy = true,
    flag_regex = false,
    fetch_filepaths = function()
      local filepaths = {} ---@type string[]
      local pinned_filepaths = eve.context.bookmark.pinned:snapshot() ---@type string[]
      for _, filepath in ipairs(pinned_filepaths) do
        local relative_filepath = std.path.relative(cwd, filepath, true) ---@type string
        table.insert(filepaths, relative_filepath)
      end
      return filepaths
    end,
  })
end

return M
