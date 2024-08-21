local _select = nil ---@type fml.types.ui.IFileSelect|nil

---@return string
---@return string[]
local function get_git_filepaths()
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

  return cwd, filepaths
end

---@return fml.types.ui.IFileSelect
local function get_select()
  if _select == nil then
    local state_frecency = require("ghc.state.frecency")
    local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency

    _select = fml.ui.FileSelect.new({
      cwd = fml.path.cwd(),
      title = "Find git files (Not committed)",
      items = {},
      frecency = frecency,
      preview = true,
      destroy_on_close = false,
      on_resume = function()
        if _select ~= nil then
          local cwd, filepaths = get_git_filepaths()

          ---@type fml.types.ui.file_select.IRawItem[]
          local items = fml.ui.FileSelect.calc_items_from_filepaths(filepaths)

          _select:update_data(cwd, items)
        end
      end,
    })
  end
  return _select
end

---@class ghc.command.find_git
local M = {}

---@return nil
function M.list_uncommited_git_files()
  ---@type string, string[]
  local cwd, filepaths = get_git_filepaths()

  ---@type fml.types.ui.file_select.IRawItem[]
  local items = fml.ui.FileSelect.calc_items_from_filepaths(filepaths)

  local select = get_select() ---@type fml.types.ui.IFileSelect
  select:update_data(cwd, items)
  select:focus()
end

return M
