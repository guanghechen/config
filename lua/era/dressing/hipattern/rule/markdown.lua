---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.rule.markdown" ---@type string

local scan = require("era.dressing.hipattern.rule.scan")

local filetypes = {
  ["image-viewer"] = true,
  markdown = true,
  notepad = true,
} ---@type table<string, true>

---@class era.dressing.hipattern.rule.markdown
local M = {}

---@param line                          string
---@param filetype                      string
---@return era.dressing.hipattern.IDecoration[]
function M.match(line, filetype)
  if not filetypes[filetype] then
    return {}
  end

  local decorations = {} ---@type era.dressing.hipattern.IDecoration[]
  for _, match in ipairs(scan.collect(line, "^%-%-%-()[^%-\n].+[^%-]()%-%-%-$")) do
    decorations[#decorations + 1] = {
      kind = "highlight",
      coll = match.coll,
      colr = match.colr,
      hlgroup = "f_md_titled_separator",
    }
  end
  return decorations
end

return M
