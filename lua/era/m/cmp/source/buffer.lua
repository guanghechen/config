---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.source.buffer" ---@type string

local context_api = require("era.m.cmp.context")
local util = require("era.m.cmp.source.util")

---@class era.m.cmp.source.buffer.ICache
---@field public changedtick            integer
---@field public name                   string
---@field public words                  string[]
---@field public usage_keys             string[]
---@field public index                  yoz.cmp.IIndex|nil
---@field public context                era.m.cmp.IContext|nil
---@field public token_valid            boolean
---@field public tracking               boolean

local cache = {} ---@type table<integer, era.m.cmp.source.buffer.ICache>
local MAX_ITEMS = 200

---@class era.m.cmp.source.buffer
local M = {}

---@param context                       era.m.cmp.IContext
---@return integer[]
local function get_bufnrs(context)
  local tabnr = vim.api.nvim_get_current_tabpage()
  local meta = dot.tab.resolve(tabnr, false)
  if meta == nil then
    return { context.bufnr }
  end
  local bufnrs = {}
  for _, buf in ipairs(meta.bufs) do
    if #bufnrs >= 10 then
      break
    end
    local bufnr = buf.bufnr
    if util.is_safe_buffer(bufnr) and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" then
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      local size = vim.api.nvim_buf_get_offset(bufnr, line_count)
      if line_count <= 5000 and size >= 0 and size < 131072 then
        bufnrs[#bufnrs + 1] = bufnr
      end
    end
  end
  return bufnrs
end

---@param bufnr                         integer
---@return era.m.cmp.source.buffer.ICache
local function create_cache(bufnr)
  local entry = {
    changedtick = -1,
    name = "",
    words = {},
    usage_keys = {},
    index = nil,
    context = nil,
    token_valid = false,
    tracking = false,
  } ---@type era.m.cmp.source.buffer.ICache
  cache[bufnr] = entry
  entry.tracking = vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, target_bufnr, _, first_row, last_row, new_last_row)
      if cache[target_bufnr] ~= entry then
        return true
      end
      local context = entry.context
      if context == nil or first_row ~= context.row or last_row ~= first_row + 1 or new_last_row ~= last_row then
        entry.token_valid = false
      end
    end,
    on_reload = function(_, target_bufnr)
      if cache[target_bufnr] ~= entry then
        return true
      end
      entry.changedtick = -1
      entry.token_valid = false
    end,
    on_detach = function(_, target_bufnr)
      if cache[target_bufnr] == entry then
        cache[target_bufnr] = nil
      end
    end,
  })
  return entry
end

---@param bufnr                         integer
---@param context                       era.m.cmp.IContext|nil
---@return era.m.cmp.source.buffer.ICache
local function get_cache(bufnr, context)
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local entry = cache[bufnr] or create_cache(bufnr)
  if entry.index ~= nil and entry.name == name then
    if entry.context ~= nil then
      if context ~= nil and context_api.same_token(entry.context, context) then
        if entry.changedtick == changedtick or (entry.tracking and entry.token_valid) then
          return entry
        end
      end
    elseif context == nil and entry.changedtick == changedtick then
      return entry
    end
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local anchor = context ~= nil and vim.deepcopy(context) or nil ---@type era.m.cmp.IContext|nil
  local token_valid = false
  if context ~= nil and lines[context.row + 1] == context.line then
    token_valid = true
    lines[context.row + 1] = context.line:sub(1, context.start_col) .. " " .. context.line:sub(context.end_col + 1)
  end
  local text = table.concat(lines, "\n")
  local words = yoz.cmp.words(text, math.max(#text, 1))
  local usage_keys = {} ---@type string[]
  for index, word in ipairs(words) do
    usage_keys[index] = "buffer\0" .. word
  end
  entry.changedtick = changedtick
  entry.name = name
  entry.words = words
  entry.usage_keys = usage_keys
  entry.index = yoz.cmp.index(words, 100, usage_keys)
  entry.context = anchor
  entry.token_valid = token_valid
  return entry
end

---@param context                       era.m.cmp.IContext
---@param history                       yoz.cmp.IUsage|table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>|nil
---@return lsp.CompletionItem[]
function M.complete(context, history)
  if #context.keyword < 2 then
    return {}
  end
  local now = os.time()
  local words = {} ---@type string[]
  local usage_keys = {} ---@type string[]
  local seen = {} ---@type table<string, boolean>
  for _, bufnr in ipairs(get_bufnrs(context)) do
    local entry = get_cache(bufnr, bufnr == context.bufnr and context or nil)
    local matched = assert(entry.index):rank(context.keyword, history, now, MAX_ITEMS + 1)
    for _, index in ipairs(matched) do
      local word = entry.words[index]
      if word ~= context.keyword and not seen[word] then
        seen[word] = true
        words[#words + 1] = word
        usage_keys[#words] = entry.usage_keys[index]
      end
    end
  end
  local matched = yoz.cmp.rank(context.keyword, words, 100, usage_keys, nil, history, now, MAX_ITEMS)
  local items = {} ---@type lsp.CompletionItem[]
  for _, result in ipairs(matched) do
    local word = words[result.index]
    local item = util.item("buffer", 100, {
      label = word,
      kind = vim.lsp.protocol.CompletionItemKind.Text,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
      textEdit = {
        newText = word,
        range = util.range(context, context.start_col),
      },
    }, usage_keys[result.index])
    local meta = assert(util.meta(item))
    meta.score = result.score
    meta.exact = result.exact
    items[#items + 1] = item
  end
  return items
end

---@param bufnr                         integer
---@return nil
function M.clear(bufnr)
  local entry = cache[bufnr]
  cache[bufnr] = nil
  if entry ~= nil then
    entry.index = nil
    entry.words = {}
    entry.usage_keys = {}
    entry.context = nil
  end
end

return M
