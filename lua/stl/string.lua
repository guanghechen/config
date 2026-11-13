-- stylua: ignore start
local BYTE_SLASH      = 0x2f ---@type integer '/'
local BYTE_BACKSLASH  = 0x5c ---@type integer '\\'
-- stylua: ignore end

---@param octal                         string
---@return string
local convert_octal_char = function(octal)
  return string.char(tonumber(octal, 8))
end

---@class stl.string
local M = {}

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
  return vim.split(text, "%s*,%s*", { trimempty = true })
end

---Splits `path[:lnum[:col[:col_end]]]`. The location is the integer suffix, so a drive letter or a colon in a file
---name stays in the path.
---@param text                          string
---@return string
---@return integer|nil
---@return integer|nil
---@return integer|nil
function M.parse_filepath_with_location(text)
  local filepath, lnum, col, col_end = text:match("^(.-):(%-?%d+):(%-?%d+):(%-?%d+)$")
  if filepath == nil then
    filepath, lnum, col = text:match("^(.-):(%-?%d+):(%-?%d+)$")
  end
  if filepath == nil then
    filepath, lnum = text:match("^(.-):(%-?%d+)$")
  end
  if filepath == nil or filepath == "" then
    return text, nil, nil, nil
  end
  return filepath, tonumber(lnum), tonumber(col), tonumber(col_end)
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

return M
