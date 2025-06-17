local __module_name__ = "fml.dressing.select" ---@type string

---@class fml.dressing.select.IDimension
---@field public row                    ?integer
---@field public col                    ?integer
---@field public height                 ?integer
---@field public width                  ?integer

---@class fml.dressing.select.IOptions
---@field public name                   ?string
---@field public prompt                 ?string
---@field public format_item            ?fun(item): string
---@field public kind                   ?string
---@field public dimension              ?fml.dressing.select.IDimension
---@field public result_render          ?eve.ux.picker.composer.list.IResultRender
---@field public preview_render         ?eve.ux.picker.composer.list.IPreviewRender
---@field public uuid_current           ?string
---@field public uuid_present           ?string

---@class fml.dressing.select.IItemData
---@field public original_item          any

---@class fml.dressing.select.IItem : eve.ux.picker.composer.list.IItem
---@field public data                   fml.dressing.select.IItemData

---@alias fml.dressing.select.IDataProvider
---| fun(items: any[], opts: fml.dressing.select.IOptions): eve.ux.picker.composer.list.IResetData, integer, eve.ux.picker.composer.list.IResultRender|nil

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
  local name = opts.name or __module_name__ ---@type string
  local title = (opts.prompt or opts.kind or "--"):gsub(":$", "") ---@type string
  local kind = opts.kind or "fallback" ---@type string
  local create_provider = providers[kind] or providers.fallback ---@type fml.dressing.select.IDataProvider
  local data, width, result_render = create_provider(items, opts)
  local preview_render = opts.preview_render ---@type eve.ux.picker.composer.list.IPreviewRender|nil

  if opts.result_render ~= nil then
    result_render = opts.result_render
  end

  local uuid_current = nil ---@type string|nil
  if opts.uuid_current then
    for _, item_data in ipairs(data.items) do
      ---@cast item_data fml.dressing.select.IItem
      if item_data.data.original_item == opts.uuid_current then
        uuid_current = item_data.uuid
        break
      end
    end
  end

  local uuid_present = nil ---@type string|nil
  if opts.uuid_present then
    for _, item_data in ipairs(data.items) do
      ---@cast item_data fml.dressing.select.IItem
      if item_data.data.original_item == opts.uuid_present then
        uuid_present = item_data.uuid
        break
      end
    end
  end

  local winnr = vim.api.nvim_get_current_win()
  local context = states_by_title[title] ---@type eve.context.select.item.state|nil

  title = (#title > 1 and string.sub(title, 1, 1) ~= " ") and " " .. title .. " " or title ---@type string

  local finder_input = std.Observable.from_value(context and context.input:snapshot() or "") ---@type std.collection.IObservable
  local flag_fuzzy = std.Observable.from_value(context and context.flag_fuzzy:snapshot() or true) ---@type std.collection.IObservable
  local flag_regex = std.Observable.from_value(false) ---@type std.collection.IObservable
  local flag_sensitive = std.Observable.from_value(context and context.flag_case_sensitive:snapshot() or false) ---@type std.collection.IObservable

  -- Handle dimension options
  local picker_height = math.min(#items + 3, math.floor(vim.o.lines * 0.8))
  local picker_width = math.max(60, width + 10)

  if opts.dimension then
    if opts.dimension.height then
      picker_height = opts.dimension.height
    elseif opts.dimension.row then
      picker_height = opts.dimension.row
    end
    if opts.dimension.width then
      picker_width = opts.dimension.width
    end
  end

  ---@type eve.ux.picker.ListComposer
  local picker = eve.ux.picker.ListComposer.new({
    name = name,
    permanent = false,
    title = title,
    height = picker_height,
    width = picker_width,

    finder_input = finder_input,
    flag_fuzzy = flag_fuzzy,
    flag_regex = flag_regex,
    flag_sensitive = flag_sensitive,

    result_render = result_render,
    preview_render = preview_render,

    on_cancel = function()
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_tabpage_set_win(0, winnr)
      end
    end,

    on_confirm = function(composer, item)
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_tabpage_set_win(0, winnr)
      end
      composer:close()

      if item ~= nil then
        ---@cast item fml.dressing.select.IItem
        on_choice(item.data.original_item, tonumber(item.uuid))
      else
        on_choice(nil, nil)
      end
    end,

    on_disposed = function()
      finder_input:dispose()
      flag_fuzzy:dispose()
      flag_regex:dispose()
      flag_sensitive:dispose()
    end,
  })

  picker:reset_data({
    items = data.items,
    uuid_current = uuid_current,
    uuid_present = uuid_present,
  })
  picker:focus()
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
