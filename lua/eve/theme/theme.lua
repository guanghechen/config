---@class eve.theme.IPalette
---@field public bg0                    string
---@field public bg1                    string
---@field public bg2                    string
---@field public bg3                    string
---@field public bg4                    string
---
---@field public fg0                    string
---@field public fg1                    string
---@field public fg2                    string
---@field public fg3                    string
---@field public fg4                    string
---
---@field public red                    string
---@field public green                  string
---@field public yellow                 string
---@field public blue                   string
---@field public purple                 string
---@field public aqua                   string
---@field public orange                 string
---
---@field public brightRed              string
---@field public brightGreen            string
---@field public brightYellow           string
---@field public brightBlue             string
---@field public brightPurple           string
---@field public brightAqua             string
---@field public brightOrange           string
---
---@field public grey                   string
---@field public pink                   string
---
---@field public diffDel                string
---@field public diffDelInline          string
---@field public diffAdd                string
---@field public diffAddInline          string

---@class eve.theme.IScheme
---@field public theme                  eve.e.Theme
---@field public variant                eve.e.ThemeVariant
---@field public palette                eve.theme.IPalette

---@class eve.theme.IHlgroup : vim.api.keyset.highlight

---@class eve.theme.IApplyParams
---@field public scheme                 eve.theme.IScheme
---@field public nsnr                   integer

---@class eve.theme.ICompileParams
---@field public scheme                 eve.theme.IScheme
---@field public filepath               string
---@field public nsnr                   integer

---@class eve.theme.ITheme
---@field public apply                  fun(self: eve.theme.ITheme, params: eve.theme.IApplyParams): nil
---@field public compile                fun(self: eve.theme.ITheme, params: eve.theme.ICompileParams): nil
---@field public register               fun(self: eve.theme.ITheme, hlname: string, hlgroup: eve.theme.IHlgroup): eve.theme.ITheme
---@field public registers              fun(self: eve.theme.ITheme, hlgroup_map: table<string, eve.theme.IHlgroup | nil>): eve.theme.ITheme

---@class eve.theme.Theme : eve.theme.ITheme
---@field public themes                 eve.e.Theme[]
---@field private hlgroup_map          table<string, eve.theme.IHlgroup>
local M = {}
M.__index = M

---@return eve.theme.Theme
function M.new()
  local self = setmetatable({}, M)
  self.hlgroup_map = {}
  return self
end

---@param params                        eve.theme.IApplyParams
---@return nil
function M:apply(params)
  local nsnr = params.nsnr ---@type integer
  for hlname, hlgroup in pairs(self.hlgroup_map) do
    vim.api.nvim_set_hl(nsnr, hlname, hlgroup)
  end
end

---@param hlname                        string
---@param hlgroup                       eve.theme.IHlgroup
---@return eve.theme.Theme
function M:register(hlname, hlgroup)
  self.hlgroup_map[hlname] = hlgroup
  return self
end

---@param hlgroup_map                   table<string, eve.theme.IHlgroup|nil>
---@return eve.theme.Theme
function M:registers(hlgroup_map)
  for hlname, hlgroup in pairs(hlgroup_map) do
    if hlgroup ~= nil then
      self.hlgroup_map[hlname] = hlgroup
    end
  end
  return self
end

---@param params                        eve.theme.ICompileParams
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

  local code = "return string.dump(function()\nlocal hls={"
    .. table.concat(hlgroup_strs, ",")
    .. "}\n"
    .. "for k, v in pairs(hls) do\n"
    .. "vim.api.nvim_set_hl("
    .. nsnr
    .. ",k,v)\n"
    .. "end\nend, true)\n"

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
