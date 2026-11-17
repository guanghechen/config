require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Keysheet = require("era.view.keysheet")

t:test("a buffer keysheet merges modes and leaves out scopes, which-key prefixes and no-ops", function()
  local bufnr = t:buffer()
  ---@param modes                       string|string[]
  ---@param lhs                         string
  ---@param desc                        string
  ---@return nil
  local function map(modes, lhs, desc)
    vim.keymap.set(modes, lhs, function() end, { buf = bufnr, desc = desc })
  end
  map({ "n", "x" }, "oa", "picker#result: add to ai")
  map("n", "R", "Git Files: refresh")
  map("n", "[i", "Treeview parent")
  map("n", "t7", "era.fn.find_files: era.fn.find_files: toggle exclude")
  map("n", "p1", "diffview(commits): Layout 1: commits top")
  map("n", "g", "wk-trigger")
  map("n", "<Tab>", "searcher#result: noop")

  local entries = {} ---@type string[]
  for _, keymap in ipairs(Keysheet.for_buffer({ bufnr = bufnr, title = "Git Files" })._keymaps) do
    entries[#entries + 1] = keymap.key .. " " .. table.concat(keymap.modes, ",") .. " " .. keymap.desc
  end
  t.assert_same({
    "R n refresh",
    "[i n parent",
    "oa n,x add to ai",
    "p1 n Layout 1: commits top",
    "t7 n toggle exclude",
  }, entries)
end)

t:test("a keysheet opens above the floating window it is asked from", function()
  t:window(t:buffer(), { relative = "editor", row = 0, col = 0, width = 20, height = 3, zindex = 51 }, true)
  local sheet = Keysheet.new({ keymaps = { { modes = { "n" }, key = "q", desc = "close", callback = "" } } })
  t:defer(function()
    sheet:dispose()
  end)
  sheet:open()
  t.assert_true(vim.api.nvim_win_get_config(assert(sheet._winnr)).zindex > 51, "above a picker window")
end)

t:run()
