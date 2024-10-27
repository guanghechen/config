local Select = require("fml.ux.component.select")

---@class fml.fn.select.IParams
---@field public title                  string
---@field public dimension              ?t.fml.ux.search.IRawDimension
---@field public input                  ?t.eve.collection.IObservable
---@field public fetch_items            fun(): t.fml.ux.select.IItem[]
---@field public on_confirm             fun(item: t.fml.ux.select.IItem): t.eve.e.WidgetConfirmAction|nil
---@field public get_present            ?fun(): string|nil
---@field public render_item            ?t.fml.ux.select.IRenderItem

---@param params                        fml.fn.select.IParams
---@return nil
local function select(params)
  local title = params.title ---@type string
  local dimension = params.dimension ---@type t.fml.ux.search.IRawDimension|nil
  local input = params.input ---@type t.eve.collection.IObservable | nil
  local fetch_items = params.fetch_items ---@type fun(): t.fml.ux.select.IItem[]
  local on_confirm = params.on_confirm ---@type fun(item: t.fml.ux.select.IItem): nil
  local get_present = params.get_present ---@type (fun(): string|nil) | nil
  local render_item = params.render_item ---@type t.fml.ux.select.IRenderItem | nil
  local last_items = nil ---@type t.fml.ux.select.IItem[] | nil

  ---@type t.fml.ux.select.IProvider
  local provider = {
    fetch_data = function(force)
      if force or last_items == nil then
        last_items = fetch_items() ---@type t.fml.ux.select.IItem[]
      end

      local present = get_present ~= nil and get_present() or nil ---@type string|nil

      ---@type t.fml.ux.select.IData
      local data = { items = last_items, present_uuid = present }
      return data
    end,
    render_item = render_item,
  }

  Select.new({
    enable_preview = false,
    permanent = false,
    title = title,
    dimension = dimension,
    input = input,
    provider = provider,
    on_confirm = function(item)
      return on_confirm(item) or "close"
    end,
  }):focus()
end

return select
