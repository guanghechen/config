local ft = require("eve.constant.filetype")

local select_files = require("fml.fn.select_files")

---@class fml.action.find
local M = {}

---@return nil
function M.find_git_not_committed()
  local cwd = eve.std.path.cwd() ---@type string
  local workspace = eve.std.path.workspace() ---@type string

  select_files({
    cwd = cwd,
    title = "Find: git files (Not committed)",
    flag_fuzzy = true,
    flag_regex = false,
    fetch_filepaths = function()
      local result = vim.fn.system("git diff HEAD --name-only") ---@type string
      local lines = eve.std.oxi.parse_lines(result) ---@type string[]

      local filepaths = {} ---@type string[]
      for _, line in ipairs(lines) do
        local absolute_filepath = eve.std.path.join(workspace, line) ---@type string
        local filepath = eve.std.path.relative(cwd, absolute_filepath, true) ---@type string
        local filename = eve.std.path.basename(filepath) ---@type string
        local is_text_file = ft.is_printable_file(filename) ---@type boolean
        if is_text_file then
          table.insert(filepaths, filepath)
        end
      end
      return filepaths
    end,
  })
end

return M
