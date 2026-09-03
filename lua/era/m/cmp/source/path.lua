---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.source.path" ---@type string

local util = require("era.m.cmp.source.util")

local M = {}
local MAX_ENTRIES = 10000 ---@type integer
local SCAN_CHUNK_SIZE = 200 ---@type integer
---@type table<string, boolean>
local SHELL_FILETYPES = {
  bash = true,
  fish = true,
  nu = true,
  powershell = true,
  ps1 = true,
  sh = true,
  shell = true,
  zsh = true,
}
---@type table<string, table<string, boolean>>
local STRING_PREFIXES = {
  c = { l = true, lr = true, r = true, u = true, u8 = true, u8r = true, ur = true },
  cpp = { l = true, lr = true, r = true, u = true, u8 = true, u8r = true, ur = true },
  ["objective-c"] = { l = true, lr = true, r = true, u = true, u8 = true, u8r = true, ur = true },
  python = {
    b = true,
    br = true,
    f = true,
    fr = true,
    r = true,
    rb = true,
    rf = true,
    rt = true,
    t = true,
    tr = true,
    u = true,
  },
  rust = { b = true, br = true, c = true, cr = true, r = true },
  sql = { n = true },
}

---@param context                       era.m.cmp.IContext
---@return string
local function buffer_dirname(context)
  local filepath = vim.api.nvim_buf_get_name(context.bufnr) ---@type string
  return filepath == "" and dot.path.cwd() or dot.path.dirname(filepath)
end

---@param base_dirname                  string
---@param dirname_part                  string
---@return string|nil
local function resolve_dirname(base_dirname, dirname_part)
  if dirname_part == "" then
    return base_dirname
  end
  if dirname_part:sub(1, 1) == "~" then
    return vim.fn.expand(dirname_part)
  end
  if yoz.path.is_absolute(dirname_part) then
    return dirname_part
  end

  local env_name, relative = dirname_part:match("^%${([%w_]+)}[/\\](.*)$")
  if env_name == nil then
    env_name, relative = dirname_part:match("^%$([%w_]+)[/\\](.*)$")
  end
  if env_name ~= nil then
    local value = vim.env[env_name] ---@type string|nil
    return type(value) == "string" and value ~= "" and dot.path.resolve(value, relative) or nil
  end
  return dot.path.resolve(base_dirname, dirname_part)
end

---@param context                       era.m.cmp.IContext
---@param source                        string
---@param priority                      integer
---@param token                         string
---@param base_dirname                  string
---@param callback                      fun(items: lsp.CompletionItem[], err: string|nil): nil
---@return fun()
local function scan(context, source, priority, token, base_dirname, callback)
  local separator = token:match("^.*()[/\\]") ---@type integer|nil
  local dirname_part = separator and token:sub(1, separator) or "" ---@type string
  local query = separator and token:sub(separator + 1) or token ---@type string
  local dirname = resolve_dirname(base_dirname, dirname_part) ---@type string|nil
  if dirname == nil then
    callback({}, nil)
    return function() end
  end

  local replace_start = context.col - #query ---@type integer
  local suffix = context.line:sub(context.col + 1):match("^([^%s%(%){%}%[%]<>\"'`/\\]*)") or "" ---@type string
  local replace_end = context.col + #suffix ---@type integer
  local cancelled = false ---@type boolean
  local settled = false ---@type boolean

  local function finish(entries, err)
    if cancelled or settled then
      return
    end
    settled = true
    vim.schedule(function()
      if not cancelled then
        callback(entries, err)
      end
    end)
  end

  local request, start_err = vim.uv.fs_scandir(dirname, function(err, handle)
    if cancelled then
      return
    end
    if err ~= nil or handle == nil then
      local expected = type(err) == "string" and (err:find("ENOENT", 1, true) or err:find("ENOTDIR", 1, true))
      if expected then
        finish({}, nil)
      else
        finish({}, err)
      end
      return
    end

    local entries = {} ---@type lsp.CompletionItem[]
    local function process_chunk()
      if cancelled or settled then
        return
      end
      local ok, done_or_error = xpcall(function()
        local chunk = {} ---@type lsp.CompletionItem[]
        local done = false ---@type boolean
        for _ = 1, SCAN_CHUNK_SIZE do
          if #entries >= MAX_ENTRIES then
            done = true
            break
          end
          local name, kind = vim.uv.fs_scandir_next(handle)
          if name == nil then
            done = true
            break
          end
          local is_directory = kind == "directory" ---@type boolean
          local insert_text = name .. (is_directory and "/" or "") ---@type string
          local range_end = replace_end ---@type integer
          if is_directory and context.line:sub(range_end + 1, range_end + 1):match("[/\\]") then
            range_end = range_end + 1
          end
          chunk[#chunk + 1] = util.item(source, priority, {
            label = insert_text,
            kind = is_directory and vim.lsp.protocol.CompletionItemKind.Folder
              or vim.lsp.protocol.CompletionItemKind.File,
            sortText = (is_directory and "1" or "2") .. name:lower(),
            insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
            textEdit = {
              newText = insert_text,
              range = util.range(context, replace_start, range_end),
            },
          }, table.concat({ source, dirname, insert_text }, "\0"))
        end
        for _, item in ipairs(util.filter(query, chunk)) do
          if #entries >= MAX_ENTRIES then
            done = true
            break
          end
          entries[#entries + 1] = item
        end
        return done
      end, debug.traceback)
      if not ok then
        finish({}, done_or_error)
      elseif done_or_error then
        finish(util.filter(query, entries), nil)
      else
        vim.schedule(process_chunk)
      end
    end
    process_chunk()
  end)
  if request == nil then
    finish({}, start_err)
  end

  return function()
    if cancelled then
      return
    end
    cancelled = true
    if not settled and request ~= nil then
      pcall(request.cancel, request)
    end
  end
end

---@param context                       era.m.cmp.IContext
---@param callback                      fun(items: lsp.CompletionItem[], err: string|nil): nil
---@return fun()
function M.complete_at(context, callback)
  local before = context.line:sub(1, context.col) ---@type string
  local at_index, token = before:match("()@([^%s%(%){%}%[%]<>\"'`]*)$") ---@type integer|nil, string|nil
  if token == nil then
    callback({}, nil)
    return function() end
  end
  local prefix = before:sub(1, assert(at_index) - 1) ---@type string
  if prefix ~= "" and not prefix:sub(-1):match("[%s%(%[%{<,=\"'`]") then
    callback({}, nil)
    return function() end
  end
  return scan(context, "path_at", 210, token, dot.path.cwd(), callback)
end

---@param before                        string
---@param quote_index                   integer 1-indexed byte index
---@param filetype                      string
---@return boolean
local function can_open_quote(before, quote_index, filetype)
  local prefix_end = quote_index - 1 ---@type integer
  local prefix_start = yoz.cmp.keyword_range(before, prefix_end, false) ---@type integer
  local prefix = before:sub(prefix_start + 1, prefix_end):lower() ---@type string
  return prefix == "" or vim.tbl_get(STRING_PREFIXES, filetype, prefix) == true
end

---@param before                        string
---@param filetype                      string
---@return string|nil
local function quoted_token(before, filetype)
  local quote = nil ---@type string|nil
  local quote_start = nil ---@type integer|nil
  local backslashes = 0 ---@type integer
  for index = 1, #before do
    local char = before:sub(index, index) ---@type string
    if char == "\\" then
      backslashes = backslashes + 1
    else
      if (char == '"' or char == "'") and backslashes % 2 == 0 then
        if quote == nil then
          if can_open_quote(before, index, filetype) then
            quote = char
            quote_start = index
          end
        elseif quote == char then
          quote = nil
          quote_start = nil
        end
      end
      backslashes = 0
    end
  end
  return quote_start and before:sub(quote_start + 1) or nil
end

---@param before                        string
---@param token                         string
---@param quoted                        boolean
---@param plain                         boolean
---@param filetype                      string
---@return boolean
local function is_path_context(before, token, quoted, plain, filetype)
  if quoted or plain then
    return true
  end
  if token:match("^[%a][%w+.-]*://") or token:sub(1, 2) == "//" or token:sub(1, 2) == "/*" then
    return false
  end

  local prefix = before:sub(1, #before - #token) ---@type string
  if token:sub(1, 1) == "/" and prefix:sub(-1) == "<" then
    return false
  end
  if token:sub(1, 1) == "/" and prefix:match("%S%s+$") and not SHELL_FILETYPES[filetype] then
    return false
  end
  return true
end

---@param context                       era.m.cmp.IContext
---@param callback                      fun(items: lsp.CompletionItem[], err: string|nil): nil
---@return fun()
function M.complete(context, callback)
  local before = context.line:sub(1, context.col) ---@type string
  local token = quoted_token(before, context.filetype) ---@type string|nil
  local quoted = token ~= nil ---@type boolean
  token = token or before:match("([^%s%(%){%}%[%]<>\"'`]*)$")
  if token == nil or token == "" or token:sub(1, 1) == "@" then
    callback({}, nil)
    return function() end
  end
  local plain = context.filetype == stl.filetype.UX_PICKER_FINDER or context.filetype == stl.filetype.UX_SEARCHER_FINDER
  if not is_path_context(before, token, quoted, plain, context.filetype) then
    callback({}, nil)
    return function() end
  end
  if not plain and not quoted and not token:find("[/\\]") and token:sub(1, 1) ~= "." and token:sub(1, 1) ~= "~" then
    callback({}, nil)
    return function() end
  end
  local base_dirname = plain and dot.path.cwd() or buffer_dirname(context) ---@type string
  return scan(context, "path", 200, token, base_dirname, callback)
end

return M
