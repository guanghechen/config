---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.filetree.path" ---@type string

local env = require("stl.env")
local M = {}

-- Filetree paths use '/' exclusively. Unix backslashes remain filename bytes.
---@param path                          string
---@return string
function M.from_os(path)
  return env.IS_WIN and (path:gsub("\\", "/")) or path
end

---@param path                          string
---@return string
function M.to_os(path)
  return env.IS_WIN and (path:gsub("/", "\\")) or path
end

---@param path                          string
---@return string
local function root(path)
  if env.IS_WIN then
    local prefix = path:match("^(//%?/UNC/[^/]+/[^/]+)")
      or path:match("^(//%?/%a:/)")
      or path:match("^(//[^/]+/[^/]+)")
      or path:match("^(%a:/)")
    if prefix then
      return prefix
    end
  end
  return path:sub(1, 1) == "/" and "/" or ""
end

---@param path                          string
---@return string
function M.trim(path)
  local prefix = root(path)
  return #path > #prefix and path:sub(1, #prefix) .. path:sub(#prefix + 1):gsub("/+$", "") or path
end

---@param path                          string
---@return string
function M.basename(path)
  path = M.trim(path)
  return path:sub(#root(path) + 1):match("[^/]+$") or ""
end

---@param path                          string
---@return string
function M.dirname(path)
  path = M.trim(path)
  local prefix = root(path)
  if #path <= #prefix then
    return path
  end
  local parent = path:match("^(.*)/[^/]+$")
  return parent and (#parent < #prefix and prefix or parent) or "."
end

---@param cwd                           string
---@param path                          string
---@return string
function M.resolve(cwd, path)
  if root(path) ~= "" then
    -- Windows rooted paths inherit the current volume; fully qualified paths retain their prefix.
    if env.IS_WIN and root(path) == "/" then
      return root(cwd):gsub("/+$", "") .. path
    end
    return path
  end
  if env.IS_WIN and path:match("^%a:") then
    error("Use an absolute drive path, such as C:/path", 0)
  end
  if path == "" or path == "." then
    return cwd
  end
  return cwd .. (cwd:sub(-1) == "/" and "" or "/") .. path
end

---@param from                          string
---@param to                            string
---@return string
function M.relative(from, to)
  from, to = M.trim(from), M.trim(to)
  local prefix = root(from)
  if prefix ~= root(to) then
    return to
  end
  local left, right = {}, {}
  for piece in from:sub(#prefix + 1):gmatch("[^/]+") do
    left[#left + 1] = piece
  end
  for piece in to:sub(#prefix + 1):gmatch("[^/]+") do
    right[#right + 1] = piece
  end
  local common = 0
  while left[common + 1] and left[common + 1] == right[common + 1] do
    common = common + 1
  end
  local parts = {}
  for _ = common + 1, #left do
    parts[#parts + 1] = ".."
  end
  for index = common + 1, #right do
    parts[#parts + 1] = right[index]
  end
  return #parts == 0 and "." or table.concat(parts, "/")
end

---@param path                          string
---@return string
function M.extname(path)
  local name = M.basename(path)
  return name:match("^.+(%.[^.]*)$") or ""
end

return M
