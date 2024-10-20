local frecency = eve.context.state.frecency.files ---@type t.eve.collection.IFrecency

---@return t.fml.ux.simple_file_select.IData
local function provide()
  local result = vim.fn.system("git diff HEAD --name-only") ---@type string
  local lines = eve.oxi.parse_lines(result) ---@type string[]

  local workspace = eve.path.workspace() ---@type string
  local cwd = eve.path.cwd() ---@type string
  local filepaths = {} ---@type string[]

  for _, line in ipairs(lines) do
    local absolute_filepath = eve.path.join(workspace, line) ---@type string
    local filepath = eve.path.relative(cwd, absolute_filepath, true) ---@type string
    local filename = eve.path.basename(filepath) ---@type string
    local is_text_file = eve.validator.is_printable_file(filename) ---@type boolean
    if is_text_file then
      table.insert(filepaths, filepath)
    end
  end
  table.sort(filepaths)

  ---@type t.fml.ux.simple_file_select.IData
  local data = { cwd = cwd, filepaths = filepaths }
  return data
end

local select = fml.ux.SimpleFileSelect.new({
  dirty_on_invisible = true,
  enable_preview = true,
  extend_preset_keymaps = true,
  frecency = frecency,
  permanent = true,
  provider = { provide = provide },
  title = "Find git files (Not committed)",
})

---@class ghc.action.find_git
local M = {}

---@return nil
function M.list_uncommited_git_files()
  select:focus()
end

return M
