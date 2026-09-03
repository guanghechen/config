---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.source.buffer" ---@type string

local util = require("era.m.cmp.source.util")

local M = {}

---@class era.m.cmp.source.buffer.ICache
---@field public changedtick             integer
---@field public name                    string
---@field public words                   string[]

---@class era.m.cmp.source.buffer.IMergedCache
---@field public signature               string
---@field public words                   string[]
---@field public matcher                 yoz.cmp.IMatcher

local cache = {} ---@type table<integer, era.m.cmp.source.buffer.ICache>
local merged_cache = {} ---@type table<integer, era.m.cmp.source.buffer.IMergedCache>
local MAX_ITEMS = 200 ---@type integer

---@param context                       era.m.cmp.IContext
---@return integer[]
local function get_bufnrs(context)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    return { context.bufnr }
  end

  local bufnrs = {} ---@type integer[]
  for _, buf in ipairs(meta.bufs) do
    if #bufnrs >= 10 then
      break
    end
    local bufnr = buf.bufnr ---@type integer
    if util.is_safe_buffer(bufnr) and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" then
      local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
      local size = vim.api.nvim_buf_get_offset(bufnr, line_count) ---@type integer
      if line_count <= 5000 and size >= 0 and size < 131072 then
        bufnrs[#bufnrs + 1] = bufnr
      end
    end
  end
  return bufnrs
end

---@param bufnr                         integer
---@return era.m.cmp.source.buffer.ICache
local function get_cache(bufnr)
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  local name = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local cached = cache[bufnr]
  if cached ~= nil and cached.changedtick == changedtick and cached.name == name then
    return cached
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local text = table.concat(lines, "\n") ---@type string
  local words = yoz.cmp.words(text, math.max(#text, 1)) ---@type string[]
  cached = { changedtick = changedtick, name = name, words = words }
  cache[bufnr] = cached
  return cached
end

---@param context                       era.m.cmp.IContext
---@return era.m.cmp.source.buffer.IMergedCache
local function get_merged_words(context)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local caches = {} ---@type era.m.cmp.source.buffer.ICache[]
  local signature = {} ---@type string[]
  for _, bufnr in ipairs(get_bufnrs(context)) do
    local cached = get_cache(bufnr)
    caches[#caches + 1] = cached
    signature[#signature + 1] = string.format("%d\0%d\0%s", bufnr, cached.changedtick, cached.name)
  end

  local key = table.concat(signature, "\0") ---@type string
  local merged = merged_cache[tabnr]
  if merged ~= nil and merged.signature == key then
    return merged
  end

  local seen = {} ---@type table<string, boolean>
  local words = {} ---@type string[]
  for _, cached in ipairs(caches) do
    for _, word in ipairs(cached.words) do
      if not seen[word] then
        seen[word] = true
        words[#words + 1] = word
      end
    end
  end
  local candidates = {} ---@type yoz.cmp.IMatchItem[]
  for index, word in ipairs(words) do
    candidates[index] = {
      text = word,
      score_offset = 100,
      usage_key = "buffer\0" .. word,
    }
  end
  merged = { signature = key, words = words, matcher = yoz.cmp.matcher(candidates) }
  merged_cache[tabnr] = merged
  return merged
end

---@param context                       era.m.cmp.IContext
---@param history                       yoz.cmp.IUsage|table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>|nil
---@return lsp.CompletionItem[]
function M.complete(context, history)
  if #context.keyword < 2 then
    return {}
  end

  local merged = get_merged_words(context)
  local matched = merged.matcher:match(context.keyword, history, os.time(), MAX_ITEMS + 1)
  local items = {} ---@type lsp.CompletionItem[]
  for _, result in ipairs(matched) do
    local word = merged.words[result.index] ---@type string|nil
    if word ~= nil and word ~= context.keyword then
      local item = util.item("buffer", 100, {
        label = word,
        kind = vim.lsp.protocol.CompletionItemKind.Text,
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        textEdit = {
          newText = word,
          range = util.range(context, context.start_col, context.end_col),
        },
      }, "buffer\0" .. word)
      local meta = assert(util.meta(item))
      meta.score = result.score
      meta.exact = result.exact
      items[#items + 1] = item
      if #items >= MAX_ITEMS then
        break
      end
    end
  end
  return items
end

---@param bufnr                         integer
function M.clear(bufnr)
  cache[bufnr] = nil
  merged_cache = {}
end

return M
