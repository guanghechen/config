local SINGLE_COMMENT = 1
local MULTI_COMMENT = 2

---@param str                           string
---@param from                          ?integer
---@param to                            ?integer
---@return string
local function slice(str, from, to)
  return str:sub(from or 1, to or #str)
end

---@param str                           string
---@param from                          ?integer
---@param to                            ?integer
---@return string
local function strip_with_whitespace(str, from, to)
  local result = slice(str, from, to):gsub("%S", " ")
  return result
end

---@param json_string                   string
---@param quote_position                integer
---@return boolean
local function is_escaped(json_string, quote_position)
  local index = quote_position - 1
  local backslash_count = 0
  while json_string:sub(index, index) == "\\" do
    index = index - 1
    backslash_count = backslash_count + 1
  end
  return backslash_count % 2 == 1
end

---@class stl.json
local M = {}

---@param json_string                   string
---@return string
function M.strip_comments(json_string)
  local inside_string = false
  local inside_comment = nil ---@type integer|nil
  local offset = 1
  local result = ""
  local skip = false
  local last_comma = 0

  for i = 1, #json_string do
    if skip then
      skip = false
    else
      local cur = json_string:sub(i, i)
      local next = json_string:sub(i + 1, i + 1)

      if not inside_comment and cur == '"' and not is_escaped(json_string, i) then
        inside_string = not inside_string
      end

      if not inside_string then
        if not inside_comment and cur .. next == "//" then
          result = result .. slice(json_string, offset, i - 1)
          offset = i
          inside_comment = SINGLE_COMMENT
          skip = true
        elseif inside_comment == SINGLE_COMMENT and cur .. next == "\r\n" then
          skip = true
          inside_comment = nil
          result = result .. strip_with_whitespace(json_string, offset, i)
          offset = i + 1
        elseif inside_comment == SINGLE_COMMENT and cur == "\n" then
          inside_comment = nil
          result = result .. strip_with_whitespace(json_string, offset, i - 1)
          offset = i
        elseif not inside_comment and cur .. next == "/*" then
          result = result .. slice(json_string, offset, i - 1)
          offset = i
          inside_comment = MULTI_COMMENT
          skip = true
        elseif inside_comment == MULTI_COMMENT and cur .. next == "*/" then
          skip = true
          inside_comment = nil
          result = result .. strip_with_whitespace(json_string, offset, i + 1)
          offset = i + 2
        elseif not inside_comment then
          if cur == "," then
            last_comma = i
          elseif (cur == "]" or cur == "}") and last_comma > 0 then
            result = result .. slice(json_string, offset, last_comma - 1) .. slice(json_string, last_comma + 1, i)
            offset = i + 1
            last_comma = 0
          elseif cur:match("%S") then
            last_comma = 0
          end
        end
      end
    end
  end

  if inside_comment then
    return result .. strip_with_whitespace(json_string, offset)
  end
  return result .. slice(json_string, offset)
end

---@param json_string                   string
---@param opts                          ?table
---@return any
function M.decode(json_string, opts)
  local stripped = M.strip_comments(json_string)
  return vim.json.decode(stripped, opts)
end

return M
