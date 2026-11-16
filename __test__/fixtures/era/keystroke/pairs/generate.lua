-- Usage, from the repository root, with blink.pairs installed and built:
-- nvim -l __test__/fixtures/era/keystroke/pairs/generate.lua [blink-root]
-- Writes blink.json beside this file: what typing each case's keys does under blink.pairs v0.5.0 with this
-- configuration's options, in a child with only Neovim's bundled treesitter parsers, as
-- __test__/specs/era/keystroke/pairs/typing_spec.lua runs era.keystroke.pairs. Command-line cases type into an
-- empty buffer: blink.pairs checks the balance of the current buffer's first line there.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.pairs.generate" ---@type string

local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))) ---@type string
local directory = vim.fs.dirname(source) ---@type string
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(directory))))) ---@type string
vim.api.nvim_set_current_dir(root)
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local UI = require("__test__.support.ui")
local blink_root = arg[1] or vim.fn.stdpath("data") .. "/lazy/blink.pairs" ---@type string

---@type __test__.fixtures.era.keystroke.pairs.ICase[]
local CASES = {
  { filetype = "lua", lines = { "local x = " }, cursor = { 0, 10 }, keys = "(" },
  { filetype = "lua", lines = { "local x = " }, cursor = { 0, 10 }, keys = "foo(a, b)" },
  { filetype = "lua", lines = { "local x = " }, cursor = { 0, 10 }, keys = "(<BS>" },
  { filetype = "lua", lines = { "local x = " }, cursor = { 0, 10 }, keys = "{<CR>a" },
  { filetype = "lua", lines = { "local x = " }, cursor = { 0, 10 }, keys = "{<Space>a" },
  { filetype = "lua", lines = { "local x = " }, cursor = { 0, 10 }, keys = "{ <BS>" },
  { filetype = "lua", lines = { "local x = " }, cursor = { 0, 10 }, keys = "{ <CR>" },
  { filetype = "lua", lines = { "foo)" }, cursor = { 0, 3 }, keys = "(" },
  { filetype = "lua", lines = { "(foo" }, cursor = { 0, 4 }, keys = ")" },
  { filetype = "lua", lines = { "f(x" }, cursor = { 0, 3 }, keys = " )" },
  { filetype = "lua", lines = { "x = " }, cursor = { 0, 4 }, keys = '"abc"' },
  { filetype = "lua", lines = { "-- don" }, cursor = { 0, 6 }, keys = "'t" },
  { filetype = "lua", lines = { "x = \\" }, cursor = { 0, 5 }, keys = "(" },
  { filetype = "lua", lines = { "x = \\" }, cursor = { 0, 5 }, keys = '"' },
  { filetype = "lua", lines = { "f(", "", ")" }, cursor = { 1, 0 }, keys = "a[1]" },
  { filetype = "lua", lines = { "local s = [[", "]]" }, cursor = { 0, 12 }, keys = "<CR>(" },
  { filetype = "markdown", lines = { "``" }, cursor = { 0, 2 }, keys = "`" },
  { filetype = "markdown", lines = { "- " }, cursor = { 0, 2 }, keys = "[ ]" },
  { filetype = "markdown", lines = { "1. " }, cursor = { 0, 3 }, keys = "[ ]" },
  { filetype = "markdown", lines = { "see " }, cursor = { 0, 4 }, keys = "[ x" },
  { filetype = "markdown", lines = { "x " }, cursor = { 0, 2 }, keys = "$a" },
  { filetype = "markdown", lines = { "<" }, cursor = { 0, 1 }, keys = "!" },
  { filetype = "markdown", lines = { "```lua", "", "```" }, cursor = { 1, 0 }, keys = "x = 'a'" },
  { filetype = "markdown", lines = { "it" }, cursor = { 0, 2 }, keys = "'s" },
  { filetype = "rust", lines = { "let s = r#" }, cursor = { 0, 10 }, keys = '"' },
  { filetype = "rust", lines = { "let c = " }, cursor = { 0, 8 }, keys = "'x'" },
  { filetype = "python", lines = { "x = ''" }, cursor = { 0, 6 }, keys = "'" },
  { filetype = "python", lines = { 'x = ""' }, cursor = { 0, 6 }, keys = '"' },
  { filetype = "tex", lines = { "a " }, cursor = { 0, 2 }, keys = "`b" },
  { filetype = "json", lines = { "" }, cursor = { 0, 0 }, keys = '{"a": [1]}' },
  { filetype = "vim", lines = { "" }, cursor = { 0, 0 }, keys = "call f('a', [1])" },
  { filetype = "lua", lines = { "" }, cmdline = true, keys = 'echo ("a' },
  { filetype = "lua", lines = { "" }, cmdline = true, keys = "call f(<Space>" },
  { filetype = "lua", lines = { "" }, cmdline = true, keys = "call f(x)<BS><BS>" },
  { filetype = "lua", lines = { "" }, cmdline = true, keys = "s/a(b/c" },
}

local seed = 7 ---@type integer
---@param bound                         integer
---@return integer
local function random(bound)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % bound
end

-- stylua: ignore
local KEYS = { "(", ")", "[", "]", "{", "}", "'", '"', "`", "<", ">", "$", "_", "*", "!", "-", "a", "x", " ", " ", "<BS>",
  "<BS>", "<CR>", "\\", "#", "r", "=" }
-- stylua: ignore
local TEXT = { "(", ")", "[", "]", "{", "}", "'", '"', "`", "--", "//", "/*", "*/", "#", "x", "foo", " ", "  ", "\\", "$", "<",
  ">" }
local FILETYPES = { "lua", "markdown", "vim", "c", "rust", "python", "javascript", "json", "tex", "toml" }
for _ = 1, 300 do
  local lines = {} ---@type string[]
  for _ = 1, 1 + random(4) do
    local parts = {} ---@type string[]
    for _ = 1, random(6) do
      parts[#parts + 1] = TEXT[random(#TEXT) + 1]
    end
    lines[#lines + 1] = table.concat(parts)
  end
  local row = random(#lines) ---@type integer
  local keys = {} ---@type string[]
  for _ = 1, 1 + random(8) do
    keys[#keys + 1] = KEYS[random(#KEYS) + 1]
  end
  CASES[#CASES + 1] = {
    filetype = FILETYPES[random(#FILETYPES) + 1],
    lines = lines,
    cursor = { row, random(#lines[row + 1] + 1) },
    keys = table.concat(keys),
  }
end

local ui = UI.new({ timeout_ms = 60000 })
ui:start({ runtime = "ark" })
ui:lua(
  [[
  pairs_cases = require("__test__.fixtures.era.keystroke.pairs.child")
  pairs_cases.setup("blink", ...)
]],
  blink_root
)
for _, case in ipairs(CASES) do
  case.expected = ui:lua("return pairs_cases.run(...)", case)
end
ui:close()
local commit = vim.system({ "git", "-C", blink_root, "rev-parse", "--short", "HEAD" }, { text = true }):wait()
local path = directory .. "/blink.json" ---@type string
assert(
  vim.fn.writefile(
    { vim.json.encode({ blink = vim.trim(commit.stdout or ""), cases = CASES }, { sort_keys = true }) },
    path
  ) == 0,
  "cannot write " .. path
)
print(string.format("%d cases -> %s", #CASES, path))
