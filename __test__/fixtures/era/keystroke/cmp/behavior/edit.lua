---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.cmp.behavior.edit" ---@type string

-- Completion behavior cases: payload, keys and the state each step must reach. The expectations were checked
-- against the frozen Blink 1.10.2 configuration during the migration; cases only the removed differential runner
-- covered had theirs recorded from Era when it was removed.

local AUTO_IMPORT = "import { foobar } from './lib';"

return {
  {
    name = "hide_preview",
    steps = { "ial", "<Down>", "<C-h>", "<C-h>" },
    expect = {
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpha",
        lines = { "al" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpine",
        lines = { "alpine" },
        cursor = { 1, 6 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "alpine" }, cursor = { 1, 6 }, mode = "i", snippet = false },
      { menu = false, lines = { "alpin" }, cursor = { 1, 5 }, mode = "i", snippet = false },
    },
  },
  {
    name = "cancel_preview",
    steps = { "ial", "<Down>", { action = "cancel" } },
    expect = {
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpha",
        lines = { "al" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpine",
        lines = { "alpine" },
        cursor = { 1, 6 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "al" }, cursor = { 1, 2 }, mode = "i", snippet = false },
    },
  },
  {
    name = "type_after_preview",
    steps = { "ial", "<Tab>", "x", "<Esc>" },
    expect = {
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpha",
        lines = { "al" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpine",
        lines = { "alpine" },
        cursor = { 1, 6 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "alpinex" }, cursor = { 1, 7 }, mode = "i", snippet = false },
      { menu = false, lines = { "alpinex" }, cursor = { 1, 6 }, mode = "n", snippet = false },
    },
  },
  {
    name = "backspace_after_preview",
    steps = { "ial", "<Tab>", "<BS>", "<C-h>" },
    expect = {
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpha",
        lines = { "al" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpine",
        lines = { "alpine" },
        cursor = { 1, 6 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "alpin" }, cursor = { 1, 5 }, mode = "i", snippet = false },
      { menu = false, lines = { "alpi" }, cursor = { 1, 4 }, mode = "i", snippet = false },
    },
  },
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
    expect = {
      [2] = { lines = { "import { foobar } from './lib';", "foobar" }, cursor = { 2, 6 }, snippet = false },
      [3] = { lines = { "import { foobar } from './lib';", "foobarx" } },
      [4] = { lines = { "fo" } },
      [5] = { lines = { "import { foobar } from './lib';", "foobarx" } },
    },
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
    expect = {
      [2] = { lines = { "import { foobar } from './lib';", "foobar(value)" }, cursor = { 2, 7 }, snippet = true },
      [3] = { lines = { "import { foobar } from './lib';", "foobar(x)" }, cursor = { 2, 7 } },
      [4] = { lines = { "import { foobar } from './lib';", "foobar(value)" }, cursor = { 2, 7 } },
      [5] = { lines = { "" }, snippet = false },
      [6] = { lines = { "import { foobar } from './lib';", "foobar(value)" }, snippet = false },
      [7] = { lines = { "import { foobar } from './lib';", "foobar(x)" }, cursor = { 2, 7 }, snippet = false },
    },
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
    expect = {
      [2] = { lines = { "import { foobar } from './lib';", "foobar()" }, cursor = { 2, 7 }, snippet = false },
      [3] = { lines = { "import { foobar } from './lib';", "foobar(x)" } },
      [4] = { lines = { "" } },
      [5] = { lines = { "import { foobar } from './lib';", "foobar(x)" } },
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
    expect = {
      [2] = { menu = false, lines = { "alpha", "-- trailing declaration" } },
      [3] = { lines = { "al" } },
      [4] = { lines = { "alpha", "-- trailing declaration" } },
    },
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
    expect = {
      { menu = true, labels = { "alpha", "alpha" }, menu_text = { "alpha(string): string", "alpha(number): number" } },
    },
  },
  {
    name = "documentation",
    options = { documentation = true },
    steps = { "ial", { wait_ms = 300 }, "<C-space>", "<C-space>", "<C-h>" },
    expect = {
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpha",
        lines = { "al" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpha",
        lines = { "al" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
        documentation = true,
      },
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpha",
        lines = { "al" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "alpha", "alpine" },
        selected = "alpha",
        lines = { "al" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
        documentation = true,
      },
      { menu = false, lines = { "al" }, cursor = { 1, 2 }, mode = "i", snippet = false },
    },
  },
  {
    name = "documentation_switch",
    options = { documentation = true },
    steps = { { keys = "ial", wait_ms = 350 }, { keys = "<Tab>", wait_ms = 120 }, "<C-h>" },
    expect = {
      [2] = { documentation = true, documentation_lines = { "alpine", "", "A stable completion description." } },
    },
  },
  {
    name = "documentation_scroll",
    options = { documentation = ("A documentation line.\n"):rep(50) },
    steps = { { keys = "ial", wait_ms = 350 }, "<C-f>", "<C-f>", "<C-b>", "<Tab>" },
    expect = {
      { documentation_topline = 1 },
      { documentation_topline = 5 },
      { documentation_topline = 9 },
      { documentation_topline = 5 },
      { documentation_topline = 1 },
    },
  },
  {
    name = "signature_toggle",
    options = { signature = true },
    steps = { "idemo(", "<C-p>", "<C-p>" },
    expect = {
      { menu = false, lines = { "demo(" }, cursor = { 1, 5 }, mode = "i", snippet = false, signature = true },
      { menu = false, lines = { "demo(" }, cursor = { 1, 5 }, mode = "i", snippet = false },
      { menu = false, lines = { "demo(" }, cursor = { 1, 5 }, mode = "i", snippet = false, signature = true },
    },
  },
  {
    name = "signature_fallback",
    options = { items = {} },
    steps = { "ial", "<C-p>" },
    expect = { [2] = { mode = "i", native_menu = false, lines = { "al" } } },
  },
  {
    name = "function_brackets",
    options = { items = { { label = "demo", kind = 3 } } },
    steps = { "ide", "<CR>" },
    expect = {
      {
        menu = true,
        labels = { "demo" },
        selected = "demo",
        lines = { "de" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "demo()" }, cursor = { 1, 5 }, mode = "i", snippet = false },
    },
  },
  {
    name = "text_snippet_existing_brackets",
    options = {
      lines = { "s()" },
      cursor = { 1, 0 },
      items = { { label = "sin", insertText = "sin", insertTextFormat = 2, kind = 3 } },
    },
    steps = { "ai", "<CR>", "x" },
    expect = {
      [2] = { lines = { "sin()" }, cursor = { 1, 4 }, snippet = false },
      [3] = { lines = { "sin(x)" }, cursor = { 1, 5 } },
    },
  },
  {
    name = "text_snippet_tab_fallback",
    options = { items = { { label = "sin", insertText = "sin", insertTextFormat = 2, kind = 3 } } },
    steps = { "isi", "<CR>", "<Tab>" },
    expect = {
      [2] = { lines = { "sin()" }, cursor = { 1, 4 }, snippet = false },
      [3] = { lines = { "sin(\t)" }, cursor = { 1, 5 }, snippet = false },
    },
  },
  {
    name = "text_snippet_undo",
    options = { items = { { label = "sin", insertText = "sin", insertTextFormat = 2, kind = 3 } } },
    steps = { "isi", "<CR>", "x<Esc>", "u" },
    expect = { [4] = { lines = { "" }, cursor = { 1, 0 }, snippet = false } },
  },
  {
    name = "text_snippet_repeat",
    options = {
      lines = { "", "" },
      cursor = { 1, 0 },
      items = { { label = "sin", insertText = "sin", insertTextFormat = 2, kind = 3 } },
    },
    steps = { "isi", "<CR>", "x<Esc>j0." },
    expect = { [3] = { lines = { "sin(x)", "sin(x)" }, mode = "n", snippet = false } },
  },
  {
    name = "function_preview",
    options = { items = { { label = "demo", kind = 3 } } },
    steps = { "ide", "<Down>", "<Down>", "<CR>" },
    expect = {
      {
        menu = true,
        labels = { "demo" },
        selected = "demo",
        lines = { "de" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "demo" },
        selected = false,
        lines = { "de" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "demo" },
        selected = "demo",
        lines = { "demo" },
        cursor = { 1, 4 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "demo()" }, cursor = { 1, 5 }, mode = "i", snippet = false },
    },
  },
  {
    name = "snippet_signature_preview_typing",
    options = {
      items = {
        { label = "normalize(value)", kind = 3, insertTextFormat = 2, insertText = "normalize(${1:value})$0" },
      },
    },
    steps = { "inor", "<Down>", "<Down>", "(" },
    expect = {
      {
        menu = true,
        labels = { "normalize(value)" },
        selected = "normalize(value)",
        lines = { "nor" },
        cursor = { 1, 3 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "normalize(value)" },
        selected = false,
        lines = { "nor" },
        cursor = { 1, 3 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "normalize(value)" },
        selected = "normalize(value)",
        lines = { "normalize" },
        cursor = { 1, 9 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "normalize(" }, cursor = { 1, 10 }, mode = "i", snippet = false },
    },
  },
  {
    name = "snippet_alias_preview",
    options = {
      items = {
        { label = "fn", kind = 15, insertTextFormat = 2, insertText = "function ${1:name}(${2:args})\n\t$0\nend" },
      },
    },
    steps = { "if", "<Down>", "<Down>", "<CR>" },
    expect = {
      {
        menu = true,
        labels = { "fn" },
        selected = "fn",
        lines = { "f" },
        cursor = { 1, 1 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "fn" },
        selected = false,
        lines = { "f" },
        cursor = { 1, 1 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "fn" },
        selected = "fn",
        lines = { "function" },
        cursor = { 1, 8 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "function name(args)", "\t", "end" }, cursor = { 1, 9 }, mode = "s", snippet = true },
    },
  },
  {
    name = "snippet_preview",
    options = {
      items = { { label = "call", kind = 15, insertText = "call(${1:first}, ${2:second})$0", insertTextFormat = 2 } },
    },
    steps = { "ica", "<Down>", "<Down>", { wait_ms = 300 }, { action = "cancel" } },
    expect = {
      {
        menu = true,
        labels = { "call" },
        selected = "call",
        lines = { "ca" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "call" },
        selected = false,
        lines = { "ca" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "call" },
        selected = "call",
        lines = { "call" },
        cursor = { 1, 4 },
        mode = "i",
        snippet = false,
      },
      {
        menu = true,
        labels = { "call" },
        selected = "call",
        lines = { "call" },
        cursor = { 1, 4 },
        mode = "i",
        snippet = false,
        documentation = true,
      },
      { menu = false, lines = { "ca" }, cursor = { 1, 2 }, mode = "i", snippet = false },
    },
  },
  {
    name = "snippet_backwards",
    options = {
      items = { { label = "call", kind = 15, insertText = "call(${1:first}, ${2:second})$0", insertTextFormat = 2 } },
    },
    steps = { "ica", "<CR>", "<Tab>", "<S-Tab>" },
    expect = {
      {
        menu = true,
        labels = { "call" },
        selected = "call",
        lines = { "ca" },
        cursor = { 1, 2 },
        mode = "i",
        snippet = false,
      },
      { menu = false, lines = { "call(first, second)" }, cursor = { 1, 5 }, mode = "s", snippet = true },
      { menu = false, lines = { "call(first, second)" }, cursor = { 1, 12 }, mode = "s", snippet = true },
      { menu = false, lines = { "call(first, second)" }, cursor = { 1, 5 }, mode = "s", snippet = true },
    },
  },
  {
    name = "snippet_jump",
    options = {
      items = { { label = "call", kind = 15, insertText = "call(${1:first}, ${2:second})$0", insertTextFormat = 2 } },
    },
    steps = { "ica", "<CR>", "value", "<Tab>", "other", "<Tab>" },
    expect = { [6] = { lines = { "call(value, other)" }, cursor = { 1, 18 }, mode = "i", snippet = false } },
  },
}
