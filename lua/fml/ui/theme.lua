local resolve_hlgroup = require("fml.fn.resolve_hlgroup")

---@class fml.ui.Theme : fml.types.ui.ITheme
---@field private hlconfig_map          table<string, fml.types.ui.theme.IHighlightConfig>
local M = {}
M.__index = M

---@return fml.ui.Theme
function M.new()
  local self = setmetatable({}, M)
  self.hlconfig_map = {}
  return self
end

---@param params                        fml.types.ui.theme.IApplyParams
---@return nil
function M:apply(params)
  local nsnr = params.nsnr ---@type integer
  local scheme = params.scheme ---@type fml.types.ui.theme.IScheme
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = resolve_hlgroup(hlconfig, scheme)
    vim.api.nvim_set_hl(nsnr, hlname, hlgroup)
  end
end

---@param hlname                        string
---@param hlconfig                      fml.types.ui.theme.IHighlightConfig
---@return fml.ui.Theme
function M:register(hlname, hlconfig)
  self.hlconfig_map[hlname] = hlconfig
  return self
end

---@param hlconfig_map                  table<string, fml.types.ui.theme.IHighlightConfig>
---@return fml.ui.Theme
function M:registers(hlconfig_map)
  for hlname, hlconfig in pairs(hlconfig_map) do
    self.hlconfig_map[hlname] = hlconfig
  end
  return self
end

---@param scheme                        fml.types.ui.theme.IScheme
---@return table<string, fml.types.ui.theme.IHighlightGroup>
function M:resolve(scheme)
  local hlgroups = {} ---@type table<string, fml.types.ui.theme.IHighlightGroup>
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = resolve_hlgroup(hlconfig, scheme) ---@type fml.types.ui.theme.IHighlightGroup
    hlgroups[hlname] = hlgroup
  end
  return hlgroups
end

---@param params                        fml.types.ui.theme.ICompileParams
---@return nil
function M:compile(params)
  local scheme = params.scheme ---@type fml.types.ui.theme.IScheme
  local filepath = params.filepath ---@type string
  local nsnr = tostring(params.nsnr or 0) ---@type string

  local hlgroup_strs = {} ---@type string[]
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = resolve_hlgroup(hlconfig, scheme) ---@type fml.types.ui.theme.IHighlightGroup
    local hlgroup_fields = {} ---@type string[]
    for key, value in pairs(hlgroup) do
      local value_type = type(value) ---@type string
      local value_stringified = (value_type == "boolean" or value_type == "number") and tostring(value)
        or '"' .. value .. '"'
      local field = key .. "=" .. value_stringified ---@type string
      table.insert(hlgroup_fields, field)
    end
    local hlgroup_str = hlname .. "={" .. table.concat(hlgroup_fields, ",") .. "}"
    table.insert(hlgroup_strs, hlgroup_str)
  end

  local lines = "return string.dump(function()\nlocal hls={"
    .. table.concat(hlgroup_strs, ",")
    .. "}\n"
    .. "for k, v in pairs(hls) do\n"
    .. "vim.api.nvim_set_hl("
    .. nsnr
    .. ",k,v)\n"
    .. "end\nend, true)\n"

  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":p:h"), "p")
  local file = io.open(filepath, "wb")
  if file then
    file:write(loadstring(lines)())
    file:close()
  end
end

return M
