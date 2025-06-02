---@class fml.dressing.select.IOptions
---@field public prompt                 ?string
---@field public format_item            ?fun(item): string
---@field public kind                   ?string

---@class fml.dressing.select.IItemData
---@field public original_item          any

---@alias fml.dressing.select.IProvider
---| fun(items: any[], opts: fml.dressing.select.IOptions): eve.ux.select.IProvider, integer

local codeaction_provider = require("fml.dressing.select.provider.codeaction")
local fallback_provider = require("fml.dressing.select.provider.fallback")

local providers = {
  codeaction = codeaction_provider,
  fallback = fallback_provider,
}

---@type table<string, eve.context.select.item.state>
local states_by_title = {
  ["(Avante) Add a file"] = eve.context.select.select_avante,
}

---@class fml.dressing.select
local M = {}

---@param items                         any[]
---@param opts                          fml.dressing.select.IOptions
---@param on_choice                     fun(item: any|nil, idx: integer|nil): nil
---@return nil
function M.select(items, opts, on_choice)
  local title = (opts.prompt or opts.kind or "--"):gsub(":$", "") ---@type string
  local kind = opts.kind or "fallback" ---@type string
  local create_provider = providers[kind] or providers.fallback ---@type fml.dressing.select.IProvider
  local provider, width = create_provider(items, opts)
  local confirmed = false ---@type boolean

  local _selector = nil ---@type eve.ux.ISelect|nil
  local winnr = vim.api.nvim_get_current_win()
  local context = states_by_title[title] ---@type eve.context.select.item.state|nil

  title = (#title > 1 and string.sub(title, 1, 1) ~= " ") and " " .. title .. " " or title ---@type string

  ---@type eve.ux.ISelect
  _selector = eve.ux.Select.new({
    dimension = {
      height = #items + 3,
      max_height = 0.8,
      max_width = 0.8,
      width = math.max(60, width + 10),
    },
    case_sensitive = context and context.flag_case_sensitive or nil,
    flag_fuzzy = context and context.flag_fuzzy or nil,
    input = context and context.input or nil,
    input_history = context and context.input_history or nil,
    multiple = false,
    preview_enabled = false,
    extend_preset_keymaps = true,
    title = title,
    provider = provider,
    on_close = function()
      if not confirmed then
        confirmed = true
        on_choice(nil, nil)
      end

      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_tabpage_set_win(0, winnr)
      end
    end,
    on_confirm = function(widget, items_selected)
      if #items_selected == 1 then
        confirmed = true
        local item = items_selected[1] ---@type eve.ux.select.IItem
        on_choice(item.data.original_item, tonumber(item.uuid))

        widget:close()
        if vim.api.nvim_win_is_valid(winnr) then
          vim.api.nvim_tabpage_set_win(0, winnr)
        end
      end
    end,
  })

  _selector:focus()
end

local original_select = vim.ui.select
std.fn.observe({ eve.context.flight.dressing_select }, function()
  local flag = eve.context.flight.dressing_select:snapshot() ---@type boolean
  if flag then
    vim.ui.select = M.select
  else
    vim.ui.select = original_select
  end
end, false)

return M
