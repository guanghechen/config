local Observable = require("eve.collection.observable")
local Select = require("fml.ux.component.select")

---@class fml.fn.select.IParams
---@field public title                  string
---@field public dimension              ?fml.t.ux.search.IRawDimension
---@field public flag_fuzzy             ?boolean
---@field public flag_regex             ?boolean
---@field public input                  ?eve.t.collection.IObservable
---@field public preview_flag_wrap      ?boolean
---@field public fetch_items            fun(): fml.t.ux.select.IItem[]
---@field public on_confirm             fun(item: fml.t.ux.select.IItem): eve.e.WidgetConfirmAction|nil
---@field public get_present            ?fun(): string|nil
---@field public render_item            ?fml.t.ux.select.IRenderItem
---@field public fetch_preview_data     ?fml.t.ux.select.IFetchPreviewData
---@field public patch_preview_data     ?fml.t.ux.select.IPatchPreviewData

---@param params                        fml.fn.select.IParams
---@return nil
local function select(params)
  local title = params.title ---@type string
  local dimension = params.dimension ---@type fml.t.ux.search.IRawDimension|nil
  local flag_fuzzy = not not params.flag_fuzzy ---@type boolean
  local flag_regex = not not params.flag_regex ---@type boolean
  local input = params.input ---@type eve.t.collection.IObservable | nil
  local preview_flag_wrap = params.preview_flag_wrap ---@type boolean|nil
  local fetch_items = params.fetch_items ---@type fun(): fml.t.ux.select.IItem[]
  local on_confirm = params.on_confirm ---@type fun(item: fml.t.ux.select.IItem): nil
  local get_present = params.get_present ---@type (fun(): string|nil) | nil
  local render_item = params.render_item ---@type fml.t.ux.select.IRenderItem | nil
  local fetch_preview_data = params.fetch_preview_data ---@type fml.t.ux.select.IFetchPreviewData | nil
  local patch_preview_data = params.patch_preview_data ---@type fml.t.ux.select.IPatchPreviewData | nil
  local last_items = nil ---@type fml.t.ux.select.IItem[] | nil

  local preview_enabled = not not fetch_preview_data ---@type boolean

  ---@type fml.t.ux.select.IProvider
  local provider = {
    fetch_data = function(force)
      if force or last_items == nil then
        last_items = fetch_items() ---@type fml.t.ux.select.IItem[]
      end

      local present = get_present ~= nil and get_present() or nil ---@type string|nil

      ---@type fml.t.ux.select.IData
      local data = { items = last_items, present_uuid = present }
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
    permanent = false,
    preview_enabled = preview_enabled,
    preview_flag_wrap = preview_flag_wrap,
    provider = provider,
    title = title,
    on_confirm = function(item)
      return on_confirm(item) or "close"
    end,
  }):focus()
end

return select
