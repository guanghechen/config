local FileSelect = require("fml.ux.component.file_select")

---@class fml.ux.SimpleFileSelect : fml.t.ux.ISimpleFileSelect
---@field public get_file_select        fun(): fml.t.ux.IFileSelect
local M = {}
M.__index = M

---@class fml.ux.simple_file_select.IProps
---@field public cmp                    ?fml.t.ux.select.IMatchedItemCmp
---@field public delay_fetch            ?integer
---@field public delay_render           ?integer
---@field public dimension              ?fml.t.ux.search.IRawDimension
---@field public dirty_on_invisible     ?boolean
---@field public preview_enabled        boolean
---@field public preview_flag_wrap      ?boolean
---@field public extend_preset_keymaps  ?boolean
---@field public frecency               ?eve.lib.collection.IFrecency
---@field public permanent              ?boolean
---@field public provider               fml.t.ux.simple_file_select.IProvider
---@field public title                  string

---@param props                         fml.ux.simple_file_select.IProps
---@return fml.ux.SimpleFileSelect
function M.new(props)
  local self = setmetatable({}, M)

  local cmp = props.cmp ---@type fml.t.ux.select.IMatchedItemCmp|nil
  local delay_fetch = props.delay_fetch ---@type integer|nil
  local delay_render = props.delay_render ---@type integer|nil
  local dimension = props.dimension ---@type fml.t.ux.search.IRawDimension|nil
  local dirty_on_invisible = not not props.dirty_on_invisible ---@type boolean
  local preview_enabled = props.preview_enabled ---@type boolean
  local preview_flag_wrap = props.preview_flag_wrap ---@type boolean|nil
  local extend_preset_keymaps = not not props.extend_preset_keymaps ---@type boolean|nil
  local frecency = props.frecency ---@type eve.lib.collection.IFrecency|nil
  local permanent = props.permanent ---@type boolean|nil
  local simple_provider = props.provider ---@type fml.t.ux.simple_file_select.IProvider
  local title = props.title ---@type string

  local _file_select = nil ---@type fml.t.ux.IFileSelect|nil

  ---@return fml.t.ux.IFileSelect
  local function get_file_select()
    if _file_select == nil then
      ---@type fml.t.ux.file_select.IProvider
      local provider = {
        fetch_data = function(force)
          local raw_data = simple_provider.provide(force) ---@type fml.t.ux.simple_file_select.IData
          local cwd = raw_data.cwd ---@type string
          local filepaths = raw_data.filepaths ---@type string[]
          local present_filepath = raw_data.present_filepath ---@type string|nil
          local items = FileSelect.make_items_by_filepaths(filepaths) ---@type fml.t.ux.file_select.IRawItem[]
          ---@type fml.t.ux.file_select.IData
          return { cwd = cwd, items = items, present_uuid = present_filepath }
        end,
      }

      _file_select = FileSelect.new({
        cmp = cmp,
        delay_fetch = delay_fetch,
        delay_render = delay_render,
        dimension = dimension,
        dirty_on_invisible = dirty_on_invisible,
        preview_enabled = preview_enabled,
        preview_flag_wrap = preview_flag_wrap,
        extend_preset_keymaps = extend_preset_keymaps,
        frecency = frecency,
        permanent = permanent,
        provider = provider,
        title = title,
      })
    end
    return _file_select
  end

  self.get_file_select = get_file_select
  return self
end

---@param dimension                     fml.t.ux.search.IRawDimension
---@return nil
function M:change_dimension(dimension)
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  file_select:change_dimension(dimension)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  file_select:change_input_title(title)
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  file_select:change_preview_title(title)
end

---@return nil
function M:close()
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  file_select:close()
end

---@return nil
function M:focus()
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  file_select:focus()
end

---@return integer|nil
function M:get_winnr_main()
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  return file_select:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  return file_select:get_winnr_input()
end

---@return integer|nil
function M:get_winnr_preview()
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  return file_select:get_winnr_preview()
end

---@return nil
function M:mark_data_dirty()
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  file_select:mark_data_dirty()
end

---@return nil
function M:open()
  local file_select = self.get_file_select() ---@type fml.t.ux.IFileSelect
  file_select:open()
end

return M
