---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.snapshot" ---@type string

local protocol = require("era.m.cmp.protocol")
local util = require("era.m.cmp.source.util")
local MAX_ITEMS = 200

---@class era.m.cmp.snapshot.IHistory
---@field public usage                  yoz.cmp.IUsage
---@field public keys                   table<string, boolean>
---@field public labels                 table<string, table<string, boolean>>

---@class era.m.cmp.snapshot
local M = {}

---@param context                       era.m.cmp.IContext
---@return string[]|nil
local function nearby_words(context)
  local line_count = vim.api.nvim_buf_line_count(context.bufnr) ---@type integer
  local start_row = math.max(0, context.row - 30) ---@type integer
  local end_row = math.min(line_count, context.row + 31) ---@type integer
  local text = table.concat(vim.api.nvim_buf_get_lines(context.bufnr, start_row, end_row, false), "\n") ---@type string
  if #text >= 10000 then
    return nil
  end
  return yoz.cmp.words(text, math.max(#text, 1))
end

---@class era.m.cmp.snapshot.IEntry
---@field public item                   era.m.cmp.ICompletionItem
---@field public client                 vim.lsp.Client|nil
---@field public start_col              integer
---@field public suffix_bytes           integer
---@field public usage_key              string|nil
---@field public source_context         era.m.cmp.IContext|nil
---@field public candidate              era.m.cmp.protocol.ICandidate|nil

---@class era.m.cmp.snapshot.ISnapshot
---@field public context                era.m.cmp.IContext
---@field public entries                era.m.cmp.snapshot.IEntry[]
---@field public target_start_col       integer
---@field public index                  yoz.cmp.IIndex

---@param context                       era.m.cmp.IContext
---@param local_result                  lsp.CompletionList
---@param responses                     table<integer, era.m.cmp.protocol.IResponse>
---@param state                         era.m.cmp.snapshot.IHistory
---@param report                        fun(owner: string, err: any): nil
---@return lsp.CompletionList
---@return era.m.cmp.snapshot.ISnapshot
function M.build(context, local_result, responses, state, report)
  local history, history_keys, history_labels = state.usage, state.keys, state.labels
  local entries = {} ---@type era.m.cmp.snapshot.IEntry[]
  local target_start_col = context.start_col ---@type integer

  ---@param item                        era.m.cmp.ICompletionItem
  ---@param client                      ?vim.lsp.Client
  ---@param used_labels                 ?table<string, boolean>
  ---@param source_context              era.m.cmp.IContext
  ---@param candidate                   ?era.m.cmp.protocol.ICandidate
  ---@return nil
  local function collect(item, client, used_labels, source_context, candidate)
    local owner = client and client.name or "local" ---@type string
    local encoding = client and (client.offset_encoding or "utf-16") or "utf-8" ---@type string
    local ok, entry = pcall(function()
      if type(item) ~= "table" then
        error("completion item is not a table", 0)
      end
      if client == nil then
        protocol.validate(item)
      end
      local start_col = protocol.start_col(item, context, encoding, source_context)
      local suffix_bytes = protocol.suffix_bytes(item, context, encoding, source_context)
      if start_col == nil or suffix_bytes == nil then
        return nil
      end
      local meta = client == nil and util.meta(item) or nil ---@type era.m.cmp.IMeta|nil
      local usage_key = nil ---@type string|nil
      if client ~= nil then
        if used_labels ~= nil and used_labels[item.label] then
          local key = protocol.usage_key(client.name, item)
          usage_key = history_keys[key] and key or nil
        end
      else
        local key = assert(meta).usage_key or util.usage_key(meta.source, item)
        usage_key = history_keys[key] and key or nil
      end
      return {
        item = item,
        client = client,
        start_col = start_col,
        suffix_bytes = suffix_bytes,
        usage_key = usage_key,
        source_context = source_context,
        candidate = candidate,
      }
    end)
    if not ok then
      report(owner, entry)
      return
    end
    if entry ~= nil then
      report(owner, nil)
      target_start_col = math.min(target_start_col, entry.start_col)
      entries[#entries + 1] = entry
    end
  end

  local local_items = type(local_result) == "table" and local_result.items or nil
  if type(local_items) == "table" then
    for _, item in ipairs(local_items) do
      collect(item, nil, nil, context)
    end
  end

  for _, response in pairs(responses) do
    local used_labels = history_labels[response.client.name]
    for _, candidate in ipairs(response.items) do
      collect(candidate.item, response.client, used_labels, candidate.context, candidate)
    end
  end

  local query = context.line:sub(target_start_col + 1, context.col) ---@type string
  local texts = {} ---@type string[]
  local score_offsets = nil ---@type integer|integer[]|nil
  local usage_keys = next(history_keys) ~= nil and {} or nil ---@type (string|nil)[]|nil
  local sort_texts = true ---@type string[]|true
  local proximity_keys = {} ---@type string[]
  for index, entry in ipairs(entries) do
    local item = entry.item ---@type era.m.cmp.ICompletionItem
    local meta = entry.client == nil and util.meta(item) or nil ---@type era.m.cmp.IMeta|nil
    texts[index] = context.line:sub(target_start_col + 1, entry.start_col) .. (item.filterText or item.label)
    proximity_keys[index] = item.label
    local score_offset = entry.client and 180 or (meta and meta.priority or 0) ---@type integer
    if score_offsets == nil then
      score_offsets = score_offset
    elseif type(score_offsets) == "number" then
      if score_offsets ~= score_offset then
        local previous_score_offset = score_offsets
        score_offsets = {}
        for previous = 1, index - 1 do
          score_offsets[previous] = previous_score_offset
        end
        score_offsets[index] = score_offset
      end
    else
      score_offsets[index] = score_offset
    end
    if usage_keys ~= nil then
      usage_keys[index] = entry.usage_key
    end
    local sort_text = item.sortText or item.label ---@type string
    if sort_texts == true then
      if sort_text ~= texts[index] then
        sort_texts = {} ---@type string[]
        for previous = 1, index - 1 do
          sort_texts[previous] = texts[previous]
        end
        sort_texts[index] = sort_text
      end
    else
      sort_texts[index] = sort_text
    end
  end

  local rank_index = yoz.cmp.index(texts, score_offsets, usage_keys, sort_texts, proximity_keys) ---@type yoz.cmp.IIndex
  local matched = rank_index:rank(query, history, os.time(), MAX_ITEMS, nearby_words(context)) ---@type integer[]
  local items = {} ---@type era.m.cmp.ICompletionItem[]
  for _, entry_index in ipairs(matched) do
    local entry = entries[entry_index] ---@type era.m.cmp.snapshot.IEntry|nil
    if entry ~= nil then
      local owner = entry.client and entry.client.name or "local" ---@type string
      local usage_key = entry.client ~= nil and entry.usage_key or nil
      local ok, item = pcall(function()
        return protocol.normalize(
          entry.item,
          context,
          entry.start_col,
          target_start_col,
          entry.suffix_bytes,
          usage_key,
          entry.client,
          nil,
          nil,
          entry.source_context,
          entry.candidate
        )
      end)
      if ok then
        if item ~= nil then
          items[#items + 1] = item
        end
      else
        report(owner, item)
      end
    end
  end

  return { isIncomplete = true, items = items }, {
    context = context,
    entries = entries,
    target_start_col = target_start_col,
    index = rank_index,
  }
end

---@param context                       era.m.cmp.IContext
---@param snapshot                      era.m.cmp.snapshot.ISnapshot
---@param state                         era.m.cmp.snapshot.IHistory
---@param report                        fun(owner: string, err: any): nil
---@return lsp.CompletionList
function M.rank(context, snapshot, state, report)
  local history = state.usage
  local target_start_col = snapshot.target_start_col ---@type integer
  if target_start_col >= snapshot.context.col then
    target_start_col = target_start_col + context.col - snapshot.context.col
  end
  local query = context.line:sub(target_start_col + 1, context.col) ---@type string
  local matched = snapshot.index:rank(query, history, os.time(), MAX_ITEMS, nearby_words(context)) ---@type integer[]
  local items = {} ---@type era.m.cmp.ICompletionItem[]
  for _, entry_index in ipairs(matched) do
    local entry = snapshot.entries[entry_index]
    if entry ~= nil then
      local encoding = entry.client and (entry.client.offset_encoding or "utf-16") or "utf-8" ---@type string
      local start_col = protocol.start_col(entry.item, context, encoding, entry.source_context)
      local suffix_bytes = protocol.suffix_bytes(entry.item, context, encoding, entry.source_context)
      if start_col ~= nil and suffix_bytes ~= nil then
        local owner = entry.client and entry.client.name or "local" ---@type string
        local ok, item = pcall(
          protocol.normalize,
          entry.item,
          context,
          start_col,
          target_start_col,
          suffix_bytes,
          entry.client and entry.usage_key or nil,
          entry.client,
          nil,
          nil,
          entry.source_context,
          entry.candidate
        )
        if ok then
          if item ~= nil then
            items[#items + 1] = item
          end
        else
          report(owner, item)
        end
      end
    end
  end
  return { isIncomplete = true, items = items }
end

return M
