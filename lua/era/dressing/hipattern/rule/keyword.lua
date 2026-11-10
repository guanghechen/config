---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.rule.keyword" ---@type string

---@class era.dressing.hipattern.rule.keyword.ISpec
---@field public hlgroup                string
---@field public words                  string[]

---@type era.dressing.hipattern.rule.keyword.ISpec[]
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
}

local hlgroups = {} ---@type table<string, string>
for _, spec in ipairs(specs) do
  for _, word in ipairs(spec.words) do
    hlgroups[word] = spec.hlgroup
  end
end

---@class era.dressing.hipattern.rule.keyword : era.dressing.hipattern.rule.IModule
local M = {}

---@param line                          string
---@param _filetype                     string
---@return era.dressing.hipattern.IDecoration[]
---@diagnostic disable-next-line: unused-local
function M.match(line, _filetype)
  local decorations = {} ---@type era.dressing.hipattern.IDecoration[]
  -- A keyword stands alone between non-alphanumerics and is written in capitals: one pass finds such words, and a
  -- lookup tells which are keywords, where a scan per keyword read a long line once for each.
  for from, word, to in line:gmatch("%f[%w]()(%u+)()%f[%W]") do
    local hlgroup = hlgroups[word] ---@type string|nil
    if hlgroup ~= nil then
      decorations[#decorations + 1] = { kind = "highlight", coll = from - 1, colr = to - 1, hlgroup = hlgroup }
    end
  end
  return decorations
end

return M
