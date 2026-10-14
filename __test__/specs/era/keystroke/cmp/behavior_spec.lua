---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.keystroke.cmp.behavior" ---@type string

local harness = require("__test__.support.harness")
local Trace = require("__test__.fixtures.era.keystroke.cmp.behavior_trace")
local cases = require("__test__.fixtures.era.keystroke.cmp.behavior_cases")
local t = harness.new("era.keystroke.cmp.behavior")
local output = vim.fn.tempname()
vim.fn.mkdir(output, "p")
t:defer(function()
  vim.fn.delete(output, "rf")
end)

-- These observable contracts were checked against the frozen Blink configuration.
-- The regression suite only runs Era and does not require an installed Blink checkout.
local expected = {
  null_insertion_falls_back_to_label = {
    { menu = true, labels = { "alpha" }, selected = "alpha", lines = { "al" } },
    { menu = false, lines = { "alpha" } },
  },
  compound_lsp_default_accept = {
    { menu = true, labels = { "div>ul>li", "link" }, selected = "div>ul>li" },
    { menu = false, lines = { "<div><ul><li></li></ul></div>" } },
  },
  first_line_auto_import = {
    [2] = { lines = { "import { foobar } from './lib';", "foobar" }, cursor = { 2, 6 }, snippet = false },
    [3] = { lines = { "import { foobar } from './lib';", "foobarx" } },
    [4] = { lines = { "fo" } },
    [5] = { lines = { "import { foobar } from './lib';", "foobarx" } },
  },
  first_line_auto_import_snippet = {
    [2] = { lines = { "import { foobar } from './lib';", "foobar(value)" }, cursor = { 2, 7 }, snippet = true },
    [3] = { lines = { "import { foobar } from './lib';", "foobar(x)" } },
    [4] = { lines = { "import { foobar } from './lib';", "foobar(value)" } },
    [5] = { lines = { "" }, snippet = false },
    [6] = { lines = { "import { foobar } from './lib';", "foobar(value)" }, snippet = false },
    [7] = { lines = { "import { foobar } from './lib';", "foobar(x)" }, cursor = { 2, 7 }, snippet = false },
  },
  first_line_auto_import_text_snippet = {
    [2] = { lines = { "import { foobar } from './lib';", "foobar()" }, cursor = { 2, 7 }, snippet = false },
    [3] = { lines = { "import { foobar } from './lib';", "foobar(x)" } },
    [4] = { lines = { "" } },
    [5] = { lines = { "import { foobar } from './lib';", "foobar(x)" } },
  },
  provider_order_without_sort_text = {
    { menu = true, labels = { "beta", "alpha" }, selected = "beta" },
    { lines = { "beta" } },
  },
  lowercase_candidate_preference = {
    { selected = "get_current_user" },
    { lines = { "get_current_user" } },
  },
  uppercase_candidate_preference = {
    { selected = "getClientUrl" },
    { lines = { "getClientUrl" } },
  },
  empty_query_uses_history = { [5] = { menu = true, labels = { "beta", "alpha" }, selected = "beta", lines = { "" } } },
  buffer_fallback_with_primary_items = { { menu = true, labels = { "alpha" }, selected = "alpha" } },
  buffer_fallback_without_primary_items = { { menu = true, labels = { "albatross" }, selected = "albatross" } },
  enter_existing_word = { { menu = false }, { menu = true, selected = "alpha", lines = { "al" } } },
  member_trigger = { { menu = true }, { menu = false }, { menu = false }, { menu = false } },
  backspace_empty = { { menu = true }, { menu = true, lines = { "" }, labels = { "alpha", "alpine" } } },
  hidden_cursor = { { menu = false }, { menu = false }, { menu = false }, { menu = true } },
  blocked_server_triggers = { { menu = false }, { menu = true }, { menu = false }, { menu = false } },
  hyphen_keyword = { [3] = { menu = false, lines = { "foo-bar" } } },
  leading_hyphen = { [3] = { lines = { "-alpha" } } },
  accept_trigger = { [2] = { menu = true, lines = { "alpha." } } },
  accept_blocked_trigger = { [2] = { menu = false, lines = { "alpha(" } }, [3] = { menu = true } },
  signature_fallback = { [2] = { mode = "i", native_menu = false, lines = { "al" } } },
  disabled_completion_newline = { { menu = false, lines = { "abc", "def" } } },
  disabled_completion_digraph = { { menu = false, lines = { "æ" } } },
  disabled_expression_keys = {
    [2] = { mode = "c", menu = false, cmdline = "'æ'" },
    [3] = { mode = "i", menu = false, lines = { "æ" } },
  },
  eof_additional_edit = {
    [2] = { menu = false, lines = { "alpha", "-- trailing declaration" } },
    [3] = { lines = { "al" } },
    [4] = { lines = { "alpha", "-- trailing declaration" } },
  },
  overload_label_details = {
    { menu = true, labels = { "alpha", "alpha" }, menu_text = { "alpha(string): string", "alpha(number): number" } },
  },
  text_snippet_existing_brackets = {
    [2] = { lines = { "sin()" }, cursor = { 1, 4 }, snippet = false },
    [3] = { lines = { "sin(x)" }, cursor = { 1, 5 } },
  },
  text_snippet_tab_fallback = {
    [2] = { lines = { "sin()" }, cursor = { 1, 4 }, snippet = false },
    [3] = { lines = { "sin(\t)" }, cursor = { 1, 5 }, snippet = false },
  },
  text_snippet_undo = { [4] = { lines = { "" }, cursor = { 1, 0 }, snippet = false } },
  text_snippet_repeat = { [3] = { lines = { "sin(x)", "sin(x)" }, mode = "n", snippet = false } },
  documentation_switch = {
    [2] = { documentation = true, documentation_lines = { "alpine", "", "A stable completion description." } },
  },
  documentation_scroll = {
    { documentation_topline = 1 },
    { documentation_topline = 5 },
    { documentation_topline = 9 },
    { documentation_topline = 5 },
    { documentation_topline = 1 },
  },
  cmdline_single_tab = {
    { menu = true, selected = false, ghost = false },
    { menu = false, cmdline = "CmpFixture alpha", cmdpos = 17, ghost = false },
  },
  cmdline_fallback_order = { [3] = { cmdline = "CmpFixture alp", cmdpos = 15 } },
  cmdline_mapping_fallback = { [3] = { cmdline = "CmpFixture alxz", fallback_calls = { "<C-j>" } } },
  search_tab = {
    { menu = false, cmdline = "al", cursor = { 1, 2 }, ghost = false },
    { menu = false, cmdline = "alpha", cursor = { 1, 5 }, ghost = false },
    { menu = false, cmdline = "alpha", cursor = { 1, 5 }, ghost = false },
  },
  search_shift_tab = { [2] = { cmdline = "alpha", menu = false, selected = false } },
  search_hidden_accept = { [2] = { cmdline = "al\25", cmdpos = 4, menu = false, ghost = false } },
  search_hidden_cancel = {
    [3] = { cmdline = "al", cmdpos = 3, menu = false, ghost = false },
    [4] = { cmdline = "alpha", menu = false, selected = false },
  },
  stale_response_on_leave = { [2] = { mode = "n", menu = false, documentation = false } },
  -- Keep deliberate corrections to the old mapping's edge cases explicit.
  -- Native custom command providers own filtering; this fixture deliberately returns its whole list.
  cmdline_cancel_and_type = { [3] = { cmdline = "CmpFixture alx", cmdpos = 15, menu = true } },
  cmdline_accept_and_leave = { [2] = { commands = { "CmpFixture alpha" }, mode = "n" } },
  snippet_jump = { [6] = { lines = { "call(value, other)" }, cursor = { 1, 18 }, mode = "i", snippet = false } },
}

for _, case in ipairs(cases) do
  local contract = expected[case.name]
  if contract ~= nil then
    t:test(case.name, function()
      local states = Trace.run({ root = assert(vim.uv.cwd()), engine = "era", output = output }, case)
      for step, fields in pairs(contract) do
        for key, value in pairs(fields) do
          t.assert_true(
            vim.deep_equal(value, states[step][key]),
            string.format(
              "step %d %s: expected %s, got %s",
              step,
              key,
              vim.inspect(value),
              vim.inspect(states[step][key])
            )
          )
        end
      end
    end)
  end
end

t:run()
