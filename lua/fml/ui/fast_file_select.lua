---@class fml.ui.FastFileSelect : fml.types.ui.IFastFileSelect
---@field protected _destroy_on_close   boolean|nil
---@field protected _preview            boolean|nil
---@field protected _file_select        fml.types.ui.IFileSelect|nil
---@field protected _frecency           fml.types.collection.IFrecency|nil
---@field protected _provider           fml.types.ui.fast_file_select.IProvider
---@field protected _title              string
local M = {}
M.__index = M

---@class fml.ui.fast_file_select.IProps
---@field public title                  string
---@field public provider               fml.types.ui.fast_file_select.IProvider
---@field public destroy_on_close       ?boolean
---@field public preview                ?boolean
---@field public frecency               ?fml.types.collection.IFrecency

---@param props                         fml.ui.fast_file_select.IProps
---@return fml.ui.FastFileSelect
function M.new(props)
  local self = setmetatable({}, M)

  local title = props.title ---@type string
  local provider = props.provider ---@type fml.types.ui.fast_file_select.IProvider
  local frecency = props.frecency ---@type fml.types.collection.IFrecency|nil
  local destroy_on_close = props.destroy_on_close ---@type boolean|nil
  local preview = props.preview ---@type boolean|nil

  self._destroy_on_close = destroy_on_close
  self._preview = preview
  self._file_select = nil
  self._frecency = frecency
  self._provider = provider
  self._title = title

  return self
end

---@return fml.types.ui.IFileSelect
function M:get_file_select()
  if self._file_select == nil then
    local title = self._title ---@type string
    local frecency = self._frecency ---@type fml.types.collection.IFrecency|nil
    local initial_data = self._provider.provide() ---@type fml.types.ui.fast_file_select.IData
    local initial_cwd = initial_data.cwd ---@type string
    local initial_filepaths = initial_data.filepaths ---@type string[]
    local initial_items = fml.ui.FileSelect.calc_items_from_filepaths(initial_filepaths) ---@type fml.types.ui.file_select.IRawItem[]

    self._file_select = fml.ui.FileSelect.new({
      cwd = initial_cwd,
      title = title,
      items = initial_items,
      frecency = frecency,
      preview = self._preview,
      destroy_on_close = self._destroy_on_close,
      on_resume = function()
        if self._file_select ~= nil then
          local data = self._provider.provide() ---@type fml.types.ui.fast_file_select.IData
          local cwd = data.cwd ---@type string
          local filepaths = data.filepaths ---@type string[]
          local items = fml.ui.FileSelect.calc_items_from_filepaths(filepaths) ---@type fml.types.ui.file_select.IRawItem[]
          self._file_select:update_data(cwd, items)
        end
      end,
    })
  end
  return self._file_select
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  self._title = title
  if self._file_select ~= nil then
    self._file_select:change_input_title(title)
  end
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  self._title = title
  if self._file_select ~= nil then
    self._file_select:change_preview_title(title)
  end
end

---@return nil
function M:list()
  local select = self:get_file_select() ---@type fml.types.ui.IFileSelect
  select:focus()
end

return M
