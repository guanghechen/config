---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.source.util" ---@type string

---@class era.m.cmp.IMeta
---@field public source                 string
---@field public priority               integer
---@field public score                  integer
---@field public exact                  boolean
---@field public usage_key?             string

---@class era.m.cmp.IOrigin
---@field public client_id              integer
---@field public candidate?             era.m.cmp.protocol.ICandidate
---@field public context                era.m.cmp.IContext
---@field public item                   lsp.CompletionItem
---@field public start_col              integer
---@field public suffix_bytes           integer
---@field public target_start_col       integer
---@field public source_context?        era.m.cmp.IContext

---@class era.m.cmp.ICompletionItem: lsp.CompletionItem
---@field public _era_cmp_meta?          era.m.cmp.IMeta
---@field public _era_cmp_origin?        era.m.cmp.IOrigin
---@field public _era_cmp_suffix_bytes?  integer
---@field public _era_cmp_cursor_offset ?integer
---@field public _era_cmp_path          ?string

local M = {}

---@param bufnr                         integer
---@return boolean
function M.is_safe_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local filename = yoz.path.basename(vim.api.nvim_buf_get_name(bufnr)) ---@type string
  return not filename:match("^%.env") and not filename:match("%.http%.out$")
end

---@param context                       era.m.cmp.IContext
---@param start_col                     integer
---@param end_col                       integer|nil
---@return lsp.Range
function M.range(context, start_col, end_col)
  return {
    start = { line = context.row, character = start_col },
    ["end"] = { line = context.row, character = end_col or context.col },
  }
end

---@param source                        string
---@param item                          lsp.CompletionItem
---@param scope                         string|nil
---@param semantic                      string|nil
---@return string
function M.usage_key(source, item, scope, semantic)
  return table.concat({
    source,
    scope or "",
    item.label or "",
    item.kind or 0,
    item.filterText or "",
    item.sortText or "",
    semantic or "",
  }, "\0")
end

---@param source                        string
---@param priority                      integer
---@param item                          era.m.cmp.ICompletionItem
---@param usage_key                     string|nil
---@return era.m.cmp.ICompletionItem
function M.item(source, priority, item, usage_key)
  local data = type(item.data) == "table" and item.data or {}
  ---@cast data table
  data.era_cmp = {
    source = source,
    priority = priority,
    score = priority,
    exact = false,
    usage_key = usage_key or M.usage_key(source, item),
  }
  item.data = data
  return item
end

---@param item                          era.m.cmp.ICompletionItem
---@return era.m.cmp.IMeta|nil
function M.meta(item)
  if type(item._era_cmp_meta) == "table" then
    return item._era_cmp_meta
  end
  return type(item.data) == "table" and item.data.era_cmp or nil
end

---@param item                          era.m.cmp.ICompletionItem
---@return string|nil
local function item_key(item)
  local meta = M.meta(item)
  if meta == nil or type(meta.usage_key) ~= "string" then
    return nil
  end
  return meta.usage_key
end

---@param query                         string
---@param items                         era.m.cmp.ICompletionItem[]
---@param history                       yoz.cmp.IUsage|table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>|nil
---@param now                           integer|nil
---@param limit                         integer|nil
---@return era.m.cmp.ICompletionItem[]
function M.filter(query, items, history, now, limit)
  if #items == 0 then
    return items
  end

  local texts = {} ---@type string[]
  local score_offsets = {} ---@type integer[]
  local usage_keys = {} ---@type string[]
  for index, item in ipairs(items) do
    local meta = M.meta(item)
    texts[index] = item.filterText or item.label
    score_offsets[index] = meta and meta.priority or 0
    usage_keys[index] = assert(item_key(item))
  end

  local matched = yoz.cmp.rank(query, texts, score_offsets, usage_keys, nil, history, now, limit) ---@type yoz.cmp.IMatchResult[]
  local output = {} ---@type era.m.cmp.ICompletionItem[]
  for _, result in ipairs(matched) do
    local item = items[result.index] ---@type era.m.cmp.ICompletionItem|nil
    if item ~= nil then
      local meta = M.meta(item)
      if meta ~= nil then
        meta.score = result.score
        meta.exact = result.exact
        output[#output + 1] = item
      end
    end
  end
  return output
end

return M
