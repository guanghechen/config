---@class ghc.dressing.select.IOptions
---@field public prompt                 ?string
---@field public format_item            ?fun(item): string
---@field public kind                   ?string

---@class ghc.dressing.select.IItemData
---@field public original_item          any

---@alias ghc.dressing.select.IProvider
---| fun(items: any[], opts: ghc.dressing.select.IOptions): fml.types.ui.select.IProvider, integer

local codeaction_provider = require("ghc.dressing.provider.codeaction")
local fallback_provider = require("ghc.dressing.provider.fallback")

local providers = {
  codeaction = codeaction_provider,
  fallback = fallback_provider,
}

---@param items                         any[]
---@param opts                          ghc.dressing.select.IOptions
---@param on_choice                     fun(item: any|nil, idx: integer|nil): nil
---@return nil
local function ghc_select(items, opts, on_choice)
  local title = (opts.prompt or opts.kind or "--"):gsub(":$", "") ---@type string
  local kind = opts.kind or "fallback" ---@type string
  local create_provider = providers[kind] or providers.fallback ---@type ghc.dressing.select.IProvider
  local provider, width = create_provider(items, opts)
  local confirmed = false ---@type boolean

  ---@type fml.types.ui.ISelect
  local select = fml.ui.Select.new({
    destroy_on_close = true,
    dimension = {
      height = #items + 3,
      max_height = 0.8,
      max_width = 0.8,
      min_width = 40,
      width = width + 10,
    },
    enable_preview = false,
    extend_preset_keymaps = true,
    title = title,
    provider = provider,
    on_close = function()
      if not confirmed then
        confirmed = true
        on_choice(nil, nil)
      end
    end,
    on_confirm = function(item)
      on_choice(item.data.original_item, tonumber(item.uuid))
      confirmed = true
      return "close"
    end,
  })

  select:focus()
end

vim.ui.select = ghc_select
