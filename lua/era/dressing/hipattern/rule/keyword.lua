---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.rule.keyword" ---@type string

local scan = require("era.dressing.hipattern.rule.scan")

---@class era.dressing.hipattern.rule.keyword.ISpec
---@field public hlgroup                string
---@field public words                  string[]

local specs = {
  {
    hlgroup = "f_hipattern_error",
    words = { "FIXME", "CAUTION", "FAILURE", "FAIL", "MISSING", "DANGER", "ERROR", "BUG" },
  },
  {
    hlgroup = "f_hipattern_warn",
    words = { "HACK", "WARN", "WARNING", "QUESTION", "HELP", "ATTENTION" },
  },
  { hlgroup = "f_hipattern_todo", words = { "TODO", "WIP" } },
  { hlgroup = "f_hipattern_info", words = { "NOTE", "ABSTRACT", "SUMMARY", "TLDR", "INFO" } },
  { hlgroup = "f_hipattern_success", words = { "TIP", "HINT", "SUCCESS", "CHECK", "DONE" } },
  { hlgroup = "f_hipattern_hint", words = { "IMPORTANT", "EXAMPLE" } },
  { hlgroup = "f_hipattern_quote", words = { "QUOTE", "CITE" } },
} ---@type era.dressing.hipattern.rule.keyword.ISpec[]

local patterns = {} ---@type { pattern: string, hlgroup: string }[]
for _, spec in ipairs(specs) do
  for _, word in ipairs(spec.words) do
    patterns[#patterns + 1] = { pattern = "%f[%w]()" .. word .. "()%f[%W]", hlgroup = spec.hlgroup }
  end
end

---@class era.dressing.hipattern.rule.keyword
local M = {}

---@param line                          string
---@param _filetype                     string
---@return era.dressing.hipattern.IDecoration[]
---@diagnostic disable-next-line: unused-local
function M.match(line, _filetype)
  local decorations = {} ---@type era.dressing.hipattern.IDecoration[]
  for _, spec in ipairs(patterns) do
    for _, match in ipairs(scan.collect(line, spec.pattern)) do
      decorations[#decorations + 1] = {
        kind = "highlight",
        coll = match.coll,
        colr = match.colr,
        hlgroup = spec.hlgroup,
      }
    end
  end
  return decorations
end

return M
