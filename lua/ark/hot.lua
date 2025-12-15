---@class ark.hot
local M = {}

---@param modname                       string
---@return unknown
function M.reload(modname)
  package.loaded[modname] = nil
  return require(modname)
end

---@param modname                       string
---@param starts_with_only              boolean?
---@return string[]
function M.reload_module(modname, starts_with_only)
  if starts_with_only == nil then
    starts_with_only = true
  end

  local matcher ---@type fun(pack: string): boolean
  if starts_with_only then
    local pattern = "^" .. vim.pesc(modname)
    matcher = function(pack)
      return pack:find(pattern) ~= nil
    end
  else
    matcher = function(pack)
      return pack:find(modname, 1, true) ~= nil
    end
  end

  local reloaded = {} ---@type string[]
  for pack in pairs(package.loaded) do
    if matcher(pack) then
      package.loaded[pack] = nil
      reloaded[#reloaded + 1] = pack
    end
  end

  table.sort(reloaded)
  for _, pack in ipairs(reloaded) do
    pcall(require, pack)
  end
  return reloaded
end

---@param modname                       string
---@return boolean
function M.unload(modname)
  if package.loaded[modname] then
    package.loaded[modname] = nil
    return true
  end
  return false
end

---@param modname                       string
---@param starts_with_only              boolean?
---@return string[]
function M.unload_module(modname, starts_with_only)
  if starts_with_only == nil then
    starts_with_only = true
  end

  local matcher ---@type fun(pack: string): boolean
  if starts_with_only then
    local pattern = "^" .. vim.pesc(modname)
    matcher = function(pack)
      return pack:find(pattern) ~= nil
    end
  else
    matcher = function(pack)
      return pack:find(modname, 1, true) ~= nil
    end
  end

  local unloaded = {} ---@type string[]
  for pack in pairs(package.loaded) do
    if matcher(pack) then
      package.loaded[pack] = nil
      unloaded[#unloaded + 1] = pack
    end
  end

  table.sort(unloaded)
  return unloaded
end

---@param modname                       string
---@return boolean
function M.is_loaded(modname)
  return package.loaded[modname] ~= nil
end

return M
