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
---@field public render_result          ?dot.module.picker.composer.list.IRenderResult
---@field public render_preview         ?dot.module.picker.composer.list.IRenderPreview
---@field public uuid_current           ?string
---@field public uuid_present           ?string
---@field public on_toggle              ?fun(item: any, idx: integer): nil
---@field public snacks                 ?any

---@class fml.dressing.select.IItemData
---@field public original_item          any

---@class fml.dressing.select.IItem : dot.module.picker.composer.list.IItem
---@field public data                   fml.dressing.select.IItemData

---@alias fml.dressing.select.IDataProvider
---| fun(items: any[], opts: fml.dressing.select.IOptions): dot.module.picker.composer.list.IResetData, integer, dot.module.picker.composer.list.IRenderResult|nil, dot.module.picker.composer.list.IRenderPreview|nil

local providers = {
  ---@type fml.dressing.select.IDataProvider
  codeaction = function(items, opts)
    local provider = require("fml.dressing.select.provider.codeaction")
    return provider(items, opts)
  end,
  ---@type fml.dressing.select.IDataProvider
  snacks = function(items, opts)
    local provider = require("fml.dressing.select.provider.snacks")
    return provider(items, opts)
  end,
  ---@type fml.dressing.select.IDataProvider
  fallback = function(items, opts)
    local provider = require("fml.dressing.select.provider.fallback")
    return provider(items, opts)
  end,
}

---@param opts                          fml.dressing.select.IOptions
---@return fml.dressing.select.IDataProvider
local function resolve_provider(opts)
  local provider = providers[opts.kind] ---@type fml.dressing.select.IDataProvider|nil
  if provider ~= nil then
    return provider
  end

  ---@cast opts any
  if type(opts.snacks) == "table" then
    return providers.snacks
  end

  return providers.fallback
end

---@type table<string, dot.context.select.item.state>
local states_by_title = {}

---@class fml.dressing.select
local M = {}

---@param items                         any[]
---@param opts                          fml.dressing.select.IOptions
---@param on_choice                     fun(item: any|nil, idx: integer|nil): nil
---@return nil
function M.select(items, opts, on_choice)
  local provider = resolve_provider(opts) ---@type fml.dressing.select.IDataProvider

  local name = opts.name or __module_name__ ---@type string
  local title = (opts.prompt or opts.kind or "--"):gsub(":$", "") ---@type string
  local data, width, render_result, render_preview = provider(items, opts)
  if opts.render_result ~= nil then
    render_result = opts.render_result
  end
  if opts.render_preview ~= nil then
    render_preview = opts.render_preview
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
  local context = states_by_title[title] ---@type dot.context.select.item.state|nil

  title = (#title > 1 and string.sub(title, 1, 1) ~= " ") and " " .. title .. " " or title ---@type string

  local is_new_context = context == nil ---@type boolean
  local search_pattern ---@type ark.c.Observable
  local flag_fuzzy ---@type ark.c.Observable
  local flag_regex ---@type ark.c.Observable
  local flag_case_sensitive ---@type ark.c.Observable

  if context then
    -- Use existing context observables
    search_pattern = context.search_pattern
    flag_fuzzy = context.flag_fuzzy
    flag_regex = context.flag_regex
    flag_case_sensitive = context.flag_case_sensitive
  else
    -- Create new observables
    search_pattern = ark.c.Observable.from_value("")
    flag_fuzzy = ark.c.Observable.from_value(true)
    flag_regex = ark.c.Observable.from_value(false)
    flag_case_sensitive = ark.c.Observable.from_value(false)
  end

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

  local on_toggle = opts.on_toggle ---@type fun(item: any, idx: integer): nil|nil

  ---@type dot.module.picker.ListComposer|nil
  local picker = nil

  ---@return nil
  local function do_toggle()
    if not picker or not on_toggle then
      return
    end
    local lnum = picker.result.lnum_current:snapshot()
    local item = picker:retrieve(lnum)
    if item then
      ---@cast item fml.dressing.select.IItem
      local idx = tonumber(item.uuid) or 0
      on_toggle(item.data.original_item, idx)
    end
  end

  picker = dot.picker.ListComposer.new({
    name = name,
    permanent = false,
    title = title,
    height = picker_height,
    width = picker_width,

    search_pattern = search_pattern,
    flag_fuzzy = flag_fuzzy,
    flag_regex = flag_regex,
    flag_case_sensitive = flag_case_sensitive,

    render_result = render_result,
    render_preview = render_preview,

    keymaps_common = on_toggle and {
      { modes = { "i", "n", "x" }, key = "<C-l>", callback = do_toggle, desc = "Toggle selection" },
      { modes = { "i", "n", "x" }, key = "<C-h>", callback = do_toggle, desc = "Toggle selection" },
    } or nil,
    keymaps_result = on_toggle and {
      { modes = { "i", "n", "x" }, key = "<space>", callback = do_toggle, desc = "Toggle selection" },
    } or nil,

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
      -- Only dispose if we created new observables
      if is_new_context then
        search_pattern:dispose()
        flag_fuzzy:dispose()
        flag_regex:dispose()
        flag_case_sensitive:dispose()
      end
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
ark.fn.observe({ dot.context.flight.dressing_select }, function()
  local flag = dot.context.flight.dressing_select:snapshot() ---@type boolean
  if flag then
    vim.ui.select = M.select
  else
    vim.ui.select = original_select
  end
end, false)

return M
