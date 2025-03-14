---@class eve.builtin.string
local M = {}

---@param text                          string
---@return string
function M.escape_url_component(text)
  return (text:gsub("([^%w%.%-])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
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
function M.remove_last_slash(text)
  if #text > 1 then
    local last_character = string.sub(text, -1, -1)
    if last_character == "/" or last_character == "\\" then
      return string.sub(text, 1, -2)
    end
  end
  return text
end

---@param text                          string
---@param word                          string
---@return boolean
function M.starts_with(text, word)
  return #text >= #word and text:sub(1, #word) == word
end

return M