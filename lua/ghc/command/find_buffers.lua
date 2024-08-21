local state_frecency = require("ghc.state.frecency")
local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency

---@return fml.types.ui.simple_file_select.IData
local function provide()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = fml.api.state.get_tab(tabnr) ---@type fml.types.api.state.ITabItem|nil
  local workspace = fml.path.workspace() ---@type string
  local cwd = fml.path.cwd() ---@type string

  local filepaths = {} ---@type string[]
  if tab ~= nil then
    local bufnrs = tab.bufnrs ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      local buf = fml.api.state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
      if buf ~= nil and buf.filename ~= fml.constant.BUF_UNTITLED and fml.path.is_under(workspace, buf.filepath) then
        local relative_path = fml.path.relative(cwd, buf.filepath) ---@type string
        table.insert(filepaths, relative_path)
      end
    end
  end

  ---@type fml.types.ui.simple_file_select.IData
  local data = { cwd = cwd, filepaths = filepaths }
  return data
end

local select = fml.ui.SimpleFileSelect.new({
  title = "Find buffers (current tab)",
  provider = { provide = provide },
  frecency = frecency,
  destroy_on_close = false,
  enable_preview = true,
})

---@class ghc.command.find_buffers
local M = {}

---@return nil
function M.list_current_tab_bufs()
  select:list()
end

return M
