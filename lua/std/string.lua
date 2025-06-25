-- stylua: ignore start
local BYTE_SLASH      = std.byte.BYTES.SLASH      ---@type integer '/'
local BYTE_BACKSLASH  = std.byte.BYTES.BACKSLASH  ---@type integer '\\'
-- stylua: ignore end

---@param octal                          string
---@return string
local convert_octal_char = function(octal)
  return string.char(tonumber(octal, 8))
end

---@class std.string
local M = {}

---@param text                          string
---@return string
function M.escape_url_component(text)
  return (text:gsub("([^%w%.%-])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

---@param text                          string
---@return string
function M.octal_to_utf8(text)
  local success, converted = pcall(string.gsub, text, "\\([0-7][0-7][0-7])", convert_octal_char)
  if success then
    return converted
  end
  return text
end

---@param text                          string
---@param width                         integer
---@param pad                           string
---@return string
function M.pad_end(text, width, pad)
  local delta = width - vim.api.nvim_strwidth(text) ---@type integer
  return delta <= 0 and text or (text .. string.rep(pad, delta))
end

---@param text                          string
---@param width                         integer
---@param pad                           string
---@return string
function M.pad_start(text, width, pad)
  local delta = width - vim.api.nvim_strwidth(text) ---@type integer
  return delta <= 0 and text or (string.rep(pad, delta) .. text)
end

---@param text                          string
---@return string[]
function M.parse_comma_list(text)
  local result = {} ---@type string[]
  local items = vim.split(text, ",", { plain = true })
  for _, item in ipairs(items) do
    local v = item:match("^%s*(.-)%s*$")
    if #v > 0 then
      table.insert(result, v)
    end
  end
  return result
end

---@param text                          string
---@return string
---@return integer|nil
---@return integer|nil
---@return integer|nil
function M.parse_filepath_with_location(text)
  local pieces = vim.split(text, ":", { plain = true })
  local filepath = pieces[1] ---@type string
  local lnum = pieces[2] ~= nil and tonumber(pieces[2]) or nil ---@type integer|nil
  local col = pieces[3] ~= nil and tonumber(pieces[3]) or nil ---@type integer|nil
  local col_end = pieces[4] ~= nil and tonumber(pieces[4]) or nil ---@type integer|nil
  return filepath, lnum, col, col_end
end

---@param text                          string
---@return string
function M.remove_last_slash(text)
  if #text > 1 then
    local last_byte = string.byte(text, #text, #text)
    if last_byte == BYTE_SLASH or last_byte == BYTE_BACKSLASH then
      return string.sub(text, 1, #text - 1)
    end
  end
  return text
end

---@param text                          string
---@param word                          string
---@return boolean
function M.starts_with(text, word)
  return #text >= #word and string.sub(text, 1, #word) == word
end

return M
