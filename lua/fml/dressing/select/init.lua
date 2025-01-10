local command = require("eve.command")

local Select = require("fml.ux.select")

---@class fml.dressing.select.IOptions
---@field public prompt                 ?string
---@field public format_item            ?fun(item): string
---@field public kind                   ?string

---@class fml.dressing.select.IItemData
---@field public original_item          any

---@alias fml.dressing.select.IProvider
---| fun(items: any[], opts: fml.dressing.select.IOptions): fml.ux.select.IProvider, integer

local codeaction_provider = require("fml.dressing.select.provider.codeaction")
local fallback_provider = require("fml.dressing.select.provider.fallback")

local providers = {
  codeaction = codeaction_provider,
  fallback = fallback_provider,
}

---@param items                         any[]
---@param opts                          fml.dressing.select.IOptions
---@param on_choice                     fun(item: any|nil, idx: integer|nil): nil
---@return nil
local function select(items, opts, on_choice)
  local title = (opts.prompt or opts.kind or "--"):gsub(":$", "") ---@type string
  local kind = opts.kind or "fallback" ---@type string
  local create_provider = providers[kind] or providers.fallback ---@type fml.dressing.select.IProvider
  local provider, width = create_provider(items, opts)
  local confirmed = false ---@type boolean

  local _selector = nil ---@type fml.ux.ISelect|nil

  ---@type fml.ux.ISelect
  _selector = Select.new({
    dimension = {
      height = #items + 3,
      max_height = 0.8,
      max_width = 0.8,
      width = math.max(60, width + 10),
    },
    preview_enabled = false,
    extend_preset_keymaps = true,
    title = title,
    provider = provider,
    on_close = function()
      if not confirmed then
        confirmed = true
        on_choice(nil, nil)
      end

      local context = command.context_snapshot() ---@type eve.command.IContext|nil
      if context ~= nil then
        vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
      end
    end,
    on_confirm = function(widget, item)
      confirmed = true
      on_choice(item.data.original_item, tonumber(item.uuid))

      widget:close()
      local context = command.context_snapshot() ---@type eve.command.IContext|nil
      if context ~= nil then
        vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
      end
    end,
  })

  _selector:show()
end

vim.ui.select = select
