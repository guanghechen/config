local checks = require("eve.lib.checks")
local oxi = require("eve.lib.oxi")
local path = require("eve.lib.path")
local select_files = require("fml.fn.select_files")

---@class fml.action.find
local M = {}

---@param context                       eve.lib.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.find_git_not_committed(context)
  local cwd = path.cwd() ---@type string
  local workspace = path.workspace() ---@type string

  select_files({
    cwd = cwd,
    title = "Find: git files (Not committed)",
    flag_fuzzy = true,
    flag_regex = false,
    fetch_filepaths = function()
      local result = vim.fn.system("git diff HEAD --name-only") ---@type string
      local lines = oxi.parse_lines(result) ---@type string[]

      local filepaths = {} ---@type string[]
      for _, line in ipairs(lines) do
        local absolute_filepath = path.join(workspace, line) ---@type string
        local filepath = path.relative(cwd, absolute_filepath, true) ---@type string
        local filename = path.basename(filepath) ---@type string
        local is_text_file = checks.is_printable_file(filename) ---@type boolean
        if is_text_file then
          table.insert(filepaths, filepath)
        end
      end
      return filepaths
    end,
  })
end

return M
