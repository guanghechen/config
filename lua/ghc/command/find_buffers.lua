local state_frecency = require("ghc.state.frecency")
local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency

local select ---@type fml.types.ui.ISimpleFileSelect

---@return fml.types.ui.simple_file_select.IData
local function provide()
  local workspace = fml.path.workspace() ---@type string
  local cwd = fml.path.cwd() ---@type string
  local filepaths = {} ---@type string[]
  local width = 0 ---@type integer

  for _, buf in pairs(fml.api.state.bufs) do
    if buf.filename ~= fml.constant.BUF_UNTITLED and fml.path.is_under(workspace, buf.filepath) then
      local relative_path = fml.path.relative(cwd, buf.filepath, true) ---@type string
      local w = vim.fn.strwidth(relative_path) ---@type integer
      width = width < w and w or width
      table.insert(filepaths, relative_path)
    end
  end
  width = math.max(width + 16, 60)

  select:change_dimension({ height = #filepaths + 3, width = width + 16 })

  local present_filepath = nil ---@type string|nil
  local winnr_cur = fml.api.state.win_history:present() ---@type integer|nil
  if winnr_cur ~= nil and vim.api.nvim_win_is_valid(winnr_cur) then
    local bufnr = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
    local absolute_filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local relative_path = fml.path.relative(cwd, absolute_filepath, true) ---@type string
    present_filepath = relative_path
  end

  ---@type fml.types.ui.simple_file_select.IData
  local data = { cwd = cwd, filepaths = filepaths, present_filepath = present_filepath }
  return data
end

select = fml.ui.SimpleFileSelect.new({
  cmp = fml.ui.Select.cmp_by_score,
  destroy_on_close = false,
  dirty_on_close = true,
  enable_preview = false,
  extend_preset_keymaps = true,
  frecency = frecency,
  provider = { provide = provide },
  title = "Find buffers",
})

---@class ghc.command.find_buffers
local M = {}

---@return nil
function M.focus()
  select:focus()
end

return M
