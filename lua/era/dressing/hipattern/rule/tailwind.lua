---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.rule.tailwind" ---@type string

local palette = require("stl.lang.tailwind").palette
local scan = require("era.dressing.hipattern.rule.scan")

local filetypes = {
  astro = true,
  css = true,
  heex = true,
  html = true,
  ["html-eex"] = true,
  javascript = true,
  javascriptreact = true,
  rust = true,
  svelte = true,
  typescript = true,
  typescriptreact = true,
  vue = true,
} ---@type table<string, true>

local pattern = "%f[%w:-][%w:-]+%-[a-z%-]+%-%d+%f[^%w:-]" ---@type string

---@class era.dressing.hipattern.rule.tailwind
local M = {}

---@param line                          string
---@param filetype                      string
---@return era.dressing.hipattern.IDecoration[]
function M.match(line, filetype)
  if not filetypes[filetype] then
    return {}
  end

  local decorations = {} ---@type era.dressing.hipattern.IDecoration[]
  for _, match in ipairs(scan.collect(line, pattern)) do
    local color_name, shade = match.full_match:match("[%w-]+%-([a-z%-]+)%-(%d+)")
    local shades = color_name and palette[color_name] or nil
    local hex = shades and shades[tonumber(shade)] or nil
    if hex ~= nil then
      decorations[#decorations + 1] = {
        kind = "inline_color",
        coll = match.coll,
        colr = match.colr,
        color = hex,
      }
    end
  end
  return decorations
end

return M
