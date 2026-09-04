---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.rule.color" ---@type string

local color = require("stl.external.color")
local scan = require("era.dressing.hipattern.rule.scan")

local css_filetypes = {
  astro = true,
  css = true,
  html = true,
  javascriptreact = true,
  less = true,
  markdown = true,
  scss = true,
  svelte = true,
  typescriptreact = true,
  vue = true,
} ---@type table<string, true>

---@class era.dressing.hipattern.rule.color
local M = {}

---@param decorations                   era.dressing.hipattern.IDecoration[]
---@param match                         era.dressing.hipattern.rule.scan.IMatch
---@param hex                           string
---@return nil
local function append(decorations, match, hex)
  decorations[#decorations + 1] = {
    kind = "inline_color",
    coll = match.coll,
    colr = match.colr,
    color = hex,
  }
end

---@param line                          string
---@param filetype                      string
---@return era.dressing.hipattern.IDecoration[]
function M.match(line, filetype)
  local decorations = {} ---@type era.dressing.hipattern.IDecoration[]

  for _, match in ipairs(scan.collect(line, "#%x%x%x%x%x%x%f[%X]")) do
    append(decorations, match, match.full_match)
  end
  for _, match in ipairs(scan.collect(line, "#%x%x%x%f[^%x%w]")) do
    local value = match.full_match ---@type string
    local r, g, b = value:sub(2, 2), value:sub(3, 3), value:sub(4, 4)
    append(decorations, match, "#" .. r .. r .. g .. g .. b .. b)
  end

  if not css_filetypes[filetype] then
    return decorations
  end

  for _, match in ipairs(scan.collect(line, "rgba?%(%d+,%s*%d+,%s*%d+[^%)]*%)")) do
    local r, g, b = match.full_match:match("rgba?%((%d+),%s*(%d+),%s*(%d+)")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if r ~= nil and g ~= nil and b ~= nil and r <= 255 and g <= 255 and b <= 255 then
      append(decorations, match, color.rgb2hex(r, g, b))
    end
  end

  for _, match in ipairs(scan.collect(line, "hsla?%(%d+,%s*%d+%%,%s*%d+%%[^%)]*%)")) do
    local h, s, l = match.full_match:match("hsla?%((%d+),%s*(%d+)%%,%s*(%d+)%%")
    h, s, l = tonumber(h), tonumber(s), tonumber(l)
    if h ~= nil and s ~= nil and l ~= nil and s <= 100 and l <= 100 then
      append(decorations, match, color.hsl2hex(h % 360, s / 100, l / 100))
    end
  end

  return decorations
end

return M
