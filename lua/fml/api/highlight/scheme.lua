local resolve_hlgroup = require("fml.fn.resolve_hlgroup")

---@class fml.api.highlight.Scheme : fml.types.api.highlight.IScheme
---@field private hlconfig_map          table<string, fml.types.api.highlight.IHighlightConfig>
local M = {}
M.__index = M

---@return fml.api.highlight.Scheme
function M.new()
  local self = setmetatable({}, M)
  self.hlconfig_map = {}
  return self
end

---@param nsnr                          integer
---@param palette                       fml.types.api.highlight.IPalette
---@return nil
function M:apply(nsnr, palette)
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = resolve_hlgroup(hlconfig, palette)
    vim.api.nvim_set_hl(nsnr, hlname, hlgroup)
  end
end

---@param hlname                        string
---@param hlconfig                      fml.types.api.highlight.IHighlightConfig
---@return fml.api.highlight.Scheme
function M:register(hlname, hlconfig)
  self.hlconfig_map[hlname] = hlconfig
  return self
end

---@param palette                       fml.types.api.highlight.IPalette
---@return table<string, vim.api.keyset.highlight>
function M:resolve(palette)
  local hlgroups = {} ---@type table<string, vim.api.keyset.highlight>
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = resolve_hlgroup(hlconfig, palette) ---@type vim.api.keyset.highlight
    hlgroups[hlname] = hlgroup
  end
  return hlgroups
end

---@param params                        fml.types.api.highlight.ISchemeCompileParams
---@return nil
function M:compile(params)
  local palette = params.palette ---@type fml.types.api.highlight.IPalette
  local filepath = params.filepath ---@type string
  local nsnr = tostring(params.nsnr or 0) ---@type string

  local hlgroup_strs = {} ---@type string[]
  for hlname, hlconfig in pairs(self.hlconfig_map) do
    local hlgroup = resolve_hlgroup(hlconfig, palette) ---@type vim.api.keyset.highlight
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
