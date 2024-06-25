---@class ghc.ui.Theme : ghc.types.ui.ITheme
---@field private hlconfig_map          table<string, ghc.types.ui.theme.IHighlightConfig>
local M = {}
M.__index = M

---@param hlconfig                      ghc.types.ui.theme.IHighlightConfig
---@param scheme                        ghc.types.ui.theme.IScheme
---@return ghc.types.ui.theme.IHighlightGroup
function M.resolve_hlgroup(hlconfig, scheme)
  ---@diagnostic disable-next-line: assign-type-mismatch
  local hlgroup = vim.deepcopy(hlconfig) ---@type ghc.types.ui.theme.IHighlightGroup

  if hlconfig.fg ~= nil then
    hlgroup.fg = scheme.colors[hlconfig.fg] or hlconfig.fg
  end

  if hlconfig.bg ~= nil then
    hlgroup.bg = scheme.colors[hlconfig.bg] or hlconfig.bg
  end

  if hlconfig.sp ~= nil then
    hlgroup.sp = scheme.colors[hlconfig.sp] or hlconfig.sp
  end
  return hlgroup
end

---@return ghc.ui.Theme
function M.new()
  local self = setmetatable({}, M)
  self.hlconfig_map = {}
  return self
end

---@param params                        ghc.types.ui.theme.IApplyParams
---@return nil
function M:apply(params)
  local nsnr = params.nsnr ---@type integer
  local scheme = params.scheme ---@type ghc.types.ui.theme.IScheme
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = M.resolve_hlgroup(hlconfig, scheme)
    vim.api.nvim_set_hl(nsnr, hlname, hlgroup)
  end
end

---@param hlname                        string
---@param hlconfig                      ghc.types.ui.theme.IHighlightConfig
---@return ghc.ui.Theme
function M:register(hlname, hlconfig)
  self.hlconfig_map[hlname] = hlconfig
  return self
end

---@param hlconfig_map                  table<string, ghc.types.ui.theme.IHighlightConfig>
---@return ghc.ui.Theme
function M:registers(hlconfig_map)
  for hlname, hlconfig in pairs(hlconfig_map) do
    self.hlconfig_map[hlname] = hlconfig
  end
  return self
end

---@param scheme                        ghc.types.ui.theme.IScheme
---@return table<string, ghc.types.ui.theme.IHighlightGroup>
function M:resolve(scheme)
  local hlgroups = {} ---@type table<string, ghc.types.ui.theme.IHighlightGroup>
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = M.resolve_hlgroup(hlconfig, scheme) ---@type ghc.types.ui.theme.IHighlightGroup
    hlgroups[hlname] = hlgroup
  end
  return hlgroups
end

---@param params                        ghc.types.ui.theme.ICompileParams
---@return nil
function M:compile(params)
  local scheme = params.scheme ---@type ghc.types.ui.theme.IScheme
  local filepath = params.filepath ---@type string
  local nsnr = tostring(params.nsnr or 0) ---@type string

  local hlgroup_strs = {} ---@type string[]
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = M.resolve_hlgroup(hlconfig, scheme) ---@type ghc.types.ui.theme.IHighlightGroup
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

  local file = io.open(filepath, "wb")
  if file then
    file:write(loadstring(lines)())
    file:close()
  end
end

return M
