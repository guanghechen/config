---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.os.path" ---@type string

local OS_SEP = stl.env.PATH_SEP ---@type string

---@param filepath                      string
---@return boolean
local function is_uri_like(filepath)
  return filepath:match("^[%w+.-]+://") ~= nil
end

---@param filepath                      string
---@return boolean
local function detect_keep_trailing_slash(filepath)
  local last = filepath:sub(-1) ---@type string
  return last == "/" or last == "\\"
end

---@class stl.os.path
local M = {}

---@param filepath                      string
---@return boolean
function M.is_uri_like(filepath)
  if type(filepath) ~= "string" or filepath == "" then
    return false
  end
  return is_uri_like(filepath)
end

---@param filepath                      string
---@param keep_trailing_slash           ?boolean
---@return string
function M.normalize(filepath, keep_trailing_slash)
  if type(filepath) ~= "string" or filepath == "" then
    return ""
  end

  if is_uri_like(filepath) then
    return filepath
  end

  if keep_trailing_slash == nil then
    keep_trailing_slash = detect_keep_trailing_slash(filepath)
  end

  return yoz.canonical_path.normalize(filepath, keep_trailing_slash)
end

---@param filepath                      string
---@param keep_trailing_slash           ?boolean
---@return string
function M.to_os(filepath, keep_trailing_slash)
  if type(filepath) ~= "string" or filepath == "" then
    return ""
  end

  if is_uri_like(filepath) then
    return filepath
  end

  local normalized = M.normalize(filepath, keep_trailing_slash) ---@type string
  if normalized == "" then
    return ""
  end

  local keep = keep_trailing_slash
  if keep == nil then
    keep = normalized:sub(-1) == "/"
  end

  return yoz.path.normalize(normalized, keep, OS_SEP)
end

---@param os_path                       string
---@param keep_trailing_slash           ?boolean
---@return string
function M.from_os(os_path, keep_trailing_slash)
  if type(os_path) ~= "string" or os_path == "" then
    return ""
  end

  if is_uri_like(os_path) then
    return os_path
  end

  if keep_trailing_slash == nil then
    keep_trailing_slash = detect_keep_trailing_slash(os_path)
  end

  return yoz.canonical_path.normalize(os_path, keep_trailing_slash)
end

---@param from                          string
---@param to                            string
---@return string
function M.join(from, to)
  return yoz.canonical_path.join(from, to, true)
end

---@param from                          string
---@param to                            string
---@return string
function M.relative(from, to)
  return yoz.path.relative(from, to, false, "/")
end

---@param cwd                           string
---@param to                            string
---@return string
function M.resolve(cwd, to)
  return yoz.canonical_path.resolve(cwd, to, true)
end

---@param filepath                      string
---@return string
function M.dirname(filepath)
  return yoz.canonical_path.dirname(filepath, false)
end

return M
