---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.source.snippets" ---@type string

local util = require("era.m.cmp.source.util")

---@class era.m.cmp.source.snippets.ISnippet
---@field public prefix                 string
---@field public body                   string
---@field public description            string|nil

local M = {}

local registry = nil ---@type table<string, string[]>|nil
local cache = {} ---@type table<string, era.m.cmp.source.snippets.ISnippet[]>
local matcher_cache = {} ---@type table<string, yoz.cmp.IMatcher>
local trigger_cache = {} ---@type table<string, table<string, boolean>>
local MAX_ITEMS = 200 ---@type integer

---@param value                         string
---@return string
local function escape_literal(value)
  return (value:gsub("\\", "\\\\"):gsub("%$", "\\$"):gsub("}", "\\}"))
end

---@param size                          integer
---@return string
local function random_bytes(size)
  local bytes, err = vim.uv.random(size)
  if bytes == nil then
    error("Failed to generate snippet random bytes: " .. tostring(err), 0)
  end
  if #bytes ~= size then
    error(string.format("Snippet random source returned %d of %d bytes", #bytes, size), 0)
  end
  return bytes
end

---@param bytes                         string
---@return string
local function bytes_to_hex(bytes)
  local output = {} ---@type string[]
  for index = 1, #bytes do
    output[index] = string.format("%02x", bytes:byte(index))
  end
  return table.concat(output)
end

---@return string
local function uuid_v4()
  local bytes = random_bytes(16)
  local values = { bytes:byte(1, 16) } ---@type integer[]
  values[7] = 0x40 + values[7] % 0x10
  values[9] = 0x80 + values[9] % 0x40
  local hex = {} ---@type string[]
  for index, value in ipairs(values) do
    hex[index] = string.format("%02x", value)
  end
  local compact = table.concat(hex)
  return table.concat({
    compact:sub(1, 8),
    compact:sub(9, 12),
    compact:sub(13, 16),
    compact:sub(17, 20),
    compact:sub(21),
  }, "-")
end

---@return string
local function random_decimal()
  local bytes = random_bytes(4)
  local value = 0 ---@type integer
  for index = 1, #bytes do
    value = value * 0x100 + bytes:byte(index)
  end
  return string.format("%06d", value % 1000000)
end

---@return string
local function random_hex()
  return bytes_to_hex(random_bytes(3))
end

---@param timestamp                     integer
---@return string
local function timezone_offset(timestamp)
  local utc = os.date("!*t", timestamp)
  local local_time = os.date("*t", timestamp)
  if type(utc) ~= "table" or type(local_time) ~= "table" then
    error("Failed to resolve snippet timezone", 0)
  end
  local_time.isdst = false
  local difference = os.difftime(os.time(local_time), os.time(utc))
  local hours, fraction = math.modf(difference / 3600)
  local minutes = math.floor(math.abs(fraction) * 60 + 0.5)
  return string.format("%s%02d:%02d", difference < 0 and "-" or "+", math.abs(hours), minutes)
end

---@param context                       era.m.cmp.IContext
---@param filepath                      string
---@return string
---@return string
local function workspace_parts(context, filepath)
  local normalized_filepath = filepath ~= "" and dot.path.normalize(filepath, false) or "" ---@type string
  local workspace = nil ---@type string|nil
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = context.bufnr })) do
    for _, folder in ipairs(client.workspace_folders or {}) do
      local folderpath = type(folder.name) == "string" and folder.name or nil ---@type string|nil
      if type(folder.uri) == "string" then
        local ok, resolved = pcall(vim.uri_to_fname, folder.uri)
        if ok then
          folderpath = resolved
        end
      end
      if type(folderpath) == "string" and folderpath ~= "" then
        folderpath = dot.path.normalize(folderpath, false)
        if
          normalized_filepath ~= ""
          and (normalized_filepath == folderpath or yoz.path.is_descendant(folderpath, normalized_filepath))
          and (workspace == nil or #folderpath > #workspace)
        then
          workspace = folderpath
        end
      end
    end
  end

  workspace = workspace or (normalized_filepath ~= "" and dot.path.dirname(normalized_filepath) or dot.path.workspace())
  local relative = normalized_filepath ~= "" and dot.path.relative(workspace, normalized_filepath, "/") or ""
  return workspace, relative
end

---@param context                       era.m.cmp.IContext
---@return { line: string, block_start: string, block_end: string }
local function comment_parts(context)
  local parts = { line = "//", block_start = "/*", block_end = "*/" }
  local commentstring = vim.api.nvim_get_option_value("commentstring", { buf = context.bufnr }) ---@type string
  local before, after = commentstring:match("^(.-)%%s(.-)$")
  if before == nil then
    return parts
  end

  before = vim.trim(before)
  after = vim.trim(after)
  if after == "" then
    parts.line = before
  else
    parts.block_start = before
    parts.block_end = after
  end
  return parts
end

---@param value                         string
---@param replacements                  table<string, string|fun(): string>
---@return string
local function replacement_value(replacements, name)
  local replacement = replacements[name] ---@type string|fun(): string|nil
  if type(replacement) == "function" then
    return replacement()
  end
  return replacement
end

---@param value                         string
---@param index                         integer
---@return string|nil
---@return vim.snippet.VariableData|nil
---@return integer|nil
local function parse_braced_variable(value, index)
  if value:sub(index, index + 1) ~= "${" then
    return nil, nil, nil
  end
  local depth = 0 ---@type integer
  local escaped = false ---@type boolean
  for cursor = index + 2, #value do
    local char = value:sub(cursor, cursor) ---@type string
    if escaped then
      escaped = false
    elseif char == "\\" then
      escaped = true
    elseif char == "{" then
      depth = depth + 1
    elseif char == "}" then
      if depth > 0 then
        depth = depth - 1
      else
        local raw = value:sub(index, cursor) ---@type string
        local ok, parsed = pcall(vim.lsp._snippet_grammar.parse, raw)
        local children = ok and parsed.data.children or nil ---@type vim.snippet.Node<any>[]|nil
        local node = children and #children == 1 and children[1] or nil ---@type vim.snippet.Node<any>|nil
        if node ~= nil and node.type == vim.lsp._snippet_grammar.NodeType.Variable then
          return raw, node.data, cursor + 1
        end
        return nil, nil, nil
      end
    end
  end
  return nil, nil, nil
end

---@param value                         string
---@param modifier                     string
---@return string
local function apply_modifier(value, modifier)
  if modifier == "upcase" then
    return vim.fn.toupper(value) ---@type string
  end
  if modifier == "downcase" then
    return vim.fn.tolower(value) ---@type string
  end
  local first = vim.fn.strcharpart(value, 0, 1) ---@type string
  local rest = vim.fn.strcharpart(value, 1) ---@type string
  return vim.fn.toupper(first) .. vim.fn.tolower(rest)
end

---@param format                        vim.snippet.Node<vim.snippet.FormatData|vim.snippet.TextData>[]
---@param matches                       string[]
---@return string
local function render_transform(format, matches)
  local output = {} ---@type string[]
  for _, node in ipairs(format) do
    if node.type == vim.lsp._snippet_grammar.NodeType.Text then
      output[#output + 1] = type(node.data) == "table" and node.data.text or node.data
    elseif node.type == vim.lsp._snippet_grammar.NodeType.Format then
      local data = node.data ---@type vim.snippet.FormatData
      local capture = matches[data.capture + 1] or "" ---@type string
      if data.modifier ~= nil then
        output[#output + 1] = apply_modifier(capture, data.modifier)
      elseif data.if_text ~= nil and data.else_text ~= nil then
        output[#output + 1] = capture ~= "" and data.if_text or data.else_text
      elseif data.if_text ~= nil then
        output[#output + 1] = capture ~= "" and data.if_text or ""
      elseif data.else_text ~= nil then
        output[#output + 1] = capture ~= "" and capture or data.else_text
      else
        output[#output + 1] = capture
      end
    end
  end
  return table.concat(output)
end

---@param value                         string
---@param data                          vim.snippet.VariableData
---@return string|nil
local function apply_transform(value, data)
  if data.regex == nil or data.format == nil or (data.options or ""):find("[^gi]") ~= nil then
    return nil
  end
  local pattern = "\\v" .. data.regex:gsub("%(%?:", "%%("):gsub("\\/", "/") ---@type string
  local flags = (data.options or ""):find("g", 1, true) and "g" or "" ---@type string
  if (data.options or ""):find("i", 1, true) then
    flags = flags .. "i"
  end
  local ok, transformed = pcall(vim.fn.substitute, value, pattern, function(matches)
    return render_transform(data.format, matches)
  end, flags)
  return ok and transformed or nil
end

---@param value                         string
---@param replacements                  table<string, string|fun(): string>
---@return string
local function replace_variables(value, replacements)
  local output = {} ---@type string[]
  local index = 1 ---@type integer
  while index <= #value do
    local char = value:sub(index, index) ---@type string
    if char == "\\" and index < #value then
      output[#output + 1] = value:sub(index, index + 1)
      index = index + 2
    elseif char == "$" then
      local rest = value:sub(index) ---@type string
      local raw, data, next_index = parse_braced_variable(value, index)
      local name = data and data.name or nil ---@type string|nil
      if name ~= nil and replacements[name] ~= nil then
        local resolved = replacement_value(replacements, name) ---@type string|nil
        local transformed = resolved ~= nil and data.regex ~= nil and apply_transform(resolved, data) or nil ---@type string|nil
        if transformed ~= nil then
          output[#output + 1] = escape_literal(transformed)
        elseif data.regex ~= nil then
          output[#output + 1] = raw
        elseif resolved == "" and data.default ~= nil then
          local marker = "${" .. name .. ":" ---@type string
          output[#output + 1] = raw:sub(#marker + 1, -2)
        elseif resolved ~= nil then
          output[#output + 1] = escape_literal(resolved)
        else
          output[#output + 1] = raw
        end
        index = next_index
      else
        local plain_name, next_offset = rest:match("^%$([%u_][%u%d_]*)()")
        local resolved = plain_name and replacement_value(replacements, plain_name) or nil ---@type string|nil
        if resolved ~= nil then
          output[#output + 1] = escape_literal(resolved)
          index = index + next_offset - 1
        else
          output[#output + 1] = char
          index = index + 1
        end
      end
    else
      output[#output + 1] = char
      index = index + 1
    end
  end
  return table.concat(output)
end

local function read_json(filepath)
  return stl.fs.read_json({
    filepath = filepath,
    silent_on_bad_json = true,
    silent_on_bad_path = true,
  })
end

local function discover()
  if registry ~= nil then
    return registry
  end

  local discovered = {} ---@type table<string, string[]>
  local found = false ---@type boolean
  for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
    if yoz.path.basename(path) == "friendly-snippets" then
      found = true
      local package = read_json(dot.path.join(path, "package.json")) ---@type table|nil
      local definitions = vim.tbl_get(package or {}, "contributes", "snippets") or {} ---@type table[]
      for _, definition in ipairs(definitions) do
        local languages = type(definition.language) == "table" and definition.language or { definition.language }
        for _, language in ipairs(languages) do
          if type(language) == "string" then
            discovered[language] = discovered[language] or {}
            discovered[language][#discovered[language] + 1] = dot.path.join(path, definition.path)
          end
        end
      end
    end
  end
  if not found then
    return discovered
  end
  registry = discovered
  return registry
end

---@param body                          string
---@param context                       era.m.cmp.IContext
local function normalize_body(body, context)
  local value = type(body) == "table" and table.concat(body, "\n") or body ---@type string
  local filepath = vim.api.nvim_buf_get_name(context.bufnr) ---@type string
  local timestamp = nil ---@type integer|nil
  local workspace = nil ---@type string|nil
  local relative_filepath = nil ---@type string|nil
  local comments = nil ---@type { line: string, block_start: string, block_end: string }|nil

  ---@return integer
  local function get_timestamp()
    if timestamp == nil then
      timestamp = os.time()
    end
    return timestamp
  end

  ---@return string
  ---@return string
  local function get_workspace_parts()
    if workspace == nil then
      workspace, relative_filepath = workspace_parts(context, filepath)
    end
    return assert(workspace), assert(relative_filepath)
  end

  ---@return { line: string, block_start: string, block_end: string }
  local function get_comment_parts()
    if comments == nil then
      comments = comment_parts(context)
    end
    return comments
  end

  ---@return string
  local function get_register()
    local text = vim.fn.getreg(vim.v.register, true) ---@type any
    return type(text) == "string" and text or ""
  end

  ---@param format                      string
  ---@return fun(): string
  local function current_date(format)
    return function()
      return os.date(format, get_timestamp()) ---@type string
    end
  end

  local replacements = {
    TM_FILENAME = yoz.path.basename(filepath),
    TM_FILENAME_BASE = vim.fn.fnamemodify(filepath, ":t:r"),
    TM_DIRECTORY = dot.path.dirname(filepath),
    TM_FILEPATH = filepath,
    TM_SELECTED_TEXT = function()
      return vim.fn.trim(get_register(), "\n", 2)
    end,
    CLIPBOARD = get_register,
    RELATIVE_FILEPATH = function()
      local _, relative = get_workspace_parts()
      return relative
    end,
    WORKSPACE_FOLDER = function()
      local folder = get_workspace_parts()
      return folder
    end,
    WORKSPACE_NAME = function()
      local folder = get_workspace_parts()
      return yoz.path.basename(folder)
    end,
    TM_CURRENT_LINE = context.line,
    TM_CURRENT_WORD = context.keyword,
    TM_LINE_INDEX = tostring(context.row),
    TM_LINE_NUMBER = tostring(context.row + 1),
    CURRENT_YEAR = current_date("%Y"),
    CURRENT_YEAR_SHORT = current_date("%y"),
    CURRENT_MONTH = current_date("%m"),
    CURRENT_MONTH_NAME = current_date("%B"),
    CURRENT_MONTH_NAME_SHORT = current_date("%b"),
    CURRENT_DATE = current_date("%d"),
    CURRENT_DAY_NAME = current_date("%A"),
    CURRENT_DAY_NAME_SHORT = current_date("%a"),
    CURRENT_HOUR = current_date("%H"),
    CURRENT_MINUTE = current_date("%M"),
    CURRENT_SECOND = current_date("%S"),
    CURRENT_SECONDS_UNIX = function()
      return tostring(get_timestamp())
    end,
    CURRENT_TIMEZONE_OFFSET = function()
      return timezone_offset(get_timestamp())
    end,
    RANDOM = random_decimal,
    RANDOM_HEX = random_hex,
    UUID = uuid_v4,
    LINE_COMMENT = function()
      return get_comment_parts().line
    end,
    BLOCK_COMMENT_START = function()
      return get_comment_parts().block_start
    end,
    BLOCK_COMMENT_END = function()
      return get_comment_parts().block_end
    end,
  }
  return replace_variables(value, replacements)
end

local function load_filetype(filetype)
  if cache[filetype] ~= nil then
    return cache[filetype]
  end

  local snippets = {} ---@type era.m.cmp.source.snippets.ISnippet[]
  local files = {} ---@type string[]
  local seen_files = {} ---@type table<string, boolean>
  local discovered = discover()
  for _, language in ipairs({ "all", "global", filetype }) do
    for _, filepath in ipairs(discovered[language] or {}) do
      if not seen_files[filepath] then
        seen_files[filepath] = true
        files[#files + 1] = filepath
      end
    end
  end

  for _, filepath in ipairs(files) do
    local definitions = read_json(filepath) ---@type table|nil
    for name, definition in pairs(definitions or {}) do
      local prefixes = type(definition.prefix) == "table" and definition.prefix or { definition.prefix or name }
      for _, prefix in ipairs(prefixes) do
        if type(prefix) == "string" and (type(definition.body) == "string" or type(definition.body) == "table") then
          snippets[#snippets + 1] = {
            prefix = prefix,
            body = type(definition.body) == "table" and table.concat(definition.body, "\n") or definition.body,
            description = type(definition.description) == "string" and definition.description or nil,
          }
        end
      end
    end
  end
  cache[filetype] = snippets
  local candidates = {} ---@type yoz.cmp.IMatchItem[]
  for index, snippet in ipairs(snippets) do
    candidates[index] = {
      text = snippet.prefix,
      score_offset = 160,
      usage_key = table.concat({ "snippets", filetype, snippet.prefix }, "\0"),
    }
  end
  matcher_cache[filetype] = yoz.cmp.matcher(candidates)
  return snippets
end

---@param line                          string
---@param col                           integer
---@param prefix                        string
---@return integer|nil
local function prefix_start(line, col, prefix)
  local before = line:sub(1, col) ---@type string
  for length = math.min(#prefix, #before), 1, -1 do
    if before:sub(-length) == prefix:sub(1, length) then
      return col - length
    end
  end
end

---@param filetype                      string
---@return table<string, boolean>
function M.trigger_characters(filetype)
  if trigger_cache[filetype] ~= nil then
    return trigger_cache[filetype]
  end
  local characters = {} ---@type table<string, boolean>
  for _, snippet in ipairs(load_filetype(filetype)) do
    local char = vim.fn.strcharpart(snippet.prefix, 0, 1) ---@type string
    if char ~= "" then
      characters[char] = true
    end
  end
  trigger_cache[filetype] = characters
  return characters
end

---@param context                       era.m.cmp.IContext
---@param history                       yoz.cmp.IUsage|table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>|nil
---@return lsp.CompletionItem[]
function M.complete(context, history)
  local snippets = load_filetype(context.filetype)
  local query = context.keyword ---@type string
  if context.start_col > 0 then
    local before = context.line:sub(1, context.start_col) ---@type string
    local char_count = vim.fn.strchars(before) ---@type integer
    local char = char_count > 0 and vim.fn.strcharpart(before, char_count - 1, 1) or "" ---@type string
    if M.trigger_characters(context.filetype)[char] then
      query = char .. query
    end
  end

  local matched = assert(matcher_cache[context.filetype]):match(query, history, os.time(), MAX_ITEMS)
  local items = {} ---@type lsp.CompletionItem[]
  for _, result in ipairs(matched) do
    local snippet = snippets[result.index] ---@type era.m.cmp.source.snippets.ISnippet|nil
    if snippet ~= nil then
      local start_col = prefix_start(context.line, context.col, snippet.prefix) ---@type integer|nil
      if context.keyword ~= "" or start_col ~= nil then
        local item = util.item("snippets", 160, {
          label = snippet.prefix,
          kind = vim.lsp.protocol.CompletionItemKind.Snippet,
          filterText = snippet.prefix,
          detail = snippet.description,
          documentation = snippet.description and { kind = "plaintext", value = snippet.description } or nil,
          insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
          textEdit = {
            newText = normalize_body(snippet.body, context),
            range = util.range(context, start_col or context.start_col, context.end_col),
          },
        }, table.concat({ "snippets", context.filetype, snippet.prefix }, "\0"))
        local meta = assert(util.meta(item))
        meta.score = result.score
        meta.exact = result.exact
        items[#items + 1] = item
      end
    end
  end
  return items
end

function M.clear_cache()
  registry = nil
  cache = {}
  matcher_cache = {}
  trigger_cache = {}
end

return M
