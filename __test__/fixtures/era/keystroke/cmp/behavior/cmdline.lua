---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.cmp.behavior.cmdline" ---@type string

-- Completion behavior cases: payload, keys and the state each step must reach. The expectations were checked
-- against the frozen Blink 1.10.2 configuration during the migration; cases only the removed differential runner
-- covered were recorded from Era and later reviewed against the completion design, plain Neovim for native keys and
-- Blink's preview prefix. Only listed fields are compared, so a state that must be off is listed as false.

-- The menu over the typed "CmpFixture al" with no candidate selected.
local MENU = {
  menu = true,
  labels = { "alpha", "alpine" },
  selected = false,
  lines = { "" },
  cursor = { 1, 0 },
  mode = "c",
  cmdline = "CmpFixture al",
  cmdpos = 14,
  snippet = false,
}
-- The second candidate previewed in place of "al".
local PREVIEW = {
  menu = true,
  labels = { "alpha", "alpine" },
  selected = "alpine",
  lines = { "" },
  cursor = { 1, 0 },
  mode = "c",
  cmdline = "CmpFixture alpine",
  cmdpos = 18,
  snippet = false,
}
-- The typed "CmpFixture al" without a menu.
local CLOSED = {
  menu = false,
  lines = { "" },
  cursor = { 1, 0 },
  mode = "c",
  cmdline = "CmpFixture al",
  cmdpos = 14,
  snippet = false,
}
-- A search for "al" in "alpha a_long" moved on to the next match, "alpha", without a menu.
local SEARCH_MATCH = {
  menu = false,
  lines = { "alpha a_long" },
  cursor = { 1, 5 },
  mode = "c",
  cmdline = "alpha",
  cmdpos = 6,
  snippet = false,
}
-- Tab in that search: the next match, without a completion menu.
local SEARCH_TAB = { cmdline = "alpha", menu = false, selected = false, labels = {} }

return {
  {
    name = "cmdline_enter",
    steps = { ":", "CmpFixture ", "al" },
    expect = {
      vim.tbl_extend("force", CLOSED, { cmdline = "", cmdpos = 1 }),
      vim.tbl_extend("force", MENU, { cmdline = "CmpFixture ", cmdpos = 12 }),
      MENU,
    },
  },
  {
    name = "cmdline_navigation",
    steps = { ":CmpFixture al", "<Tab>", "<Tab>", "<Tab>", "<C-e>" },
    expect = {
      MENU,
      vim.tbl_extend("force", MENU, { selected = "alpha", cmdline = "CmpFixture alpha", cmdpos = 17 }),
      PREVIEW,
      MENU,
      CLOSED,
    },
  },
  {
    name = "cmdline_single_tab",
    options = { cmd_items = { "alpha" } },
    steps = { ":CmpFixture al", "<Tab>", "<Tab>" },
    expect = {
      { menu = true, selected = false },
      { menu = false, cmdline = "CmpFixture alpha", cmdpos = 17 },
      { menu = true, labels = { "alpha" } },
    },
  },
  {
    name = "cmdline_cursor",
    steps = { ":CmpFixture al", "<Left>", "<Right>", "<End>" },
    expect = { MENU, PREVIEW, MENU, CLOSED },
  },
  {
    name = "cmdline_hidden_cursor",
    steps = { ":CmpFixture al", "<C-e>", "<Left>", "<Right>" },
    expect = {
      MENU,
      CLOSED,
      vim.tbl_extend("force", CLOSED, { cmdpos = 13 }),
      CLOSED,
    },
  },
  {
    name = "cmdline_empty_tab",
    options = { cmd_items = {} },
    steps = { ":CmpFixture al", "<Tab>" },
    expect = { CLOSED, CLOSED },
  },
  {
    name = "cmdline_cancel_and_type",
    steps = { ":CmpFixture al", "<Tab>", "<C-e>x" },
    expect = { [3] = { cmdline = "CmpFixture alx", cmdpos = 15, menu = true } },
  },
  {
    name = "cmdline_accept_and_leave",
    steps = { ":CmpFixture al", "<C-y><CR>" },
    expect = { [2] = { commands = { "CmpFixture alpha" }, mode = "n" } },
  },
  {
    name = "cmdline_fallback_order",
    steps = { ":CmpFixture al", "<C-e>", "<Left><End>p" },
    expect = { [3] = { cmdline = "CmpFixture alp", cmdpos = 15 } },
  },
  {
    name = "cmdline_mapping_fallback",
    options = { mappings = { { mode = "c", key = "<C-j>", result = "x" } } },
    steps = { ":CmpFixture al", "<C-e>", "<C-j>z" },
    expect = {
      [3] = {
        cmdline = "CmpFixture alxz",
        fallback_calls = { "<C-j>" },
        menu = true,
        labels = { "alpha", "alpine" },
      },
    },
  },
  {
    name = "search_tab",
    options = { lines = { "alpha a_long" } },
    steps = { "/al", "<Tab>", "<C-e>" },
    expect = {
      { menu = false, cmdline = "al", cursor = { 1, 2 } },
      { menu = false, cmdline = "alpha", cursor = { 1, 5 }, labels = {}, selected = false },
      { menu = false, cmdline = "alpha", cmdpos = 6, cursor = { 1, 5 } },
    },
  },
  {
    name = "search_shift_tab",
    options = { lines = { "alpha a_long" } },
    steps = { "/al", "<S-Tab>", "<C-e>" },
    expect = {
      [2] = SEARCH_TAB,
      [3] = { cmdline = "alpha", cmdpos = 6, cursor = { 1, 5 } },
    },
  },
  {
    name = "search_backward",
    options = { lines = { "alpha a_long" } },
    steps = { "?al", "<Tab>", "<C-e>" },
    expect = {
      {
        menu = false,
        lines = { "alpha a_long" },
        cursor = { 1, 2 },
        mode = "c",
        cmdline = "al",
        cmdpos = 3,
        snippet = false,
      },
      SEARCH_MATCH,
      SEARCH_MATCH,
    },
  },
  {
    name = "search_hidden_accept",
    options = { lines = { "alpha a_long" } },
    steps = { "/al", "<C-y>" },
    expect = { [2] = { cmdline = "al\25", cmdpos = 4, menu = false } },
  },
  {
    name = "search_hidden_cancel",
    options = { lines = { "alpha a_long" } },
    steps = { "/al", "<Left>", "<C-e>", "<Tab>" },
    expect = {
      [3] = { cmdline = "al", cmdpos = 3, menu = false },
      [4] = SEARCH_TAB,
    },
  },
}
