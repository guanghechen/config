local FileSelect = require("fml.ui.file_select")

---@class fml.ui.SimpleFileSelect : fml.types.ui.ISimpleFileSelect
---@field public file_select            fml.types.ui.IFileSelect|nil
---@field protected _cmp                fml.types.ui.select.IMatchedItemCmp|nil
---@field protected _destroy_on_close   boolean|nil
---@field protected _dimension          fml.types.ui.search.IRawDimension|nil
---@field protected _enable_preview     boolean|nil
---@field protected _frecency           fml.types.collection.IFrecency|nil
---@field protected _provider           fml.types.ui.simple_file_select.IProvider
---@field protected _title              string
local M = {}
M.__index = M

---@class fml.ui.simple_file_select.IProps
---@field public cmp                    ?fml.types.ui.select.IMatchedItemCmp
---@field public destroy_on_close       boolean
---@field public dimension              ?fml.types.ui.search.IRawDimension
---@field public enable_preview         boolean
---@field public frecency               ?fml.types.collection.IFrecency
---@field public provider               fml.types.ui.simple_file_select.IProvider
---@field public title                  string

---@param props                         fml.ui.simple_file_select.IProps
---@return fml.ui.SimpleFileSelect
function M.new(props)
  local self = setmetatable({}, M)

  local cmp = props.cmp ---@type fml.types.ui.select.IMatchedItemCmp|nil
  local destroy_on_close = props.destroy_on_close ---@type boolean
  local dimension = props.dimension ---@type fml.types.ui.search.IRawDimension|nil
  local enable_preview = props.enable_preview ---@type boolean
  local frecency = props.frecency ---@type fml.types.collection.IFrecency|nil
  local provider = props.provider ---@type fml.types.ui.simple_file_select.IProvider
  local title = props.title ---@type string

  self.file_select = nil
  self._cmp = cmp
  self._destroy_on_close = destroy_on_close
  self._dimension = dimension
  self._enable_preview = enable_preview
  self._frecency = frecency
  self._provider = provider
  self._title = title

  return self
end

---@param dimension                     fml.types.ui.search.IRawDimension
---@return nil
function M:change_dimension(dimension)
  if self.file_select ~= nil then
    self.file_select:change_dimension(dimension)
  end
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  self._title = title
  if self.file_select ~= nil then
    self.file_select:change_input_title(title)
  end
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  self._title = title
  if self.file_select ~= nil then
    self.file_select:change_preview_title(title)
  end
end

---@return fml.types.ui.IFileSelect
function M:get_file_select()
  if self.file_select == nil then
    local cmp = self._cmp ---@type fml.types.ui.select.IMatchedItemCmp|nil
    local title = self._title ---@type string
    local frecency = self._frecency ---@type fml.types.collection.IFrecency|nil

    ---@type fml.types.ui.file_select.IProvider
    local provider = {
      fetch_data = function()
        local raw_data = self._provider.provide() ---@type fml.types.ui.simple_file_select.IData
        local cwd = raw_data.cwd ---@type string
        local filepaths = raw_data.filepaths ---@type string[]
        local items = FileSelect.make_items_by_filepaths(filepaths) ---@type fml.types.ui.file_select.IRawItem[]
        local data = { cwd = cwd, items = items }
        return data
      end,
    }

    self.file_select = FileSelect.new({
      cmp = cmp,
      frecency = frecency,
      destroy_on_close = self._destroy_on_close,
      enable_preview = self._enable_preview,
      provider = provider,
      title = title,
      on_close = function()
        if self.file_select ~= nil then
          self.file_select:mark_data_dirty()
        end
      end,
    })
  end
  return self.file_select
end

---@return integer|nil
function M:get_winnr_main()
  if self.file_select ~= nil then
    return self.file_select:get_winnr_main()
  end
end

---@return integer|nil
function M:get_winnr_input()
  if self.file_select ~= nil then
    return self.file_select:get_winnr_input()
  end
end

---@return integer|nil
function M:get_winnr_preview()
  if self.file_select ~= nil then
    return self.file_select:get_winnr_preview()
  end
end

---@return nil
function M:list()
  local select = self:get_file_select() ---@type fml.types.ui.IFileSelect
  select:focus()
end

return M
