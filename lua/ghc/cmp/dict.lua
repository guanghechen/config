local __module_name__ = "ghc.cmp.dict" ---@type string

---@alias ghc.cmp.dict.IMatchMode
---| "prefix"
---| "substring"

---@alias IBlinkCmpDocumentation
---| string
---| { kind: lsp.MarkupKind, value: string, draw?: fun(opts?: unknown) }

---@class ghc.cmp.dict.IConfig
---@field public dictionary_module      string
---@field public max_items              integer
---@field public min_keyword_length     integer
---@field public match_mode             ghc.cmp.dict.IMatchMode
---@field public include_compounds      boolean
---@field public adjust_case            boolean
---@field public language               string

---@class ghc.cmp.dict
---@field public opts                   ghc.cmp.dict.IConfig
---@field public entries                { word: string, documentation: string }[]
---@field public kind_text              integer
---@field public insert_format          integer
local M = {}

local defaults = {
  dictionary_module = "resource.dict.en",
  max_items = 20,
  min_keyword_length = 3,
  match_mode = "prefix",
  include_compounds = false,
  adjust_case = true,
  language = "en",
}

local function keyword_bounds(context)
  if type(context.get_bounds) == "function" then
    local bounds = context:get_bounds("prefix")
    local keyword = bounds.length > 0 and context.line:sub(bounds.start_col, bounds.start_col + bounds.length - 1) or ""
    return keyword,
      {
        start = { line = bounds.line_number - 1, character = bounds.start_col - 1 },
        ["end"] = { line = bounds.line_number - 1, character = bounds.start_col - 1 + bounds.length },
      }
  end

  local start_col, end_col = require("blink.cmp.fuzzy").get_keyword_range(context.line, context.cursor[2], "prefix")
  local keyword = ""
  if end_col > start_col then
    keyword = context.line:sub(start_col + 1, end_col)
  end
  return keyword,
    {
      start = { line = context.cursor[1] - 1, character = start_col },
      ["end"] = { line = context.cursor[1] - 1, character = end_col },
    }
end

local function empty_response(pending)
  pending = pending == true
  return { is_incomplete_forward = pending, is_incomplete_backward = pending, items = {} }
end

local function expand_indices(results, max_items)
  local expanded = {}
  local limit = max_items or math.huge

  if type(results) ~= "table" then
    return expanded
  end

  for _, entry in ipairs(results) do
    if type(entry) ~= "table" then
      goto continue
    end

    local kind = entry.type
    local indexes = entry.indexes
    if type(indexes) ~= "table" then
      goto continue
    end

    if kind == "scalar" then
      for _, value in ipairs(indexes) do
        if type(value) == "number" then
          expanded[#expanded + 1] = math.floor(value + 0.5)
          if #expanded >= limit then
            return expanded
          end
        end
      end
    elseif kind == "segment" then
      local i = 1
      while i <= #indexes do
        local start_index = indexes[i]
        local end_index = indexes[i + 1]
        if type(start_index) ~= "number" or type(end_index) ~= "number" then
          break
        end
        start_index = math.floor(start_index + 0.5)
        end_index = math.floor(end_index + 0.5)
        for index = start_index, end_index - 1 do
          expanded[#expanded + 1] = index
          if #expanded >= limit then
            return expanded
          end
        end
        i = i + 2
      end
    end

    ::continue::
  end

  return expanded
end

function M.new(opts)
  local self = setmetatable({}, { __index = M })

  ---@type ghc.cmp.dict.IConfig
  opts = vim.tbl_deep_extend("keep", opts or {}, defaults)
  opts.match_mode = opts.match_mode == "substring" and "substring" or "prefix"
  opts.max_items = math.max(1, opts.max_items)
  opts.min_keyword_length = math.max(1, opts.min_keyword_length)

  self.opts = opts
  local entries = {}
  local loaded = require(opts.dictionary_module)
  if type(loaded) == "table" then
    for index, item in ipairs(loaded) do
      if type(item) == "table" then
        local word = item[1]
        local documentation = item[2]
        if type(word) == "string" and type(documentation) == "string" then
          entries[index] = { word = word, documentation = documentation }
        end
      end
    end
  else
    std.reporter.error({
      from = __module_name__,
      subject = "load dictionary",
      message = "Dictionary module did not return a table",
      details = { module = opts.dictionary_module },
    })
  end

  self.entries = entries
  self.kind_text = require("blink.cmp.types").CompletionItemKind.Text
  self.insert_format = vim.lsp.protocol.InsertTextFormat.PlainText

  return self
end

---@return boolean
function M:enabled()
  return #self.entries > 0
end

function M:apply_case(prefix, word)
  if not self.opts.adjust_case then
    return word
  end
  if not word:match("^[%l%-%']+$") then
    return word
  end
  if prefix:match("^%u%u") then
    return word:upper()
  end
  if prefix:match("^%u") then
    return word:sub(1, 1):upper() .. word:sub(2)
  end
  return word
end

---@param range                         lsp.Range
---@param prefix                        string
---@param word                          string
---@param documentation                 string
---@param index                         integer
---@return lsp.CompletionItem
function M:make_item(range, prefix, word, documentation, index)
  local display = self:apply_case(prefix, word)
  return {
    label = display,
    kind = self.kind_text,
    insertTextFormat = self.insert_format,
    insertText = display,
    filterText = word,
    sortText = word,
    textEdit = {
      newText = display,
      range = vim.deepcopy(range),
    },
    documentation = {
      kind = "plaintext",
      value = documentation,
    },
    data = { word = word, index = index },
  }
end

function M:get_completions(context, callback)
  callback = vim.schedule_wrap(callback)

  local keyword, range = keyword_bounds(context)
  if keyword == "" or #keyword < self.opts.min_keyword_length then
    return callback(empty_response(true))
  end

  local ok, results = pcall(rstd.dict.search, {
    keyword = keyword,
    language = self.opts.language,
    match_mode = self.opts.match_mode,
    include_compounds = self.opts.include_compounds,
    max_items = self.opts.max_items,
  })

  if not ok then
    std.reporter.error({
      from = __module_name__,
      subject = "dictionary search",
      message = "Failed to execute rstd.dict.search",
      details = results,
    })
    return callback(empty_response(false))
  end

  if type(results) ~= "table" then
    return callback(empty_response(false))
  end

  local indices = expand_indices(results, self.opts.max_items)

  local items = {}
  for _, index_value in ipairs(indices) do
    local entry = self.entries[index_value]
    if entry ~= nil then
      items[#items + 1] = self:make_item(range, keyword, entry.word, entry.documentation, index_value)
      if #items >= self.opts.max_items then
        break
      end
    end
  end

  callback({
    is_incomplete_forward = false,
    is_incomplete_backward = false,
    items = items,
  })
end

function M:resolve(item, callback)
  callback = vim.schedule_wrap(callback)
  callback(item)
end

return M
