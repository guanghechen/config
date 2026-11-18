require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Keysheet = require("era.view.keysheet")

t:test("a buffer keysheet names keys as mapped and drops scopes, which-key prefixes and no-ops", function()
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
  map("n", "<C-j>", "picker#finder: focus next item")
  map("n", "<C-i>", "picker#finder: history backward")

  local entries = {} ---@type string[]
  for _, keymap in ipairs(Keysheet.for_buffer({ bufnr = bufnr, title = "Git Files" })._keymaps) do
    entries[#entries + 1] = keymap.key .. " " .. table.concat(keymap.modes, ",") .. " " .. keymap.desc
  end
  t.assert_same({
    "<C-I> n history backward",
    "<C-J> n focus next item",
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

t:test("a keysheet opened from Insert mode takes its keys in Normal mode", function()
  local ui = require("__test__.support.ui").open(t, { width = 80, height = 24, runtime = "ark" })
  ui:lua([[
    vim.keymap.set("i", "<F5>", function()
      require("era.view.keysheet").new({ keymaps = {} }):open()
    end)
  ]])
  ui:rpc("nvim_input", "i<F5>")
  ui:wait_lua("return vim.bo.filetype == 'board' and vim.api.nvim_get_mode().mode == 'n'", 5000, "Normal mode sheet")
  ui:rpc("nvim_input", "q")
  ui:wait_lua("return vim.bo.filetype ~= 'board'", 5000, "q closes the sheet")
end)

t:run()
