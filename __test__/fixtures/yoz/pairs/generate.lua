-- Usage, from the repository root, with blink.pairs installed and built:
-- nvim -l __test__/fixtures/yoz/pairs/generate.lua [blink-root]
-- Writes blink.json beside this file: the tokens, heights and pair queries of blink.pairs v0.5.0 for random lines in
-- every language and slices of this checkout's sources, which __test__/specs/yoz/pairs_spec.lua compares with
-- yoz.pairs. A query position is every column of every row, or of every tenth row of a slice; only positions where
-- some query finds a result are written.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.yoz.pairs.generate" ---@type string

local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))) ---@type string
local directory = vim.fs.dirname(source) ---@type string
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(directory)))) ---@type string
local blink_root = arg[1] or vim.fn.stdpath("data") .. "/lazy/blink.pairs" ---@type string
package.cpath = blink_root .. "/target/release/lib?.dylib;" .. blink_root .. "/target/release/lib?.so;" .. package.cpath
local blink = require("blink_pairs")

---@class __test__.fixtures.yoz.pairs.ICase
---@field name                          string
---@field language                      string
---@field tab_width                     integer
---@field query_every                   integer Rows between query rows.
---@field lines                         string[]

-- stylua: ignore
---@type string[]
local LANGUAGES = {
  "c", "clojure", "cpp", "csharp", "dart", "elixir", "erlang", "fsharp", "go", "haskell", "haxe", "java", "javascript",
  "json", "kotlin", "latex", "lean", "lua", "markdown", "nix", "objc", "ocaml", "perl", "php", "python", "r", "ruby",
  "rust", "scala", "scheme", "shell", "sql", "swift", "toml", "typst", "vim", "zig",
}
-- Patterns of every language, so each language also meets the others' syntax as plain text.
-- stylua: ignore
---@type string[]
local VOCABULARY = {
  "(", ")", "[", "]", "{", "}", '"', "'", "`", "\\", "\\\\", " ", " ", " ", "x", "ab", "\t", "--", "//", "/*", "*/", "#",
  "%", ";", '"""', "'''", "[[", "]]", "--[[", 'r#"', '"#', 'r##"', '"##', "$", "$$", "_", "*", "**", "~~", "```",
  "=begin", "end", 'R"(', ')"', '@"', "''", "{-", "-}", "/-", "-/", "(*", "*)", "'a", "'{'", "'\\''",
}
---@type { path: string, language: string, first: integer, last: integer }[]
local SLICES = {
  { path = "lua/era/m/git/hunk_nav.lua", language = "lua", first = 1, last = 150 },
  { path = "rust/yoz/src/fuzzy/algo.rs", language = "rust", first = 1, last = 150 },
  { path = "script/build.mjs", language = "javascript", first = 1, last = 150 },
  { path = "spec/design/feat/git-files.md", language = "markdown", first = 1, last = 80 },
  { path = ".luarc.json", language = "json", first = 1, last = 200 },
}
---@type string[][]
local DELIMITERS = { { "(", ")" }, { "[", "]" }, { "{", "}" } }
-- Text that yoz.pairs reads unlike blink.pairs on purpose (spec/design/yoz/pairs.md), rewritten out of random lines.
---@type table<string, string[]>
local DEVIATIONS = { csharp = { '"""', '"" "' } }

local seed = 20261114 ---@type integer
---@param bound                         integer
---@return integer
local function random(bound)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % bound
end

---@return __test__.fixtures.yoz.pairs.ICase[]
local function cases()
  local result = {} ---@type __test__.fixtures.yoz.pairs.ICase[]
  for _, language in ipairs(LANGUAGES) do
    for index = 1, 4 do
      local lines = {} ---@type string[]
      for _ = 1, 1 + random(8) do
        local parts = {} ---@type string[]
        for _ = 1, random(4) do
          parts[#parts + 1] = random(3) == 0 and "\t" or "  "
        end
        for _ = 1, random(12) do
          parts[#parts + 1] = VOCABULARY[random(#VOCABULARY) + 1]
        end
        local line = table.concat(parts) ---@type string
        local deviation = DEVIATIONS[language]
        if deviation then
          line = line:gsub(vim.pesc(deviation[1]), deviation[2])
        end
        lines[#lines + 1] = line
      end
      result[#result + 1] = {
        name = string.format("random %s %d", language, index),
        language = language,
        tab_width = 2 + random(7),
        query_every = 1,
        lines = lines,
      }
    end
  end
  for _, slice in ipairs(SLICES) do
    result[#result + 1] = {
      name = string.format("%s %d-%d", slice.path, slice.first, slice.last),
      language = slice.language,
      tab_width = 4,
      query_every = 10,
      lines = vim.list_slice(vim.fn.readfile(root .. "/" .. slice.path), slice.first, slice.last),
    }
  end
  return result
end

local next_id = 1 ---@type integer

--- The fields of a token joined by `|`, an absent one as `nil`.
---@param ... any
---@return string
local function key(...)
  local fields = {} ---@type string[]
  for index = 1, select("#", ...) do
    fields[index] = tostring((select(index, ...)))
  end
  return table.concat(fields, "|")
end

---@param pair                          table|nil
---@return string
local function pair_key(pair)
  return pair and string.format("%d,%d,%d,%d", pair[1].line, pair[1].col, pair[2].line, pair[2].col) or "-"
end

---@param match                         table|nil
---@return string
local function position_key(match)
  return match and string.format("%d,%d", match.line, match.col) or "-"
end

---@param case                          __test__.fixtures.yoz.pairs.ICase
---@return table
local function record(case)
  local id = next_id
  next_id = next_id + 1
  assert(blink.parse_buffer(id, case.tab_width, case.language, case.lines), "blink.pairs did not parse " .. case.name)
  local tokens = {} ---@type string[][]
  for row = 0, #case.lines - 1 do
    local keys = {} ---@type string[]
    for token_type = 0, 4 do
      for _, match in ipairs(blink.get_line_matches(id, row, token_type)) do
        keys[#keys + 1] = key(match.col, match[1], match[2], match.span, match.stack_height)
      end
    end
    -- Spans have no token type of their own; find them by position.
    local seen = {} ---@type table<integer, boolean>
    for col = 0, #case.lines[row + 1] do
      local match = blink.get_match_at(id, row, col)
      if match and match.span and not seen[match.col] then
        seen[match.col] = true
        keys[#keys + 1] = key(match.col, match[1], match[2], match.span, match.stack_height)
      end
    end
    table.sort(keys)
    tokens[#tokens + 1] = keys
  end
  local queries = vim.empty_dict()
  for row = 0, #case.lines - 1, case.query_every do
    for col = 0, #case.lines[row + 1] + 1 do
      local values = {
        pair_key(blink.get_match_pair(id, row, col)),
        pair_key(blink.get_surrounding_match_pair(id, row, col)),
      }
      for _, delimiter in ipairs(DELIMITERS) do
        values[#values + 1] = position_key(blink.get_unmatched_closing_after(id, delimiter[1], delimiter[2], row, col))
        values[#values + 1] = position_key(blink.get_unmatched_opening_before(id, delimiter[1], delimiter[2], row, col))
      end
      local value = table.concat(values, " ")
      if value:find("%d") then
        queries[row .. ":" .. col] = value
      end
    end
  end
  return {
    name = case.name,
    language = case.language,
    tab_width = case.tab_width,
    query_every = case.query_every,
    lines = case.lines,
    tokens = tokens,
    queries = queries,
  }
end

local commit = vim.system({ "git", "-C", blink_root, "rev-parse", "--short", "HEAD" }, { text = true }):wait()
local recorded = {} ---@type table[]
for _, case in ipairs(cases()) do
  recorded[#recorded + 1] = record(case)
end
local path = directory .. "/blink.json" ---@type string
assert(
  vim.fn.writefile(
    { vim.json.encode({ blink = vim.trim(commit.stdout or ""), cases = recorded }, { sort_keys = true }) },
    path
  ) == 0,
  "cannot write " .. path
)
print(string.format("%d cases -> %s", #recorded, path))
