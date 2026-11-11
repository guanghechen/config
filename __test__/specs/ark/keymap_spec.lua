local harness = require("__test__.support.harness")
local undo = require("__test__.support.undo")

local t = harness.new()

vim.o.showmode = false

-- An in-memory clipboard keeps the system one out of the test.
local clipboard = { lines = { "pasted" }, regtype = "v" }
vim.g.clipboard = {
  name = "test",
  copy = {
    ["+"] = function(lines, regtype)
      clipboard = { lines = lines, regtype = regtype }
    end,
    ["*"] = function() end,
  },
  paste = {
    ["+"] = function()
      return { clipboard.lines, clipboard.regtype }
    end,
    ["*"] = function()
      return { {}, "v" }
    end,
  },
  cache_enabled = 0,
}

require("ark.keymap")

for _, case in ipairs({
  {
    name = "ASCII punctuation ends an undo step",
    keys = "one,two.three;four",
    states = {
      { "one,two.three;four" },
      { "one,two.three;" },
      { "one,two." },
      { "one," },
      { "" },
    },
  },
  {
    name = "full-width punctuation from an input method ends an undo step too",
    keys = "你好，世界。天气不错；注意：真好！对吗？再见",
    states = {
      { "你好，世界。天气不错；注意：真好！对吗？再见" },
      { "你好，世界。天气不错；注意：真好！对吗？" },
      { "你好，世界。天气不错；注意：真好！" },
      { "你好，世界。天气不错；注意：" },
      { "你好，世界。天气不错；" },
      { "你好，世界。" },
      { "你好，" },
      { "" },
    },
  },
  {
    name = "undo takes back a word with the space before it, as in VS Code",
    keys = "the quick  brown fox",
    states = {
      { "the quick  brown fox" },
      { "the quick  brown" },
      { "the quick" },
      { "the" },
      { "" },
    },
  },
  {
    name = "undo takes back a line with its line break",
    keys = "one<CR>two<CR>three",
    states = {
      { "one", "two", "three" },
      { "one", "two" },
      { "one" },
      { "" },
    },
  },
}) do
  t:test(case.name, function()
    t.assert_same(case.states, undo.states(t, case.keys))
  end)
end

---@param line                          string
---@param col                           integer
---@return integer
local function open(line, col)
  local bufnr = t:buffer({ line }, { current = true })
  vim.api.nvim_win_set_cursor(0, { 1, col })
  return bufnr
end

for _, case in ipairs({
  { name = "Insert mode pastes at the cursor and stays in Insert mode", keys = "i<M-v>X<Esc>", line = "pastedXab" },
  { name = "Normal mode pastes after the cursor", keys = "<M-v>", line = "apastedb" },
}) do
  t:test(case.name, function()
    open("ab", 0)

    vim.api.nvim_feedkeys(vim.keycode(case.keys), "tx", false)
    t.assert_eq(case.line, vim.api.nvim_get_current_line())
  end)
end

t:test("Visual mode replaces the selection and keeps the unnamed register", function()
  open("one two three", 4)
  vim.fn.setreg('"', "kept")

  vim.api.nvim_feedkeys(vim.keycode("viw<M-v>"), "tx", false)
  t.assert_eq("one pasted three", vim.api.nvim_get_current_line())
  t.assert_eq("kept", vim.fn.getreg('"'), "unnamed register")
end)

t:test("escape skips unused snippets and stops an active native session", function()
  local escape = vim.fn.maparg("<Esc>", "n", false, true).callback ---@type (fun(): string)|nil
  t.assert_nil(package.loaded["vim.snippet"], "cold snippet module")
  t.assert_eq("<esc>", assert(escape)(), "mapped key")
  t.assert_nil(package.loaded["vim.snippet"], "unused snippet module remains unloaded")

  local snippet = require("vim.snippet")
  t:buffer({ "" }, { current = true })
  t:defer(snippet.stop)
  snippet.expand("${1:word}$0")
  t.assert_true(snippet.active(), "native snippet session")

  t.assert_eq("<esc>", escape(), "mapped key")
  t.assert_false(snippet.active(), "session stopped")
  t.assert_eq("word", vim.api.nvim_get_current_line(), "snippet text preserved")
end)

t:run()
