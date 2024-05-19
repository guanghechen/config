local ESCAPE_CHARMAP = {
  ["\\"] = [[\]],
  ['"'] = [[\"]],
  ["/"] = [[\/]],
  ["\b"] = [[\b]],
  ["\f"] = [[\f]],
  ["\n"] = [[\n]],
  ["\r"] = [[\r]],
  ["\t"] = [[\t]],
  ["\a"] = [[\u0007]],
  ["\v"] = [[\u000b]],
}

---@param s string
---@return string
local function escape_json_string(s)
  for k, v in pairs(ESCAPE_CHARMAP) do
    s = s:gsub(k, v)
  end
  return s
end

---@param obj table
---@return boolean
local function check_if_array(obj)
  local i = 1
  for _ in pairs(obj) do
    if obj[i] == nil then
      return false
    end
    i = i + 1
  end
  return i ~= 1
end

---@param json any
---@param preceding string
---@param lines string[]
---@return nil
local function stringify_json_prettier(json, preceding, lines)
  local t = type(json)
  local last_line = lines[#lines]

  if t == "number" then
    local text = tostring(json) ---@type string
    lines[#lines] = last_line .. text
    return
  end

  if t == "string" then
    local text = '"' .. escape_json_string(json) .. '"' ---@type string
    lines[#lines] = last_line .. text
    return
  end

  if t == "nil" then
    local text = "null" ---@type string
    lines[#lines] = last_line .. text
    return
  end

  if t == "boolean" then
    local text = json and "true" or "false" ---@type string
    lines[#lines] = last_line .. text
    return
  end

  if t == "table" then
    local preceding_next = preceding .. "  "
    if check_if_array(json) then
      lines[#lines] = last_line .. "["
      for i = 1, #json do
        table.insert(lines, preceding_next)
        stringify_json_prettier(json[i], preceding_next, lines)
        if i < #json then
          lines[#lines] = lines[#lines] .. ","
        end
      end
      table.insert(lines, preceding .. "]")
    else
      lines[#lines] = last_line .. "{"
      local keys = {}
      for key, _ in pairs(json) do
        table.insert(keys, key)
      end
      table.sort(keys)

      for i = 1, #keys do
        local key = keys[i]
        table.insert(lines, preceding_next .. '"' .. escape_json_string(key) .. '": ')
        stringify_json_prettier(json[key], preceding_next, lines)
        if i < #keys then
          lines[#lines] = lines[#lines] .. ","
        end
      end
      table.insert(lines, preceding .. "}")
    end
    return
  end

  ---invalid json type
  local text = vim.inspect(json)
  table.insert(lines, preceding .. text)
end

---@class guanghechen.util.json
local M = {}

---@param json any
---@return nil
function M.stringify_prettier(json)
  local lines = { "" } ---@type string[]
  stringify_json_prettier(json, "", lines)
  return table.concat(lines, "\n")
end

return M
