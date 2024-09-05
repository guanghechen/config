local FileSelect = require("fml.ui.file_select")

---@class fml.ui.SimpleFileSelect : fml.types.ui.ISimpleFileSelect
---@field public get_file_select        fun(): fml.types.ui.IFileSelect
local M = {}
M.__index = M

---@class fml.ui.simple_file_select.IProps
---@field public cmp                    ?fml.types.ui.select.IMatchedItemCmp
---@field public delay_fetch            ?integer
---@field public delay_render           ?integer
---@field public destroy_on_close       boolean
---@field public dimension              ?fml.types.ui.search.IRawDimension
---@field public dirty_on_close         ?boolean
---@field public enable_preview         boolean
---@field public extend_preset_keymaps  ?boolean
---@field public frecency               ?eve.types.collection.IFrecency
---@field public provider               fml.types.ui.simple_file_select.IProvider
---@field public title                  string

---@param props                         fml.ui.simple_file_select.IProps
---@return fml.ui.SimpleFileSelect
function M.new(props)
  local self = setmetatable({}, M)

  local cmp = props.cmp ---@type fml.types.ui.select.IMatchedItemCmp|nil
  local delay_fetch = props.delay_fetch ---@type integer|nil
  local delay_render = props.delay_render ---@type integer|nil
  local destroy_on_close = props.destroy_on_close ---@type boolean
  local dimension = props.dimension ---@type fml.types.ui.search.IRawDimension|nil
  local dirty_on_close = not not props.dirty_on_close ---@type boolean
  local enable_preview = props.enable_preview ---@type boolean
  local extend_preset_keymaps = not not props.extend_preset_keymaps ---@type boolean|nil
  local frecency = props.frecency ---@type eve.types.collection.IFrecency|nil
  local simple_provider = props.provider ---@type fml.types.ui.simple_file_select.IProvider
  local title = props.title ---@type string

  local _file_select = nil ---@type fml.types.ui.IFileSelect|nil

  ---@return fml.types.ui.IFileSelect
  local function get_file_select()
    if _file_select == nil then
      ---@type fml.types.ui.file_select.IProvider
      local provider = {
        fetch_data = function(force)
          local raw_data = simple_provider.provide(force) ---@type fml.types.ui.simple_file_select.IData
          local cwd = raw_data.cwd ---@type string
          local filepaths = raw_data.filepaths ---@type string[]
          local present_filepath = raw_data.present_filepath ---@type string|nil
          local items = FileSelect.make_items_by_filepaths(filepaths) ---@type fml.types.ui.file_select.IRawItem[]
          ---@type fml.types.ui.file_select.IData
          return { cwd = cwd, items = items, present_uuid = present_filepath }
        end,
      }

      _file_select = FileSelect.new({
        cmp = cmp,
        delay_fetch = delay_fetch,
        delay_render = delay_render,
        destroy_on_close = destroy_on_close,
        dimension = dimension,
        dirty_on_close = dirty_on_close,
        enable_preview = enable_preview,
        extend_preset_keymaps = extend_preset_keymaps,
        frecency = frecency,
        provider = provider,
        title = title,
      })
    end
    return _file_select
  end

  self.get_file_select = get_file_select
  return self
end

---@param dimension                     fml.types.ui.search.IRawDimension
---@return nil
function M:change_dimension(dimension)
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  file_select:change_dimension(dimension)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  file_select:change_input_title(title)
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  file_select:change_preview_title(title)
end

---@return nil
function M:close()
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  file_select:close()
end

---@return nil
function M:focus()
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  file_select:focus()
end

---@return integer|nil
function M:get_winnr_main()
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  return file_select:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  return file_select:get_winnr_input()
end

---@return integer|nil
function M:get_winnr_preview()
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  return file_select:get_winnr_preview()
end

---@return nil
function M:mark_data_dirty()
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  file_select:mark_data_dirty()
end

---@return nil
function M:open()
  local file_select = self.get_file_select() ---@type fml.types.ui.IFileSelect
  file_select:open()
end

return M
