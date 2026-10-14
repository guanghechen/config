---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.cmp.behavior_cases" ---@type string

local AUTO_IMPORT = "import { foobar } from './lib';"
local snippet_import_differences = {}
-- Blink expands at the old cursor when an import is inserted at the main edit's start.
for _, state in ipairs({
  { step = 2, text = "foobar(value)", cursor = true },
  { step = 3, text = "foobar(x)", cursor = true },
  { step = 4, text = "foobar(value)", cursor = true },
  { step = 6, text = "foobar(value)" },
  { step = 7, text = "foobar(x)", cursor = true },
}) do
  snippet_import_differences[#snippet_import_differences + 1] = {
    step = state.step,
    field = "lines",
    blink = { state.text .. AUTO_IMPORT, "" },
    era = { AUTO_IMPORT, state.text },
    reason = "Expand the snippet after the simultaneous import insertion.",
  }
  if state.cursor then
    snippet_import_differences[#snippet_import_differences + 1] = {
      step = state.step,
      field = "cursor",
      blink = { 1, 7 },
      era = { 2, 7 },
      reason = "Cursor follows the relocated snippet.",
    }
  end
end

return {
  {
    name = "null_insertion_falls_back_to_label",
    options = { items = { { label = "alpha", insertText = vim.NIL, kind = 6 } } },
    steps = { "ial", "<CR>" },
  },
  {
    name = "compound_lsp_default_accept",
    options = {
      filetype = "html",
      items = {
        {
          label = "div>ul>li",
          kind = 10,
          textEdit = {
            range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 9 } },
            newText = "<div><ul><li></li></ul></div>",
          },
        },
        {
          label = "link",
          kind = 10,
          textEdit = {
            range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 9 } },
            newText = '<div><ul><link href=""></ul></div>',
          },
        },
      },
    },
    steps = { "idiv>ul>li", "<CR>" },
  },
  {
    name = "provider_order_without_sort_text",
    options = {
      items = { { label = "beta", filterText = "al", kind = 6 }, { label = "alpha", filterText = "al", kind = 6 } },
    },
    steps = { "ial", "<CR>" },
  },
  {
    name = "lowercase_candidate_preference",
    options = { items = { { label = "getClientUrl", kind = 6 }, { label = "get_current_user", kind = 6 } } },
    steps = { "igcu", "<CR>" },
  },
  {
    name = "uppercase_candidate_preference",
    options = { items = { { label = "getClientUrl", kind = 6 }, { label = "get_current_user", kind = 6 } } },
    steps = { "iGCU", "<CR>" },
  },
  {
    name = "empty_query_uses_history",
    options = { items = { { label = "alpha", kind = 6 }, { label = "beta", kind = 6 } } },
    steps = { "ib", "<CR>", "<C-w>", "a", "<BS>" },
  },
  {
    name = "buffer_fallback_with_primary_items",
    options = { buffer = true, lines = { "", "albatross" }, items = { { label = "alpha", kind = 6 } } },
    steps = { "ial" },
  },
  {
    name = "buffer_fallback_without_primary_items",
    options = { buffer = true, lines = { "", "albatross" }, items = {} },
    steps = { "ial" },
  },
  { name = "insert_enter", steps = { "i", "al", "<Esc>", "a" } },
  { name = "enter_existing_word", options = { lines = { "al" } }, steps = { "A", "<C-space>" } },
  { name = "space_and_punctuation", steps = { "ial", " ", "<BS>", ";", "<BS>" } },
  { name = "backspace_empty", steps = { "ia", "<BS>" } },
  { name = "blocked_server_triggers", options = { triggers = { ".", " ", "(" } }, steps = { "i ", "(", "<Esc>", "A" } },
  { name = "member_trigger", options = { lines = { "obj." } }, steps = { "A", "<C-h>", "<Left>", "<Right>" } },
  {
    name = "cursor_in_query",
    reviewed_differences = {
      {
        step = 2,
        field = "labels",
        blink = { "alpha", "alpine" },
        era = {},
        reason = "Native completion dismisses its menu when the cursor moves inside the query.",
      },
      {
        step = 2,
        field = "selected",
        blink = "alpha",
        era = false,
        reason = "Native completion dismisses its menu when the cursor moves inside the query.",
      },
      {
        step = 2,
        field = "menu",
        blink = true,
        era = false,
        reason = "Native completion dismisses its menu when the cursor moves inside the query.",
      },
      {
        step = 3,
        field = "labels",
        blink = { "alpha", "alpine" },
        era = {},
        reason = "Native completion dismisses its menu when the cursor moves inside the query.",
      },
      {
        step = 3,
        field = "selected",
        blink = "alpha",
        era = false,
        reason = "Native completion dismisses its menu when the cursor moves inside the query.",
      },
      {
        step = 3,
        field = "menu",
        blink = true,
        era = false,
        reason = "Native completion dismisses its menu when the cursor moves inside the query.",
      },
    },
    steps = { "ial", "<Left>", "<Right>", "<Home>", "<Right>" },
  },
  { name = "hidden_cursor", options = { lines = { "al" } }, steps = { "A", "<Left>", "<Right>", "<BS>" } },
  { name = "backspace_whitespace", steps = { "ial ", " ", "<BS>", "<BS>" } },
  { name = "delete_word", steps = { "ial", "<C-w>", "a", "<C-h>", "<C-w>" } },
  {
    name = "hyphen_keyword",
    options = { items = { { label = "foo-bar", kind = 6 } } },
    steps = { "ifo-", "b", "<CR>" },
  },
  { name = "leading_hyphen", steps = { "i-", "al", "<CR>" } },
  {
    name = "accept_trigger",
    options = { items = { { label = "alpha", insertText = "alpha.", kind = 6 } } },
    steps = { "ial", "<CR>", "<C-h>" },
  },
  {
    name = "accept_blocked_trigger",
    options = { triggers = { "(" }, items = { { label = "alpha", insertText = "alpha(", kind = 6 } } },
    steps = { "ial", "<CR>", "<BS>" },
  },
  { name = "navigation_cycle", steps = { "ial", "<Tab>", "<Tab>", "<Tab>", "<S-Tab>", "<S-Tab>" } },
  { name = "hide_preview", steps = { "ial", "<Down>", "<C-h>", "<C-h>" } },
  { name = "cancel_preview", steps = { "ial", "<Down>", { action = "cancel" } } },
  { name = "type_after_preview", steps = { "ial", "<Tab>", "x", "<Esc>" } },
  { name = "backspace_after_preview", steps = { "ial", "<Tab>", "<BS>", "<C-h>" } },
  { name = "accept_and_undo", steps = { "ial", "<CR>", "<Esc>", "u", "<C-r>" } },
  {
    name = "first_line_auto_import",
    options = {
      items = {
        {
          label = "foobar",
          kind = 6,
          additionalTextEdits = {
            {
              newText = AUTO_IMPORT .. "\n",
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
            },
          },
        },
      },
    },
    steps = { "ifo", "<CR>", "x<Esc>", "u", "<C-r>" },
  },
  {
    name = "first_line_auto_import_snippet",
    options = {
      items = {
        {
          label = "foobar",
          kind = 15,
          insertTextFormat = 2,
          insertText = "foobar(${1:value})$0",
          additionalTextEdits = {
            {
              newText = AUTO_IMPORT .. "\n",
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
            },
          },
        },
      },
    },
    steps = { "ifo", "<CR>", "x<Esc>", "u", "u", "<C-r>", "<C-r>" },
    reviewed_differences = snippet_import_differences,
  },
  {
    name = "first_line_auto_import_text_snippet",
    options = {
      items = {
        {
          label = "foobar",
          kind = 3,
          insertTextFormat = 2,
          insertText = "foobar",
          additionalTextEdits = {
            {
              newText = AUTO_IMPORT .. "\n",
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
            },
          },
        },
      },
    },
    steps = { "ifo", "<CR>", "x<Esc>", "u", "<C-r>" },
  },
  { name = "accept_after_deselect", steps = { "ial", "<Up>", "<CR>" } },
  { name = "enter_fallback", options = { items = {} }, steps = { "ix", "<CR>" } },
  { name = "tab_fallback", options = { items = {} }, steps = { "ix", "<Tab>", "<S-Tab>" } },
  { name = "inline_priority", options = { inline = true }, steps = { "ial", "<C-y>", "<C-l>", "<Tab>" } },
  {
    name = "mapping_fallback",
    options = {
      items = {},
      mappings = { { mode = "i", key = "<C-j>", result = "j" }, { mode = "i", key = "<C-k>", result = "k" } },
    },
    steps = { "ix", "<C-j>", "<C-k>", "<C-h>" },
  },
  { name = "mapping_only_fallback", options = { items = {} }, steps = { "ix", "<C-j>", "<C-k>" } },
  {
    name = "disabled_completion_newline",
    options = { filetype = "gitcommit", items = {} },
    steps = { "iabc<C-j>def" },
  },
  {
    name = "disabled_completion_digraph",
    options = { filetype = "gitcommit", items = {} },
    steps = { "i<C-k>ae" },
  },
  {
    name = "disabled_expression_keys",
    options = { items = {} },
    steps = { "i<C-r>=", "'<C-k>ae'", "<C-j>" },
    reviewed_differences = {
      {
        step = 2,
        field = "cmdline",
        blink = "'ae'",
        era = "'æ'",
        reason = "Disabled completion preserves native digraph input in expression registers.",
      },
      {
        step = 3,
        field = "mode",
        blink = "c",
        era = "i",
        reason = "The native confirmation key completes the expression register.",
      },
      { step = 3, field = "lines", blink = { "" }, era = { "æ" }, reason = "Insert the evaluated expression." },
      { step = 3, field = "cursor", blink = { 1, 0 }, era = { 1, 2 }, reason = "Cursor follows the inserted text." },
      { step = 3, field = "cmdline", blink = "'ae'", era = false, reason = "The expression cmdline has closed." },
      { step = 3, field = "cmdpos", blink = 5, era = false, reason = "The expression cmdline has closed." },
    },
  },
  {
    name = "eof_additional_edit",
    options = {
      items = {
        {
          label = "alpha",
          kind = 6,
          additionalTextEdits = {
            {
              newText = "-- trailing declaration\n",
              range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 0 } },
            },
          },
        },
      },
    },
    steps = { "ial", "<CR>", "<Esc>u", "<C-r>" },
  },
  {
    name = "overload_label_details",
    options = {
      menu_text = true,
      items = {
        { label = "alpha", kind = 6, labelDetails = { detail = "(string): string" } },
        { label = "alpha", kind = 6, labelDetails = { detail = "(number): number" } },
      },
    },
    steps = { "ial" },
  },
  {
    name = "documentation",
    options = { documentation = true },
    steps = { "ial", { wait_ms = 300 }, "<C-space>", "<C-space>", "<C-h>" },
  },
  {
    name = "documentation_switch",
    options = { documentation = true },
    steps = { { keys = "ial", wait_ms = 350 }, { keys = "<Tab>", wait_ms = 120 }, "<C-h>" },
  },
  {
    name = "documentation_scroll",
    options = { documentation = ("A documentation line.\n"):rep(50) },
    steps = { { keys = "ial", wait_ms = 350 }, "<C-f>", "<C-f>", "<C-b>", "<Tab>" },
  },
  {
    name = "stale_response_on_leave",
    options = { delay_ms = 150 },
    steps = { { keys = "ial", wait_ms = 20 }, { keys = "<Esc>", wait_ms = 250 } },
  },
  { name = "signature_toggle", options = { signature = true }, steps = { "idemo(", "<C-p>", "<C-p>" } },
  { name = "signature_fallback", options = { items = {} }, steps = { "ial", "<C-p>" } },
  { name = "cmdline_enter", steps = { ":", "CmpFixture ", "al" } },
  { name = "cmdline_navigation", steps = { ":CmpFixture al", "<Tab>", "<Tab>", "<Tab>", "<C-e>" } },
  {
    name = "cmdline_single_tab",
    reviewed_differences = {
      {
        step = 3,
        field = "labels",
        blink = {},
        era = { "alpha" },
        reason = "Native custom command providers own filtering and may return a candidate after backspace.",
      },
      {
        step = 3,
        field = "menu",
        blink = false,
        era = true,
        reason = "Native custom command providers own filtering and may return a candidate after backspace.",
      },
    },
    options = { cmd_items = { "alpha" } },
    steps = { ":CmpFixture al", "<Tab>", "<Tab>" },
  },
  {
    name = "cmdline_cursor",
    reviewed_differences = {
      {
        step = 2,
        field = "selected",
        blink = false,
        era = "alpine",
        reason = "Native command-line Left selects the previous completion while the menu is active.",
      },
      {
        step = 2,
        field = "cmdpos",
        blink = 13,
        era = 18,
        reason = "Native command-line Left selects the previous completion while the menu is active.",
      },
      {
        step = 2,
        field = "cmdline",
        blink = "CmpFixture al",
        era = "CmpFixture alpine",
        reason = "Native command-line Left selects the previous completion while the menu is active.",
      },
    },
    steps = { ":CmpFixture al", "<Left>", "<Right>", "<End>" },
  },
  { name = "cmdline_hidden_cursor", steps = { ":CmpFixture al", "<C-e>", "<Left>", "<Right>" } },
  { name = "cmdline_empty_tab", options = { cmd_items = {} }, steps = { ":CmpFixture al", "<Tab>" } },
  {
    name = "cmdline_cancel_and_type",
    steps = { ":CmpFixture al", "<Tab>", "<C-e>x" },
    reviewed_differences = {
      {
        step = 3,
        field = "cmdline",
        blink = "CmpFixture al",
        era = "CmpFixture alx",
        reason = "Keep input typed immediately after cancelling a preview.",
      },
      { step = 3, field = "cmdpos", blink = 14, era = 15, reason = "Cursor follows the preserved input." },
    },
  },
  {
    name = "cmdline_accept_and_leave",
    steps = { ":CmpFixture al", "<C-y><CR>" },
    reviewed_differences = {
      {
        step = 2,
        field = "commands",
        blink = { "CmpFixture al" },
        era = { "CmpFixture alpha" },
        reason = "Apply acceptance before the following Enter executes the command.",
      },
    },
  },
  { name = "cmdline_fallback_order", steps = { ":CmpFixture al", "<C-e>", "<Left><End>p" } },
  {
    name = "cmdline_mapping_fallback",
    reviewed_differences = {
      {
        step = 3,
        field = "labels",
        blink = {},
        era = { "alpha", "alpine" },
        reason = "The native custom provider returns its full list; mapping fallback still preserves typed input.",
      },
      {
        step = 3,
        field = "menu",
        blink = false,
        era = true,
        reason = "The native custom provider returns its full list; mapping fallback still preserves typed input.",
      },
    },
    options = { mappings = { { mode = "c", key = "<C-j>", result = "x" } } },
    steps = { ":CmpFixture al", "<C-e>", "<C-j>z" },
  },
  {
    name = "search_tab",
    reviewed_differences = {
      {
        step = 2,
        field = "labels",
        blink = { "alpha", "a_long" },
        era = {},
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 2,
        field = "selected",
        blink = "alpha",
        era = false,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 2,
        field = "menu",
        blink = true,
        era = false,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cmdpos",
        blink = 3,
        era = 6,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cursor",
        blink = { 1, 2 },
        era = { 1, 5 },
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cmdline",
        blink = "al",
        era = "alpha",
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
    },
    options = { lines = { "alpha a_long" } },
    steps = { "/al", "<Tab>", "<C-e>" },
  },
  {
    name = "search_shift_tab",
    reviewed_differences = {
      {
        step = 2,
        field = "labels",
        blink = { "alpha", "a_long" },
        era = {},
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 2,
        field = "selected",
        blink = "alpha",
        era = false,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 2,
        field = "menu",
        blink = true,
        era = false,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cmdpos",
        blink = 3,
        era = 6,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cursor",
        blink = { 1, 2 },
        era = { 1, 5 },
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cmdline",
        blink = "al",
        era = "alpha",
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
    },
    options = { lines = { "alpha a_long" } },
    steps = { "/al", "<S-Tab>", "<C-e>" },
  },
  {
    name = "search_backward",
    reviewed_differences = {
      {
        step = 2,
        field = "menu",
        blink = true,
        era = false,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 2,
        field = "labels",
        blink = { "alpha", "a_long" },
        era = {},
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 2,
        field = "selected",
        blink = "alpha",
        era = false,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cmdpos",
        blink = 3,
        era = 6,
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cursor",
        blink = { 1, 2 },
        era = { 1, 5 },
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
      {
        step = 3,
        field = "cmdline",
        blink = "al",
        era = "alpha",
        reason = "Native search uses the search pattern rather than fuzzy word matching; a sole match completes immediately.",
      },
    },
    options = { lines = { "alpha a_long" } },
    steps = { "?al", "<Tab>", "<C-e>" },
  },
  { name = "search_hidden_accept", options = { lines = { "alpha a_long" } }, steps = { "/al", "<C-y>" } },
  {
    name = "search_hidden_cancel",
    reviewed_differences = {
      {
        step = 4,
        field = "menu",
        blink = true,
        era = false,
        reason = "Native search has a single matching word and completes it without a persistent menu.",
      },
      {
        step = 4,
        field = "labels",
        blink = { "alpha", "a_long" },
        era = {},
        reason = "Native search has a single matching word and completes it without a persistent menu.",
      },
      {
        step = 4,
        field = "selected",
        blink = "alpha",
        era = false,
        reason = "Native search has a single matching word and completes it without a persistent menu.",
      },
    },
    options = { lines = { "alpha a_long" } },
    steps = { "/al", "<Left>", "<C-e>", "<Tab>" },
  },
  { name = "function_brackets", options = { items = { { label = "demo", kind = 3 } } }, steps = { "ide", "<CR>" } },
  {
    name = "text_snippet_existing_brackets",
    options = {
      lines = { "s()" },
      cursor = { 1, 0 },
      items = { { label = "sin", insertText = "sin", insertTextFormat = 2, kind = 3 } },
    },
    steps = { "ai", "<CR>", "x" },
  },
  {
    name = "text_snippet_tab_fallback",
    options = { items = { { label = "sin", insertText = "sin", insertTextFormat = 2, kind = 3 } } },
    steps = { "isi", "<CR>", "<Tab>" },
  },
  {
    name = "text_snippet_undo",
    options = { items = { { label = "sin", insertText = "sin", insertTextFormat = 2, kind = 3 } } },
    steps = { "isi", "<CR>", "x<Esc>", "u" },
  },
  {
    name = "text_snippet_repeat",
    options = {
      lines = { "", "" },
      cursor = { 1, 0 },
      items = { { label = "sin", insertText = "sin", insertTextFormat = 2, kind = 3 } },
    },
    steps = { "isi", "<CR>", "x<Esc>j0." },
  },
  {
    name = "function_preview",
    options = { items = { { label = "demo", kind = 3 } } },
    steps = { "ide", "<Down>", "<Down>", "<CR>" },
  },
  {
    name = "directory_accept",
    options = { triggers = { "/" }, items = { { label = "assets/", kind = 19 } } },
    steps = { "ias", "<CR>" },
  },
  {
    name = "snippet_signature_preview_typing",
    options = {
      items = {
        { label = "normalize(value)", kind = 3, insertTextFormat = 2, insertText = "normalize(${1:value})$0" },
      },
    },
    steps = { "inor", "<Down>", "<Down>", "(" },
  },
  {
    name = "snippet_alias_preview",
    options = {
      items = {
        { label = "fn", kind = 15, insertTextFormat = 2, insertText = "function ${1:name}(${2:args})\n\t$0\nend" },
      },
    },
    steps = { "if", "<Down>", "<Down>", "<CR>" },
  },
  {
    name = "snippet_preview",
    options = {
      items = { { label = "call", kind = 15, insertText = "call(${1:first}, ${2:second})$0", insertTextFormat = 2 } },
    },
    steps = { "ica", "<Down>", "<Down>", { wait_ms = 300 }, { action = "cancel" } },
  },
  {
    name = "snippet_backwards",
    options = {
      items = { { label = "call", kind = 15, insertText = "call(${1:first}, ${2:second})$0", insertTextFormat = 2 } },
    },
    steps = { "ica", "<CR>", "<Tab>", "<S-Tab>" },
  },
  {
    name = "snippet_jump",
    options = {
      items = { { label = "call", kind = 15, insertText = "call(${1:first}, ${2:second})$0", insertTextFormat = 2 } },
    },
    steps = { "ica", "<CR>", "value", "<Tab>", "other", "<Tab>" },
    reviewed_differences = {
      {
        step = 6,
        field = "cursor",
        blink = { 1, 17 },
        era = { 1, 18 },
        reason = "Respect the snippet's final $0 position.",
      },
    },
  },
}
