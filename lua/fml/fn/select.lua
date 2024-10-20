local Select = require("fml.ux.component.select")

---@class fml.fn.select.IParams
---@field public title                  string
---@field public fetch_items            fun(): t.fml.ux.select.IItem[]
---@field public on_confirm             fun(item: t.fml.ux.select.IItem): t.eve.e.WidgetConfirmAction|nil

---@param params                        fml.fn.select.IParams
---@return nil
local function select(params)
  local title = params.title ---@type string
  local fetch_items = params.fetch_items ---@type fun(): t.fml.ux.select.IItem[]
  local on_confirm = params.on_confirm ---@type fun(item: t.fml.ux.select.IItem): nil
  local last_items = nil ---@type t.fml.ux.select.IItem[] | nil

  ---@type t.fml.ux.select.IProvider
  local provider = {
    fetch_data = function(force)
      if force or last_items == nil then
        last_items = fetch_items() ---@type t.fml.ux.select.IItem[]
      end

      ---@type t.fml.ux.select.IData
      local data = { items = last_items }
      return data
    end,
  }

  Select.new({
    enable_preview = false,
    permanent = false,
    title = title,
    on_confirm = function(item)
      return on_confirm(item) or "close"
    end,
    provider = provider,
  }):focus()
end

return select
