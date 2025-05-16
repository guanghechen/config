---@class std.collection.theme.IApplyParams
---@field public scheme                 std.t.theme.IScheme
---@field public nsnr                   integer

---@class std.collection.theme.ICompileParams
---@field public scheme                 std.t.theme.IScheme
---@field public filepath               string
---@field public nsnr                   integer

---@class std.collection.theme.ITheme
---@field public apply                  fun(self: std.collection.theme.ITheme, params: std.collection.theme.IApplyParams): nil
---@field public compile                fun(self: std.collection.theme.ITheme, params: std.collection.theme.ICompileParams): nil
---@field public register               fun(self: std.collection.theme.ITheme, hlname: string, hlgroup: std.t.theme.IHlgroup): std.collection.theme.ITheme
---@field public registers              fun(self: std.collection.theme.ITheme, hlgroup_map: table<string, std.t.theme.IHlgroup | nil>): std.collection.theme.ITheme

---@class std.collection.Theme : std.collection.theme.ITheme
---@field private hlgroup_map           table<string, std.t.theme.IHlgroup>
local M = {}
M.__index = M

---@return std.collection.Theme
function M.new()
  local self = setmetatable({}, M)
  self.hlgroup_map = {}
  return self
end

---@param params                        std.collection.theme.IApplyParams
---@return nil
function M:apply(params)
  local nsnr = params.nsnr ---@type integer
  for hlname, hlgroup in pairs(self.hlgroup_map) do
    vim.api.nvim_set_hl(nsnr, hlname, hlgroup)
  end
end

---@param hlname                        string
---@param hlgroup                       std.t.theme.IHlgroup
---@return std.collection.Theme
function M:register(hlname, hlgroup)
  self.hlgroup_map[hlname] = hlgroup
  return self
end

---@param hlgroup_map                   table<string, std.t.theme.IHlgroup|nil>
---@return std.collection.Theme
function M:registers(hlgroup_map)
  for hlname, hlgroup in pairs(hlgroup_map) do
    if hlgroup ~= nil then
      self.hlgroup_map[hlname] = hlgroup
    end
  end
  return self
end

---@param params                        std.collection.theme.ICompileParams
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

    local hlname_stringified = string.sub(hlname, 1, 1) == "@" and '["' .. hlname .. '"]' or hlname
    local hlgroup_str = hlname_stringified .. "={" .. table.concat(hlgroup_fields, ",") .. "}"
    table.insert(hlgroup_strs, hlgroup_str)
  end

  local code = string.format(
    "return string.dump(function()\nlocal hls={%s}\n"
      .. "for k, v in pairs(hls) do\n"
      .. "vim.api.nvim_set_hl(%s,k,v)\n"
      .. "end\nend, true)\n",
    table.concat(hlgroup_strs, ","),
    nsnr
  )

  local dirpath = vim.fn.fnamemodify(filepath, ":p:h") ---@type string
  local dirpath_stat = vim.uv.fs_stat(filepath)
  if dirpath_stat == nil or vim.tbl_isempty(dirpath_stat) then
    vim.fn.mkdir(dirpath, "p")
  end

  local file = io.open(filepath, "wb")
  if file then
    file:write(loadstring(code)())
    file:close()
  end
end

return M
