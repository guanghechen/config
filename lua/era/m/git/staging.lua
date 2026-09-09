---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.staging" ---@type string

local native = require("yoz").git.staging

---@class era.m.git.staging
local M = {}

M.normalize_encoding = native.normalize_encoding

---@param fileformat                    ?string
---@return string
function M.eol_from_fileformat(fileformat)
  return fileformat == "dos" and "\r\n" or "\n"
end

---@param text                          string
---@param opts                          ?{ default_eol: string|nil, encoding: string|nil, bomb: boolean|nil }
---@return era.m.git.Document
function M.from_text(text, opts)
  opts = opts or {}
  local document = native.from_text(text, opts.default_eol)
  ---@cast document era.m.git.Document
  document.bomb = opts.bomb == true
  document.encoding = M.normalize_encoding(opts.encoding)
  return document
end

---@param bytes                         string
---@param encoding                      ?string
---@param default_eol                   ?string
---@return era.m.git.Document|nil
---@return string|nil
function M.from_blob(bytes, encoding, default_eol)
  encoding = M.normalize_encoding(encoding)
  local text, bomb, err = native.decode_unicode(bytes, encoding)
  if err then
    return nil, string.format("Failed to decode %s content: %s", encoding, err)
  end
  if text == nil then
    local ok, converted = pcall(vim.iconv, bytes, encoding, "utf-8")
    if not ok or type(converted) ~= "string" then
      return nil, string.format("Failed to decode %s content", encoding)
    end
    text = converted
  end

  return M.from_text(text, { bomb = bomb, default_eol = default_eol, encoding = encoding }), nil
end

---@param document                      era.m.git.Document
---@return string|nil
---@return string|nil
function M.encode(document)
  local encoding = M.normalize_encoding(document.encoding) ---@type string
  local bytes, err = native.encode_unicode(document.text, encoding, document.bomb == true)
  if err then
    return nil, string.format("Failed to encode %s content: %s", encoding, err)
  end
  if bytes == nil then
    local ok, converted = pcall(vim.iconv, document.text, "utf-8", encoding)
    if not ok or type(converted) ~= "string" then
      return nil, string.format("Failed to encode %s content", encoding)
    end
    bytes = converted
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

M.apply_line_changes = native.apply_line_changes
M.apply_selection = native.apply_selection
M.modified_range = native.modified_range
M.touches = native.touches
M.intersect = native.intersect
M.invert = native.invert
M.less = native.less

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
