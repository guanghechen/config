---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.staging" ---@type string

---@class era.m.git.staging
local M = {}

---@type table<string, string>
local BOMS = {
  ["utf-8"] = "\239\187\191",
  ["utf-16le"] = "\255\254",
  ["ucs-2le"] = "\255\254",
  ["utf-16be"] = "\254\255",
  ["ucs-2be"] = "\254\255",
  ["utf-32le"] = "\255\254\000\000",
  ["utf-32be"] = "\000\000\254\255",
}

---@param encoding                      string|nil
---@return string
function M.normalize_encoding(encoding)
  if not encoding or encoding == "" then
    return "utf-8"
  end
  return encoding:lower()
end

---@param encoding                      string
---@return boolean
local function is_utf8(encoding)
  return encoding == "utf-8" or encoding == "utf8"
end

---@param fileformat                    string|nil
---@return string
function M.eol_from_fileformat(fileformat)
  return fileformat == "dos" and "\r\n" or "\n"
end

---@param text                          string
---@param default_eol                   string
---@return string
local function detect_eol(text, default_eol)
  local cr = 0 ---@type integer
  local lf = 0 ---@type integer
  local crlf = 0 ---@type integer
  local index = 1 ---@type integer

  while index <= #text do
    local byte = text:byte(index)
    if byte == 13 then
      if text:byte(index + 1) == 10 then
        crlf = crlf + 1
        index = index + 2
      else
        cr = cr + 1
        index = index + 1
      end
    elseif byte == 10 then
      lf = lf + 1
      index = index + 1
    else
      index = index + 1
    end
  end

  local total = cr + lf + crlf ---@type integer
  if total == 0 then
    return default_eol
  end
  return cr + crlf > total / 2 and "\r\n" or "\n"
end

---@param text                          string
---@param eol                           string
---@return string
local function normalize_eol(text, eol)
  local normalized = text:gsub("\r\n", "\n"):gsub("\r", "\n") ---@type string
  if eol == "\r\n" then
    normalized = normalized:gsub("\n", "\r\n")
  end
  return normalized
end

---@param text                          string
---@param opts                          { default_eol: string|nil, encoding: string|nil, bomb: boolean|nil }|nil
---@return era.m.git.Document
function M.from_text(text, opts)
  opts = opts or {}
  local default_eol = opts.default_eol or "\n" ---@type string
  local eol = detect_eol(text, default_eol) ---@type string
  local normalized = normalize_eol(text, eol) ---@type string
  local lines = vim.split(normalized, eol, { plain = true }) ---@type string[]

  return {
    bomb = opts.bomb == true,
    encoding = M.normalize_encoding(opts.encoding),
    eol = eol,
    lines = lines,
    text = normalized,
  }
end

---@param bytes                         string
---@param encoding                      string|nil
---@param default_eol                   string|nil
---@return era.m.git.Document|nil
---@return string|nil
function M.from_blob(bytes, encoding, default_eol)
  encoding = M.normalize_encoding(encoding)
  local bom = BOMS[encoding] ---@type string|nil
  local bomb = bom ~= nil and bytes:sub(1, #bom) == bom ---@type boolean
  if bomb then
    bytes = bytes:sub(#bom + 1)
  end

  local ok, text = true, bytes ---@type boolean, string|nil
  if not is_utf8(encoding) then
    ok, text = pcall(vim.iconv, bytes, encoding, "utf-8")
  end
  if not ok or type(text) ~= "string" then
    return nil, string.format("Failed to decode %s content", encoding)
  end

  return M.from_text(text, { bomb = bomb, default_eol = default_eol, encoding = encoding }), nil
end

---@param document                     era.m.git.Document
---@return string|nil
---@return string|nil
function M.encode(document)
  local encoding = M.normalize_encoding(document.encoding) ---@type string
  local ok, bytes = true, document.text ---@type boolean, string|nil
  if not is_utf8(encoding) then
    ok, bytes = pcall(vim.iconv, document.text, "utf-8", encoding)
  end
  if not ok or type(bytes) ~= "string" then
    return nil, string.format("Failed to encode %s content", encoding)
  end

  local bom = document.bomb and BOMS[encoding] or nil ---@type string|nil
  if bom and bytes:sub(1, #bom) ~= bom then
    bytes = bom .. bytes
  end
  return bytes, nil
end

---@param bufnr                         integer
---@return era.m.git.Document
function M.from_buffer(bufnr)
  local fileformat = vim.api.nvim_get_option_value("fileformat", { buf = bufnr }) ---@type string
  local eol = M.eol_from_fileformat(fileformat) ---@type string
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local text = table.concat(lines, eol) ---@type string
  local has_eol = vim.api.nvim_get_option_value("eol", { buf = bufnr }) ---@type boolean

  if has_eol then
    local is_empty = #lines == 1
      and lines[1] == ""
      and vim.api.nvim_buf_call(bufnr, function()
        return vim.fn.wordcount().bytes == 0
      end)
    if not is_empty then
      text = text .. eol
      lines[#lines + 1] = ""
    end
  end

  return {
    bomb = vim.api.nvim_get_option_value("bomb", { buf = bufnr }),
    encoding = M.normalize_encoding(vim.api.nvim_get_option_value("fileencoding", { buf = bufnr })),
    eol = eol,
    lines = lines,
    text = text,
  }
end

---@param document                     era.m.git.Document
---@return string[]
---@return boolean
local function content_lines(document)
  if document.text == "" then
    return {}, false
  end
  local has_final_eol = document.text:sub(-#document.eol) == document.eol ---@type boolean
  local lines = vim.deepcopy(document.lines) ---@type string[]
  if has_final_eol and lines[#lines] == "" then
    lines[#lines] = nil
  end
  return lines, has_final_eol
end

---@param original                      era.m.git.Document
---@param modified                      era.m.git.Document
---@param hunks                         era.m.git.Hunk[]
---@return string
function M.apply_line_changes(original, modified, hunks)
  if #hunks == 0 then
    return original.text
  end

  local original_lines, original_has_eol = content_lines(original) ---@type string[], boolean
  local modified_lines, modified_has_eol = content_lines(modified) ---@type string[], boolean
  local entries = {} ---@type { line: string, terminated: boolean, eol: string }[]
  local current_line = 1 ---@type integer

  ---@param line                        string
  ---@param terminated                  boolean
  ---@param eol                         string
  local function push(line, terminated, eol)
    entries[#entries + 1] = { line = line, terminated = terminated, eol = eol }
  end

  for _, hunk in ipairs(hunks) do
    if hunk.removed.count == 0 then
      for index = current_line, hunk.removed.start do
        push(original_lines[index], index < #original_lines or original_has_eol, original.eol)
      end
      current_line = math.max(current_line, hunk.removed.start + 1)
    else
      for index = current_line, hunk.removed.start - 1 do
        push(original_lines[index], index < #original_lines or original_has_eol, original.eol)
      end
      current_line = math.max(current_line, hunk.removed.start + hunk.removed.count)
    end

    for offset, line in ipairs(hunk.added.lines) do
      local index = hunk.added.start + offset - 1 ---@type integer
      push(line, index < #modified_lines or modified_has_eol, modified.eol)
    end
  end

  local ends_in_original = current_line <= #original_lines ---@type boolean
  for index = current_line, #original_lines do
    push(original_lines[index], index < #original_lines or original_has_eol, original.eol)
  end

  local last_hunk = hunks[#hunks] ---@type era.m.git.Hunk
  local reaches_modified_end ---@type boolean
  if last_hunk.added.count == 0 then
    reaches_modified_end = last_hunk.added.start >= #modified_lines
  else
    reaches_modified_end = last_hunk.added.start + last_hunk.added.count - 1 >= #modified_lines
  end
  local ends_in_modified = not ends_in_original and reaches_modified_end ---@type boolean
  local keeps_final_eol ---@type boolean
  local final_eol ---@type string
  if ends_in_modified then
    keeps_final_eol = modified_has_eol
    final_eol = modified.eol
  elseif not ends_in_original and last_hunk.added.count > 0 and #entries > 0 then
    keeps_final_eol = entries[#entries].terminated
    final_eol = entries[#entries].eol
  else
    keeps_final_eol = original_has_eol
    final_eol = original.eol
  end

  local result = {} ---@type string[]
  for index, entry in ipairs(entries) do
    result[#result + 1] = entry.line
    if index < #entries then
      local next_entry = entries[index + 1]
      result[#result + 1] = entry.terminated and entry.eol or next_entry.eol
    elseif keeps_final_eol then
      result[#result + 1] = entry.terminated and entry.eol or final_eol
    end
  end
  return table.concat(result)
end

---@param hunk                          era.m.git.Hunk
---@return integer
---@return integer
function M.modified_range(hunk)
  local start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
  local vend = hunk.added.count == 0 and start or (hunk.added.start + hunk.added.count - 1) ---@type integer
  return start, vend
end

---@param hunk                          era.m.git.Hunk
---@param top                           integer
---@param bot                           integer
---@return boolean
function M.touches(hunk, top, bot)
  local start, vend = M.modified_range(hunk) ---@type integer, integer
  return not (vend < top or start > bot)
end

---@param lines                         string[]
---@param offset                        integer
---@param count                         integer
---@return string[]
local function slice(lines, offset, count)
  local result = {} ---@type string[]
  for index = offset + 1, offset + count do
    result[#result + 1] = lines[index]
  end
  return result
end

---@param hunk                          era.m.git.Hunk
---@param top                           integer
---@param bot                           integer
---@return era.m.git.Hunk|nil
function M.intersect(hunk, top, bot)
  if not M.touches(hunk, top, bot) then
    return nil
  end
  if hunk.added.count == 0 then
    return vim.deepcopy(hunk)
  end

  local modified_start = math.max(hunk.added.start, top) ---@type integer
  local modified_end = math.min(hunk.added.start + hunk.added.count - 1, bot) ---@type integer
  local modified_count = modified_end - modified_start + 1 ---@type integer
  local modified_offset = modified_start - hunk.added.start ---@type integer
  local original_start = hunk.removed.start ---@type integer
  local original_count = hunk.removed.count ---@type integer
  local original_offset = 0 ---@type integer

  if hunk.removed.count == hunk.added.count then
    original_start = hunk.removed.start + modified_offset
    original_count = modified_count
    original_offset = modified_offset
  end

  local hunk_type = original_count == 0 and "add" or "change" ---@type era.m.git.HunkType
  return {
    type = hunk_type,
    head = string.format("@@ -%d,%d +%d,%d @@", original_start, original_count, modified_start, modified_count),
    added = {
      count = modified_count,
      lines = slice(hunk.added.lines, modified_offset, modified_count),
      no_nl_at_eof = modified_offset + modified_count >= hunk.added.count and hunk.added.no_nl_at_eof or nil,
      start = modified_start,
    },
    removed = {
      count = original_count,
      lines = slice(hunk.removed.lines, original_offset, original_count),
      no_nl_at_eof = original_offset + original_count >= hunk.removed.count and hunk.removed.no_nl_at_eof or nil,
      start = original_start,
    },
    vend = modified_start + modified_count - 1,
  }
end

---@param hunk                          era.m.git.Hunk
---@return era.m.git.Hunk
function M.invert(hunk)
  local removed = vim.deepcopy(hunk.added) ---@type era.m.git.HunkNode
  local added = vim.deepcopy(hunk.removed) ---@type era.m.git.HunkNode
  local hunk_type = removed.count == 0 and "add" or (added.count == 0 and "delete" or "change") ---@type era.m.git.HunkType
  return {
    type = hunk_type,
    head = string.format("@@ -%d,%d +%d,%d @@", removed.start, removed.count, added.start, added.count),
    added = added,
    removed = removed,
    vend = added.start + math.max(added.count, 1) - 1,
  }
end

---@param a                             era.m.git.Hunk
---@param b                             era.m.git.Hunk
---@return boolean
function M.less(a, b)
  if a.added.start ~= b.added.start then
    return a.added.start < b.added.start
  end
  if a.added.count ~= b.added.count then
    return a.added.count < b.added.count
  end
  if a.removed.start ~= b.removed.start then
    return a.removed.start < b.removed.start
  end
  return a.removed.count < b.removed.count
end

---@param bufnr                         integer
---@param text                          string
---@return nil
function M.replace_buffer_text(bufnr, text)
  local target_eol = M.eol_from_fileformat(vim.api.nvim_get_option_value("fileformat", { buf = bufnr })) ---@type string
  local document = M.from_text(text, { default_eol = target_eol }) ---@type era.m.git.Document
  local has_final_eol = text ~= "" and (text:sub(-1) == "\n" or text:sub(-1) == "\r") ---@type boolean
  local lines = vim.deepcopy(document.lines) ---@type string[]

  if has_final_eol and lines[#lines] == "" then
    lines[#lines] = nil
  end
  if #lines == 0 then
    lines[1] = ""
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("eol", has_final_eol, { buf = bufnr })
  vim.api.nvim_set_option_value("fixeol", has_final_eol, { buf = bufnr })
end

return M
