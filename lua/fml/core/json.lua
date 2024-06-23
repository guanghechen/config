---@class fml.core.json
local M = {}

---@param obj table
---@return boolean
local function check_if_array(obj)
  if #obj > 0 then
    return true
  end

  for key, _ in pairs(table) do
    if type(key) ~= "number" then
      return false
    end
  end

  return true
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
    local text = vim.json.encode(json):gsub("\\/", "/")
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
      if #json == 0 then
        lines[#lines] = last_line .. "[]"
        return
      end

      lines[#lines] = last_line .. "["
      for i = 1, #json do
        table.insert(lines, preceding_next)
        stringify_json_prettier(json[i], preceding_next, lines)
        if i < #json then
          lines[#lines] = lines[#lines] .. ","
        end
      end
      table.insert(lines, preceding .. "]")
      return
    else
      local keys = {}
      for key, _ in pairs(json) do
        table.insert(keys, key)
      end

      if #keys == 0 then
        lines[#lines] = last_line .. "{}"
        return
      end

      lines[#lines] = last_line .. "{"
      table.sort(keys)
      for i = 1, #keys do
        local key = keys[i]
        table.insert(lines, preceding_next .. vim.json.encode(key) .. ": ")
        stringify_json_prettier(json[key], preceding_next, lines)
        if i < #keys then
          lines[#lines] = lines[#lines] .. ","
        end
      end
      table.insert(lines, preceding .. "}")
      return
    end
  end

  ---invalid json type
  local text = vim.inspect(json)
  table.insert(lines, preceding .. text)
end

---@param json any
---@return string[]
function M.stringify_prettier_lines(json)
  local lines = { "" } ---@type string[]
  stringify_json_prettier(json, "", lines)
  return lines
end

---@param json any
---@return string
function M.stringify_prettier(json)
  local lines = { "" } ---@type string[]
  stringify_json_prettier(json, "", lines)
  return table.concat(lines, "\n")
end

function M.stringify(json)
  return vim.json.encode(json)
end

---@param json_text string
function M.parse(json_text)
  if json_text == nil then
    return
  end

  local ok_to_decode_json, data = pcall(vim.json.decode, json_text)
  if not ok_to_decode_json then
    vim.notify("[josn.parse] Failed to decode json.\n\n" .. json_text, vim.log.levels.WARN)
    return
  end

  return data
end

return M
