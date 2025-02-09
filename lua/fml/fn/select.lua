local Observable = require("eve.collection.observable")

local Select = require("fml.ux.select")

---@class fml.fn.select.IParams
---@field public title                  string
---@field public dimension              ?fml.ux.search.IRawDimension
---@field public flag_fuzzy             ?boolean
---@field public flag_regex             ?boolean
---@field public input                  ?eve.collection.IObservable
---@field public multiple               ?boolean
---@field public preview_wrap           ?boolean
---@field public fetch_items            fun(): fml.ux.select.IItem[]
---@field public on_confirm             fml.ux.select.IOnConfirm
---@field public get_cursor             ?fun(): string|nil
---@field public get_present            ?fun(): string|nil
---@field public render_item            ?fml.ux.select.IRenderItem
---@field public fetch_preview_data     ?fml.ux.select.IFetchPreviewData
---@field public patch_preview_data     ?fml.ux.select.IPatchPreviewData

---@param params                        fml.fn.select.IParams
---@return nil
local function select(params)
  local title = params.title ---@type string
  local dimension = params.dimension ---@type fml.ux.search.IRawDimension|nil
  local flag_fuzzy = not not params.flag_fuzzy ---@type boolean
  local flag_regex = not not params.flag_regex ---@type boolean
  local input = params.input ---@type eve.collection.IObservable | nil
  local multiple = params.multiple ---@type boolean|nil
  local preview_wrap = params.preview_wrap ---@type boolean|nil
  local fetch_items = params.fetch_items ---@type fun(): fml.ux.select.IItem[]
  local on_confirm = params.on_confirm ---@type fml.ux.select.IOnConfirm
  local get_curosr = params.get_cursor ---@type (fun(): string|nil) | nil
  local get_present = params.get_present ---@type (fun(): string|nil) | nil
  local render_item = params.render_item ---@type fml.ux.select.IRenderItem | nil
  local fetch_preview_data = params.fetch_preview_data ---@type fml.ux.select.IFetchPreviewData | nil
  local patch_preview_data = params.patch_preview_data ---@type fml.ux.select.IPatchPreviewData | nil
  local last_items = nil ---@type fml.ux.select.IItem[] | nil

  local preview_enabled = not not fetch_preview_data ---@type boolean

  ---@type fml.ux.select.IProvider
  local provider = {
    fetch_data = function(force)
      if force or last_items == nil then
        last_items = fetch_items() ---@type fml.ux.select.IItem[]
      end

      local uuid_cursor = get_curosr ~= nil and get_curosr() or nil ---@type string|nil
      local uuid_present = get_present ~= nil and get_present() or nil ---@type string|nil

      ---@type fml.ux.select.IData
      local data = { items = last_items, uuid_cursor = uuid_cursor, uuid_present = uuid_present }
      return data
    end,
    render_item = render_item,
    fetch_preview_data = fetch_preview_data,
    patch_preview_data = patch_preview_data,
  }

  Select.new({
    dimension = dimension,
    extend_preset_keymaps = true,
    flag_fuzzy = Observable.from_value(flag_fuzzy),
    flag_regex = Observable.from_value(flag_regex),
    input = input,
    multiple = multiple,
    permanent = false,
    preview_enabled = preview_enabled,
    preview_wrap = preview_wrap,
    provider = provider,
    title = title,
    on_confirm = on_confirm,
  }):show()
end

return select
