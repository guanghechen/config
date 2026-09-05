--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/foldtext_spec.lua
---@diagnostic disable: undefined-global
-- cspell:ignore foldtextresult multibyte

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.foldtext")
local module_name = "era.dressing.foldtext" ---@type string

bootstrap.with_runtime(t, {
  stl = {
    icon = {
      symbols = {
        sep_left = "<",
        sep_right = ">",
      },
    },
  },
})

t:patch_table(package.loaded, module_name, nil)

local Foldtext = require(module_name)

t:test("dressing initializes every existing window only once", function()
  local calls = {} ---@type table[]
  local list_wins_calls = 0 ---@type integer
  t:patch_table(vim.api, "nvim_list_wins", function()
    list_wins_calls = list_wins_calls + 1
    return { 11, 22 }
  end)
  t:patch_table(vim.api, "nvim_set_option_value", function(option, value, opts)
    calls[#calls + 1] = { option = option, value = value, opts = opts }
  end)

  Foldtext.dressing()
  Foldtext.dressing()

  local callback = "v:lua.era.dressing.foldtext.foldtext()" ---@type string
  t.assert_eq(1, list_wins_calls, "window enumeration")
  t.assert_eq(3, #calls, "foldtext writes")
  t.assert_eq("foldtext", calls[1].option, "global option")
  t.assert_eq(callback, calls[1].value, "global callback")
  t.assert_eq("global", calls[1].opts.scope, "global scope")
  t.assert_eq(11, calls[2].opts.win, "first window")
  t.assert_eq(22, calls[3].opts.win, "second window")
end)

t:test("foldtext preserves byte columns and separates uncaptured text", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local previous_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local previous_foldmethod = vim.api.nvim_get_option_value("foldmethod", { win = winnr }) ---@type string
  local previous_foldtext = vim.api.nvim_get_option_value("foldtext", { win = winnr }) ---@type string
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local chunks = nil ---@type table[]|nil
  local capture_cols = {} ---@type integer[]

  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "a\téc", "two", "three" })
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr })
  vim.api.nvim_set_option_value("tabstop", 4, { buf = bufnr })
  vim.cmd("1,3fold")

  t:patch_table(vim.treesitter, "get_captures_at_pos", function(_, row, col)
    t.assert_eq(0, row, "capture row")
    capture_cols[#capture_cols + 1] = col
    if col == 0 then
      return {
        { capture = "High", lang = "lua", metadata = { priority = 150 } },
        { capture = "Low", lang = "lua", metadata = { priority = 50 } },
      }
    end
    if col == 2 or col == 4 then
      return { { capture = "Last", lang = "lua", id = 3, metadata = { [3] = { priority = 120 } } } }
    end
    return {}
  end)
  t:patch_global("__test_foldtext", function()
    chunks = Foldtext.foldtext()
    return chunks
  end)
  vim.api.nvim_set_option_value("foldtext", "v:lua.__test_foldtext()", { win = winnr })

  local ok, err = pcall(function()
    vim.fn.foldtextresult(1)
    t.assert_true(chunks ~= nil, "foldtext chunks")
    ---@cast chunks table[]
    t.assert_eq(7, #chunks, "chunk count")
    t.assert_eq("a", chunks[1][1], "first text")
    t.assert_eq("@High.lua", chunks[1][2], "first highlight")
    t.assert_eq("   ", chunks[2][1], "expanded tab")
    t.assert_nil(chunks[2][2], "uncaptured highlight")
    t.assert_eq("éc", chunks[3][1], "last text")
    t.assert_eq("@Last.lua", chunks[3][2], "last highlight")
    t.assert_eq(4, #capture_cols, "capture count")
    t.assert_eq(0, capture_cols[1], "ascii column")
    t.assert_eq(1, capture_cols[2], "tab column")
    t.assert_eq(2, capture_cols[3], "multibyte column")
    t.assert_eq(4, capture_cols[4], "post-multibyte column")
  end)

  vim.api.nvim_set_option_value("foldtext", previous_foldtext, { win = winnr })
  vim.api.nvim_set_option_value("foldmethod", previous_foldmethod, { win = winnr })
  if vim.api.nvim_buf_is_valid(previous_bufnr) then
    vim.api.nvim_win_set_buf(winnr, previous_bufnr)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  if not ok then
    error(err, 0)
  end
end)
t:run()
