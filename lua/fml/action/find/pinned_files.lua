local path = require("eve.builtin.path")

local state = require("eve.state")
local select_files = require("fml.fn.select_files")

---@class fml.action.find
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_pinned_files(context)
  local cwd = path.cwd() ---@type string

  select_files({
    cwd = cwd,
    title = "Find pinned files",
    flag_fuzzy = true,
    flag_regex = false,
    fetch_filepaths = function()
      local filepaths = {} ---@type string[]
      local pinned_filepaths = state.bookmark.pinned:snapshot() ---@type string[]
      for _, filepath in ipairs(pinned_filepaths) do
        local relative_filepath = path.relative(cwd, filepath, true) ---@type string
        table.insert(filepaths, relative_filepath)
      end
      return filepaths
    end,
  })
end

return M
