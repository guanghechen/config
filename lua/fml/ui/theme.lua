---@class fml.ui.Theme : fml.types.ui.ITheme
---@field private hlgroup_map          table<string, fml.types.ui.theme.IHighlightGroup>
local M = {}
M.__index = M

---@return fml.ui.Theme
function M.new()
  local self = setmetatable({}, M)
  self.hlgroup_map = {}
  return self
end

---@param params                        fml.types.ui.theme.IApplyParams
---@return nil
function M:apply(params)
  local nsnr = params.nsnr ---@type integer
  for hlname, hlgroup in pairs(self.hlgroup_map) do
    vim.api.nvim_set_hl(nsnr, hlname, hlgroup)
  end
end

---@param hlname                        string
---@param hlgroup                       fml.types.ui.theme.IHighlightGroup
---@return fml.ui.Theme
function M:register(hlname, hlgroup)
  self.hlgroup_map[hlname] = hlgroup
  return self
end

---@param hlgroup_map                   table<string, fml.types.ui.theme.IHighlightGroup|nil>
---@return fml.ui.Theme
function M:registers(hlgroup_map)
  for hlname, hlgroup in pairs(hlgroup_map) do
    if hlgroup ~= nil then
      self.hlgroup_map[hlname] = hlgroup
    end
  end
  return self
end

---@param params                        fml.types.ui.theme.ICompileParams
---@return nil
function M:compile(params)
  local filepath = params.filepath ---@type string
  local nsnr = tostring(params.nsnr or 0) ---@type string

  local hlgroup_strs = {} ---@type string[]
  for hlname, hlgroup in pairs(self.hlgroup_map) do
    local hlgroup_fields = {} ---@type string[]
    for key, value in pairs(hlgroup) do
      local value_type = type(value) ---@type string
      local value_stringified = (value_type == "boolean" or value_type == "number") and tostring(value)
        or '"' .. value .. '"'
      local field = key .. "=" .. value_stringified ---@type string
      table.insert(hlgroup_fields, field)
    end

    local hlname_stringified = string.sub(hlname, 1, 1) == '@' and '["' .. hlname .. '"]' or hlname
    local hlgroup_str = hlname_stringified .. "={" .. table.concat(hlgroup_fields, ",") .. "}"
    table.insert(hlgroup_strs, hlgroup_str)
  end

  local code = "return string.dump(function()\nlocal hls={"
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
    file:write(loadstring(code)())
    file:close()
  end
end

return M
