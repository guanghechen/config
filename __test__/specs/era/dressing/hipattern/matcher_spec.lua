local harness = require("__test__.support.harness")

local t = harness.new()
local matcher = require("era.dressing.hipattern.matcher")

---@param decorations                   era.dressing.hipattern.IDecoration[]
---@param kind                          "highlight"|"inline_color"
---@param coll                          integer
---@return era.dressing.hipattern.IDecoration|nil
local function get_decoration(decorations, kind, coll)
  for _, decoration in ipairs(decorations) do
    if decoration.kind == kind and decoration.coll == coll then
      return decoration
    end
  end
  return nil
end

t:test("matches standalone keywords only", function()
  local decorations = matcher.match("TODO TODO1 ERROR", "lua")
  t.assert_eq(2, #decorations, "keyword count")

  local todo = get_decoration(decorations, "highlight", 0)
  local err = get_decoration(decorations, "highlight", 11)
  t.assert_eq("f_hipattern_todo", todo and todo.hlgroup, "todo group")
  t.assert_eq(4, todo and todo.colr, "todo range")
  t.assert_eq("f_hipattern_error", err and err.hlgroup, "error group")
end)

t:test("keywords decorate exactly what one scan per keyword found", function()
  local keyword = require("era.dressing.hipattern.rule.keyword")
  local scan = require("era.dressing.hipattern.rule.scan")
  ---@type table<string, string[]>
  local specs = {
    f_hipattern_error = { "FIXME", "CAUTION", "FAILURE", "FAIL", "MISSING", "DANGER", "ERROR", "BUG" },
    f_hipattern_warn = { "HACK", "WARN", "WARNING", "QUESTION", "HELP", "ATTENTION" },
    f_hipattern_todo = { "TODO", "WIP" },
    f_hipattern_info = { "NOTE", "ABSTRACT", "SUMMARY", "TLDR", "INFO" },
    f_hipattern_success = { "TIP", "HINT", "SUCCESS", "CHECK", "DONE" },
    f_hipattern_hint = { "IMPORTANT", "EXAMPLE" },
    f_hipattern_quote = { "QUOTE", "CITE" },
  }
  local groups = {} ---@type table<string, string>
  for hlgroup, words in pairs(specs) do
    for _, word in ipairs(words) do
      groups[word] = hlgroup
    end
  end
  ---@param decorations                 { coll: integer, colr: integer, hlgroup: string }[]
  ---@return string[]
  local function keys(decorations)
    local out = {} ---@type string[]
    for _, d in ipairs(decorations) do
      out[#out + 1] = string.format("%d:%d:%s", d.coll, d.colr, d.hlgroup)
    end
    table.sort(out)
    return out
  end
  ---@param line                        string
  ---@return string[]
  local function reference(line)
    local decorations = {} ---@type { coll: integer, colr: integer, hlgroup: string }[]
    for word, hlgroup in pairs(groups) do
      for _, match in ipairs(scan.collect(line, "%f[%w]()" .. word .. "()%f[%W]")) do
        decorations[#decorations + 1] = { coll = match.coll, colr = match.colr, hlgroup = hlgroup }
      end
    end
    return keys(decorations)
  end

  local tokens = vim.tbl_keys(groups) ---@type string[]
  table.sort(tokens)
  vim.list_extend(tokens, { "todo", "Todo", "TODO1", "1TODO", "TODOS", "XTODO", "TODO_", "_TODO", "ABC", "HTTP" })
  vim.list_extend(tokens, { "42", "abc", "\195\137TODO", "TODO\195\169", "WARN-ING", "(NOTE)", "FIXME:", "a" })
  local separators = { "", "", " ", ",", "-", "_", ".", "/", "+", "=", "\t", ":", "#" }
  math.randomseed(9)
  for _ = 1, 2000 do
    local parts = {} ---@type string[]
    for _ = 1, math.random(1, 12) do
      parts[#parts + 1] = tokens[math.random(#tokens)] .. separators[math.random(#separators)]
    end
    local line = table.concat(parts)
    t.assert_same(reference(line), keys(keyword.match(line, "lua")), line)
  end
end)

t:test("matches long and shorthand hex colors", function()
  local decorations = matcher.match("#12AbEf #0f8", "lua")
  t.assert_eq(2, #decorations, "color count")

  local long = get_decoration(decorations, "inline_color", 0)
  local short = get_decoration(decorations, "inline_color", 8)
  t.assert_eq("#12AbEf", long and long.color, "long color")
  t.assert_eq("#00ff88", short and short.color, "short color")
end)

t:test("limits rgb and hsl colors to css filetypes", function()
  local line = "rgb(255, 0, 16) hsl(120, 100%, 50%)"
  t.assert_eq(0, #matcher.match(line, "lua"), "lua colors")

  local decorations = matcher.match(line, "css")
  t.assert_eq(2, #decorations, "css colors")
  t.assert_eq("#ff0010", decorations[1].color, "rgb color")
  t.assert_eq("#00ff00", decorations[2].color, "hsl color")
end)

t:test("ignores invalid css channel ranges", function()
  local decorations = matcher.match("rgb(256, 0, 0) hsl(0, 101%, 50%)", "css")
  t.assert_eq(0, #decorations, "invalid colors")
end)

t:test("matches tailwind colors only in configured filetypes", function()
  t.assert_eq(0, #matcher.match("bg-red-500", "lua"), "lua tailwind")

  local decorations = matcher.match("hover:bg-red-500", "typescript")
  t.assert_eq(1, #decorations, "tailwind count")
  t.assert_eq("#EF4444", decorations[1].color, "tailwind color")
end)

t:test("highlights markdown titled separator content", function()
  local decorations = matcher.match("---Release Notes---", "markdown")
  t.assert_eq(1, #decorations, "separator count")
  t.assert_eq(3, decorations[1].coll, "separator start")
  t.assert_eq(16, decorations[1].colr, "separator end")
  t.assert_eq("f_md_titled_separator", decorations[1].hlgroup, "separator group")
  t.assert_eq(0, #matcher.match("---Release Notes---", "lua"), "lua separator")
end)

t:run()
