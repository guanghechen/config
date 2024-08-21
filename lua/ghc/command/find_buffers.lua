local _select = nil ---@type fml.types.ui.IFileSelect|nil

---@return string
---@return string[]
local function get_buf_filepaths()
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

  return cwd, filepaths
end

---@return fml.types.ui.IFileSelect
local function get_select()
  if _select == nil then
    local state_frecency = require("ghc.state.frecency")
    local frecency = state_frecency.load_and_autosave().files ---@type fml.types.collection.IFrecency

    _select = fml.ui.FileSelect.new({
      cwd = fml.path.cwd(),
      title = "Find buffers (current tab)",
      items = {},
      frecency = frecency,
      preview = true,
      destroy_on_close = false,
      on_resume = function()
        if _select ~= nil then
          local cwd, filepaths = get_buf_filepaths()

          ---@type fml.types.ui.file_select.IRawItem[]
          local items = fml.ui.FileSelect.calc_items_from_filepaths(filepaths)

          _select:update_data(cwd, items)
        end
      end,
    })
  end
  return _select
end

---@class ghc.command.find_buffers
local M = {}

---@return nil
function M.list_current_tab_bufs()
  ---@type string, string[]
  local cwd, filepaths = get_buf_filepaths()

  ---@type fml.types.ui.file_select.IRawItem[]
  local items = fml.ui.FileSelect.calc_items_from_filepaths(filepaths)

  local select = get_select() ---@type fml.types.ui.IFileSelect
  select:update_data(cwd, items)
  select:focus()
end

return M
