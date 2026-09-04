---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.highlight" ---@type string

---@class era.dressing.hipattern.highlight
local M = {}

local MAX_GROUPS = 10000 ---@type integer
local groups = {} ---@type table<string, string>
local group_count = 0 ---@type integer

---@param hex                           string
---@param hlgroup                       string
---@return boolean
local function apply(hex, hlgroup)
  return pcall(vim.api.nvim_set_hl, 0, hlgroup, { fg = hex })
end

---@param hex                           string|nil
---@return string|nil
function M.get_color_group(hex)
  if type(hex) ~= "string" or hex:match("^#%x%x%x%x%x%x$") == nil then
    return nil
  end

  hex = hex:lower()
  local existing = groups[hex]
  if existing ~= nil then
    return existing
  end
  if group_count >= MAX_GROUPS then
    return nil
  end

  local hlgroup = "EraHipatternColor_" .. hex:sub(2)
  if not apply(hex, hlgroup) then
    return nil
  end

  groups[hex] = hlgroup
  group_count = group_count + 1
  return hlgroup
end

---@return nil
function M.refresh()
  for hex, hlgroup in pairs(groups) do
    apply(hex, hlgroup)
  end
end

return M
