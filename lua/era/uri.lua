---@class era.uri
local M = {}

---@param src                           string
---@return string
function M.decode(src)
  return (src:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

---@param src                           string
---@return string
function M.encode(src)
  return (src:gsub("([^%w%-_.~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

---@param src                           string
---@return boolean
function M.is_data_uri(src)
  return src:find("^data:") ~= nil
end

---@param value                         unknown
---@return integer|nil
local function normalize_index(value)
  local num = tonumber(value)
  return num ~= nil and math.max(math.floor(num), 1) or nil
end

---@param location                      era.t.ILocation
---@return string|nil label
---@return string|nil err
function M.file_location(location)
  if type(location) ~= "table" then
    return nil, "Location must be a table."
  end

  local filepath = era.path.normalize(location.filepath, false, "/")
  if type(filepath) ~= "string" or #vim.trim(filepath) == 0 then
    return nil, "Invalid filepath."
  end

  ---@type string
  local relpath = (
    yoz.path.is_absolute(filepath)
    and yoz.path.is_descendant(era.path.workspace(), filepath)
    and era.path.relative(era.path.cwd(), filepath, "/")
  ) or filepath

  local start_lnum = normalize_index(location.start_lnum)
  local start_col = normalize_index(location.start_col)
  local end_lnum = normalize_index(location.end_lnum)
  local end_col = normalize_index(location.end_col)

  local label = string.format("@%s", relpath)

  if start_lnum == nil then
    return label
  end

  local resolved_end_lnum = end_lnum or start_lnum ---@type integer
  local resolved_start_col = start_col or 1 ---@type integer
  local resolved_end_col = end_col or resolved_start_col ---@type integer
  local has_explicit_start_col = location.start_col ~= nil and start_col ~= nil ---@type boolean
  local has_explicit_end_col = location.end_col ~= nil and end_col ~= nil ---@type boolean

  label = label .. string.format(" :L%d", start_lnum)
  if has_explicit_start_col then
    label = label .. string.format(":C%d", resolved_start_col)
  end

  if resolved_end_lnum ~= start_lnum then
    label = label .. string.format("-L%d", resolved_end_lnum)
    local should_show_end_col = has_explicit_end_col
      or (has_explicit_start_col and resolved_end_col ~= resolved_start_col)
    if should_show_end_col then
      label = label .. string.format(":C%d", resolved_end_col)
    end
  elseif has_explicit_start_col and has_explicit_end_col and resolved_end_col ~= resolved_start_col then
    label = label .. string.format("-C%d", resolved_end_col)
  end

  return label
end

return M
