---@class stl.c.theme.IApplyParams
---@field public scheme                 stl.t.theme.IScheme
---@field public nsnr                   integer

---@class stl.c.Theme
---@field protected hlgroup_map         table<string, stl.t.theme.IHlgroup>
local M = {}
M.__index = M

---@return stl.c.Theme
function M.new()
  local self = setmetatable({}, M)
  self.hlgroup_map = {}
  return self
end

---@param params                        stl.c.theme.IApplyParams
---@return nil
function M:apply(params)
  local nsnr = params.nsnr ---@type integer
  for hlname, hlgroup in pairs(self.hlgroup_map) do
    vim.api.nvim_set_hl(nsnr, hlname, hlgroup)
  end
end

---@param hlname                        string
---@param hlgroup                       stl.t.theme.IHlgroup
---@return stl.c.Theme
function M:register(hlname, hlgroup)
  self.hlgroup_map[hlname] = hlgroup
  return self
end

---@param hlgroup_map                   table<string, stl.t.theme.IHlgroup|nil>
---@return stl.c.Theme
function M:registers(hlgroup_map)
  for hlname, hlgroup in pairs(hlgroup_map) do
    if hlgroup ~= nil then
      self.hlgroup_map[hlname] = hlgroup
    end
  end
  return self
end

return M
