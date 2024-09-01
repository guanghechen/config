local state_frecency = require("ghc.state.frecency")
local frecency = state_frecency.load_and_autosave().files ---@type fc.types.collection.IFrecency

---@return fml.types.ui.simple_file_select.IData
local function provide()
  local result = vim.fn.system("git diff HEAD --name-only") ---@type string
  local lines = fml.oxi.parse_lines(result) ---@type string[]

  local workspace = fc.path.workspace() ---@type string
  local cwd = fc.path.cwd() ---@type string
  local filepaths = {} ---@type string[]

  for _, line in ipairs(lines) do
    local absolute_filepath = fc.path.join(workspace, line) ---@type string
    local filepath = fc.path.relative(cwd, absolute_filepath, true) ---@type string
    local filename = fc.path.basename(filepath) ---@type string
    local is_text_file = fc.is.printable_file(filename) ---@type boolean
    if is_text_file then
      table.insert(filepaths, filepath)
    end
  end
  table.sort(filepaths)

  ---@type fml.types.ui.simple_file_select.IData
  local data = { cwd = cwd, filepaths = filepaths }
  return data
end

local select = fml.ui.SimpleFileSelect.new({
  destroy_on_close = false,
  dirty_on_close = true,
  enable_preview = true,
  extend_preset_keymaps = true,
  frecency = frecency,
  provider = { provide = provide },
  title = "Find git files (Not committed)",
})

---@class ghc.command.find_git
local M = {}

---@return nil
function M.list_uncommited_git_files()
  select:focus()
end

return M
