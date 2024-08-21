local state_frecency = require("ghc.state.frecency")
local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency

---@return fml.types.ui.simple_file_select.IData
local function provide()
  local result = vim.fn.system("git diff HEAD --name-only") ---@type string
  local lines = fml.oxi.parse_lines(result) ---@type string[]

  local workspace = fml.path.workspace() ---@type string
  local cwd = fml.path.cwd() ---@type string
  local filepaths = {} ---@type string[]

  for _, line in ipairs(lines) do
    local absolute_filepath = fml.path.join(workspace, line) ---@type string
    local filepath = fml.path.relative(cwd, absolute_filepath) ---@type string
    local filename = fml.path.basename(filepath) ---@type string
    local is_text_file = fml.is.printable_file(filename) ---@type boolean
    if is_text_file then
      table.insert(filepaths, filepath)
    end
  end

  ---@type fml.types.ui.simple_file_select.IData
  local data = { cwd = cwd, filepaths = filepaths }
  return data
end

local select = fml.ui.SimpleFileSelect.new({
  title = "Find git files (Not committed)",
  provider = { provide = provide },
  frecency = frecency,
  destroy_on_close = false,
  enable_preview = true,
})

---@class ghc.command.find_git
local M = {}

---@return nil
function M.list_uncommited_git_files()
  select:list()
end

return M
