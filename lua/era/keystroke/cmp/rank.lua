---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.rank" ---@type string

local Context = require("era.keystroke.cmp.context")
local Item = require("era.keystroke.cmp.item")
local new_table = require("table.new")
local M = {}

---@class era.keystroke.cmp.IRankRegion
---@field public context                era.keystroke.cmp.IContext
---@field public start_col              integer

---@class era.keystroke.cmp.IRankGroup
---@field public start_col              integer
---@field public items                  era.keystroke.cmp.IItem[]
---@field public regions                era.keystroke.cmp.IRankRegion[]
---@field public snapshot               yoz.completion.Snapshot

---@param items                         era.keystroke.cmp.IItem[]
---@return era.keystroke.cmp.IRankGroup[]
function M.prepare(items)
  local builders, by_start = {}, {}
  for _, item in ipairs(items) do
    local start_col = item.filter_start_col or item.start_col
    local group = by_start[start_col]
    if group == nil then
      -- Most sources share one filter start; reserve one list's capacity across all groups.
      local capacity = #builders == 0 and #items or 0
      group = {
        start_col = start_col,
        items = new_table(capacity, 0),
        regions = {},
        by_context = {},
        data = {
          labels = new_table(capacity, 0),
          filters = new_table(capacity, 0),
          sort_texts = new_table(capacity, 0),
          ids = new_table(capacity, 0),
          frecency_keys = new_table(capacity, 0),
          offsets = new_table(capacity, 0),
          deprecated = new_table(capacity, 0),
          regions = new_table(capacity, 0),
          filetypes = {},
        },
      }
      builders[#builders + 1] = group
      by_start[start_col] = group
    end
    local regions = group.by_context[item.context]
    if regions == nil then
      regions = {}
      group.by_context[item.context] = regions
    end
    local region = regions[item.start_col]
    if region == nil then
      region = #group.regions + 1
      regions[item.start_col] = region
      group.regions[region] = { context = item.context, start_col = item.start_col }
      group.data.filetypes[region] = item.context.filetype
    end
    local index = #group.items + 1
    local raw, data = item.raw, group.data
    group.items[index] = item
    data.labels[index] = raw.label
    data.filters[index] = Item.optional(raw.filterText) or raw.label
    data.sort_texts[index] = Item.optional(raw.sortText) or false
    data.ids[index] = item.id
    data.frecency_keys[index] = item.frecency_key
    data.offsets[index] = item.score_offset
    local tags = Item.optional(raw.tags)
    data.deprecated[index] = raw.deprecated == true or (tags ~= nil and vim.list_contains(tags, 1))
    data.regions[index] = region
  end
  local groups = {} ---@type era.keystroke.cmp.IRankGroup[]
  for _, group in ipairs(builders) do
    groups[#groups + 1] = {
      start_col = group.start_col,
      items = group.items,
      regions = group.regions,
      snapshot = yoz.completion.new_snapshot(group.data),
    }
  end
  return groups
end

---@param context                       era.keystroke.cmp.IContext
---@param groups                        era.keystroke.cmp.IRankGroup[]
---@param frecency                      ?yoz.completion.History
---@return era.keystroke.cmp.IItem[]
function M.filter(context, groups, frecency)
  local requests = {} ---@type yoz.completion.IRankRequest[]
  local active = {} ---@type era.keystroke.cmp.IRankGroup[]
  for _, group in ipairs(groups) do
    local eligible, any = {}, false
    for index, region in ipairs(group.regions) do
      local valid = Context.compatible(region.context, context, region.start_col)
      eligible[index] = valid
      any = any or valid
    end
    if any then
      local query = context.line:sub(group.start_col + 1, context.col)
      if yoz.string.is_utf8(query) then
        active[#active + 1] = group
        requests[#requests + 1] = { snapshot = group.snapshot, query = query, eligible = eligible }
      end
    end
  end
  if #requests == 0 then
    return {}
  end
  local nearby = ""
  local first = math.max(0, context.row - 30)
  local last = math.min(vim.api.nvim_buf_line_count(context.bufnr), context.row + 31)
  local size = vim.api.nvim_buf_get_offset(context.bufnr, last) - vim.api.nvim_buf_get_offset(context.bufnr, first)
  -- Offsets may include a final EOL that is absent from the joined text.
  if size >= 0 and size <= 10001 then
    nearby = table.concat(vim.api.nvim_buf_get_lines(context.bufnr, first, last, false), "\n")
    if #nearby > 10000 then
      nearby = ""
    end
  end
  local sources, indexes, scores = yoz.completion.rank(requests, nearby, frecency)
  local ranked = {} ---@type era.keystroke.cmp.IItem[]
  for position, source in ipairs(sources) do
    local item = active[source].items[indexes[position]]
    item.score = scores[position]
    ranked[position] = item
  end
  return ranked
end

return M
