---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.source.buffer" ---@type string

local Context = require("era.keystroke.cmp.context")
local Item = require("era.keystroke.cmp.item")
---@class era.keystroke.cmp.source.buffer.ICache
---@field public tick                   integer
---@field public keyword                string
---@field public lines                  (string[]|false)[]
---@field public counts                 table<string, integer>
---@field public positions              table<string, integer>
---@field public words                  string[]
---@field public raw                    table<string, lsp.CompletionItem>
---@field public pending                { first: integer, last: integer, new_last: integer }[]

local cache = {} ---@type table<integer, era.keystroke.cmp.source.buffer.ICache>
local attached = {} ---@type table<integer, boolean>
local EMPTY_WORDS = {} ---@type string[]
local word_pattern = vim.regex([[\k\{3,}]])
local M = {}

---@param bufnr                         integer
---@param row                           integer
---@param line                          string
---@param standard                      boolean
---@return string[]
local function line_words(bufnr, row, line, standard)
  if line == "" then
    return EMPTY_WORDS
  end
  local seen = {} ---@type table<string, boolean>
  local words = {} ---@type string[]
  if standard and not line:find("[%z\128-\255]") then
    for word in line:gmatch("[A-Za-z0-9_]+") do
      if #word >= 3 and not seen[word] then
        seen[word] = true
        words[#words + 1] = word
      end
    end
  else
    local valid_utf8 = yoz.string.is_utf8(line)
    local length = (line:find("\0", 1, true) or (#line + 1)) - 1
    local offset = 0
    while offset < length do
      local left, right = word_pattern:match_line(bufnr, row, offset, length)
      if left == nil or right == nil or right <= left then
        break
      end
      local word = line:sub(offset + left + 1, offset + right)
      if not seen[word] and (valid_utf8 or yoz.string.is_utf8(word)) then
        seen[word] = true
        words[#words + 1] = word
      end
      offset = offset + right
    end
  end
  return words[1] ~= nil and words or EMPTY_WORDS
end

---@param entry                         era.keystroke.cmp.source.buffer.ICache
---@param words                         string[]|false
---@return nil
local function remove_line(entry, words)
  for _, word in ipairs(words or EMPTY_WORDS) do
    local count = entry.counts[word] - 1
    if count == 0 then
      local position = entry.positions[word]
      local last = entry.words[#entry.words]
      entry.words[position] = last
      entry.positions[last] = position
      entry.words[#entry.words] = nil
      entry.positions[word] = nil
      entry.counts[word] = nil
      entry.raw[word] = nil
    else
      entry.counts[word] = count
    end
  end
end

---@param bufnr                         integer
---@param keyword                       string
---@return era.keystroke.cmp.source.buffer.ICache
local function refresh(bufnr, keyword)
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local entry = cache[bufnr]
  if entry ~= nil and entry.keyword == keyword and entry.tick == tick and #entry.pending == 0 then
    return entry
  end
  if entry == nil or entry.keyword ~= keyword or (entry.tick ~= tick and #entry.pending == 0) then
    entry =
      { tick = tick, keyword = keyword, lines = {}, counts = {}, positions = {}, words = {}, raw = {}, pending = {} }
    for row = 1, vim.api.nvim_buf_line_count(bufnr) do
      entry.lines[row] = false
    end
    cache[bufnr] = entry
  end
  if not attached[bufnr] then
    attached[bufnr] = vim.api.nvim_buf_attach(bufnr, false, {
      on_lines = function(_, changed_bufnr, _, first, last, new_last)
        local current = cache[changed_bufnr]
        if current ~= nil then
          if #current.pending >= 128 then
            -- An idle source must not retain an unbounded edit log.
            cache[changed_bufnr] = nil
          else
            current.pending[#current.pending + 1] = { first = first, last = last, new_last = new_last }
          end
        end
      end,
      on_reload = function(_, changed_bufnr)
        cache[changed_bufnr] = nil
      end,
      on_detach = function(_, detached_bufnr)
        cache[detached_bufnr] = nil
        attached[detached_bufnr] = nil
      end,
    })
  end
  for _, change in ipairs(entry.pending) do
    local size = #entry.lines
    for row = change.first + 1, change.last do
      remove_line(entry, entry.lines[row])
    end
    table.move(entry.lines, change.last + 1, size, change.new_last + 1)
    for row = size + change.new_last - change.last + 1, size do
      entry.lines[row] = nil
    end
    for row = change.first + 1, change.new_last do
      entry.lines[row] = false
    end
  end
  entry.pending = {}
  entry.tick = tick
  local standard = keyword == "@,48-57,_,192-255"
  local row = 1
  while row <= #entry.lines do
    if entry.lines[row] then
      row = row + 1
    else
      local first = row
      while row <= #entry.lines and not entry.lines[row] do
        row = row + 1
      end
      local lines = vim.api.nvim_buf_get_lines(bufnr, first - 1, row - 1, false)
      for offset, line in ipairs(lines) do
        local words = line_words(bufnr, first + offset - 2, line, standard)
        entry.lines[first + offset - 1] = words
        for _, word in ipairs(words) do
          local count = entry.counts[word] or 0
          if count == 0 then
            entry.words[#entry.words + 1] = word
            entry.positions[word] = #entry.words
            entry.raw[word] = { label = word, kind = vim.lsp.protocol.CompletionItemKind.Text }
          end
          entry.counts[word] = count + 1
        end
      end
    end
  end
  return entry
end

---@return integer[]
local function buffer_numbers()
  local meta = dot.tab.resolve(vim.api.nvim_get_current_tabpage(), false)
  local entries = meta and meta.bufs or {}
  local bufnrs = {}
  local total_size = 0
  for _, entry in ipairs(entries) do
    if #bufnrs >= 10 then
      break
    end
    local bufnr = entry.bufnr
    if
      vim.api.nvim_buf_is_valid(bufnr)
      and vim.api.nvim_buf_is_loaded(bufnr)
      and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == ""
      and not Context.is_private(vim.api.nvim_buf_get_name(bufnr))
    then
      local size = vim.api.nvim_buf_get_offset(bufnr, vim.api.nvim_buf_line_count(bufnr))
      if size >= 0 and size < 131072 and total_size + size <= 500000 then
        bufnrs[#bufnrs + 1] = bufnr
        total_size = total_size + size
      end
    end
  end
  return bufnrs
end

---@param context                       era.keystroke.cmp.IContext
---@param callback                      fun(response: era.keystroke.cmp.IResponse): nil
---@return nil
function M.complete(context, callback)
  local items = {} ---@type era.keystroke.cmp.IItem[]
  local seen = {} ---@type table<string, boolean>
  local live = {} ---@type table<integer, boolean>
  local keyword = vim.api.nvim_get_option_value("iskeyword", { buf = 0 })
  for _, bufnr in ipairs(buffer_numbers()) do
    live[bufnr] = true
    local entry = refresh(bufnr, keyword)
    for _, word in ipairs(entry.words) do
      if not seen[word] and word ~= context.keyword then
        seen[word] = true
        items[#items + 1] = Item.new(context, "buffer", entry.raw[word])
      end
    end
  end
  for bufnr in pairs(cache) do
    if not live[bufnr] then
      cache[bufnr] = nil
    end
  end
  callback({ items = items, incomplete = false })
end

return M
