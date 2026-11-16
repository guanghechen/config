local harness = require("__test__.support.harness")
local fs = require("__test__.support.fs")
local UI = require("__test__.support.ui")
local t = harness.new()

local FIXTURE = "__test__/fixtures/era/keystroke/pairs/blink.json"
-- Fixture cases where era deliberately differs from blink.pairs: a bracket typed inside a string stays single.
---@type table<integer, { keys: string, result: table }>
local DEVIATIONS = {
  [16] = { keys = "<CR>(", result = { cursor = { 1, 1 }, lines = { "local s = [[", "(", "]]" } } },
  [332] = { keys = "{", result = { cursor = { 0, 2 }, lines = { "'{\\" } } },
}

---@return __test__.support.UI
local function child()
  local ui = UI.open(t, { runtime = "ark" })
  ui:lua([[
    pairs_cases = require("__test__.fixtures.era.keystroke.pairs.child")
    pairs_cases.setup("era")
  ]])
  return ui
end

---@param ui                            __test__.support.UI
---@param case                          __test__.fixtures.era.keystroke.pairs.ICase
---@return table
local function run(ui, case)
  return ui:lua("return pairs_cases.run(...)", case)
end

t:test("typing does what blink.pairs did with this configuration", function()
  local fixture = vim.json.decode((fs.read(FIXTURE)))
  t.assert_true(#fixture.cases > 300)
  local ui = child()
  for index, case in ipairs(fixture.cases) do
    local expected = case.expected
    case.expected = nil
    local deviation = DEVIATIONS[index]
    if deviation then
      t.assert_eq(deviation.keys, case.keys, string.format("case %d is the deviation listed for it", index))
      expected = deviation.result
    end
    t.assert_same(
      expected,
      run(ui, case),
      string.format("case %d: %q typed into %s %s", index, case.keys, case.filetype, vim.inspect(case.lines))
    )
  end
end)

t:test("a bracket typed inside a string stays single", function()
  local ui = child()
  -- A Lua pattern's escaped parenthesis: the string closes where its quote is typed.
  t.assert_same(
    { cursor = { 0, 13 }, lines = { 's:match("%(")' } },
    run(ui, { filetype = "lua", lines = { "" }, cursor = { 0, 0 }, keys = 's:match("%(")' })
  )
  -- A character literal is a string too.
  t.assert_same(
    { cursor = { 0, 11 }, lines = { "let c = '('" } },
    run(ui, { filetype = "rust", lines = { "let c = " }, cursor = { 0, 8 }, keys = "'('" })
  )
  -- A format string's braces read the same when both are typed.
  t.assert_same(
    { cursor = { 0, 17 }, lines = { 'println!("{}", x)' } },
    run(ui, { filetype = "rust", lines = { "" }, cursor = { 0, 0 }, keys = 'println!("{}", x)' })
  )
  -- Backspace inside a string deletes one character, and code outside still pairs.
  t.assert_same(
    { cursor = { 0, 5 }, lines = { 'x = ")"' } },
    run(ui, { filetype = "lua", lines = { 'x = "()"' }, cursor = { 0, 6 }, keys = "<BS>" })
  )
  t.assert_same(
    { cursor = { 0, 13 }, lines = { 'x = "a" .. f()' } },
    run(ui, { filetype = "lua", lines = { 'x = "a"' }, cursor = { 0, 7 }, keys = " .. f(" })
  )
end)

t:test("the command line types Vim script whatever the buffer's language", function()
  local ui = child()
  -- blink.pairs applied the buffer's rules: LaTeX's `` `' `` and markdown's `$$`.
  t.assert_same(
    { cmdline = "``", cursor = 1 },
    run(ui, { filetype = "tex", lines = { "" }, cmdline = true, keys = "`" })
  )
  t.assert_same(
    { cmdline = "$", cursor = 1 },
    run(ui, { filetype = "markdown", lines = { "" }, cmdline = true, keys = "$" })
  )
end)

t:test("Enter on the command line runs the command with the cursor inside a pair", function()
  local ui = child()
  ui:lua("vim.cmd.enew()")
  -- `(` closes itself, so Enter comes between the parentheses.
  ui:rpc("nvim_input", ":let g:pairs_ran = localtime(<CR>")
  ui:wait_lua("return vim.g.pairs_ran ~= nil", 5000, "the command ran")
  t.assert_eq("n", ui:lua("return vim.api.nvim_get_mode().mode"))
  t.assert_same({ "" }, ui:lua("return vim.api.nvim_buf_get_lines(0, 0, -1, false)"))
end)

t:test("a line break and the first space after a word start new undo steps", function()
  local ui = child()
  local states = ui:lua([[
    vim.cmd.enew()
    vim.bo.filetype = "lua"
    -- Completion's InsertCharPre autocmd makes the configuration take typed keys one at a time.
    vim.api.nvim_create_autocmd("InsertCharPre", { callback = function() end })
    vim.api.nvim_feedkeys(vim.keycode("ithe quick  brown fox<CR>next<Esc>"), "tx", false)
    local states = { vim.api.nvim_buf_get_lines(0, 0, -1, false) }
    while true do
      local seq = vim.fn.undotree().seq_cur
      vim.cmd("silent! undo")
      if vim.fn.undotree().seq_cur == seq then
        return states
      end
      states[#states + 1] = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    end
  ]])
  t.assert_same({
    { "the quick  brown fox", "next" },
    { "the quick  brown fox" },
    { "the quick  brown" },
    { "the quick" },
    { "the" },
    { "" },
  }, states)
end)

t:run()
