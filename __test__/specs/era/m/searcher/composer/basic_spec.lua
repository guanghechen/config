require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

---A permanent searcher that <F5> focuses from a source window of two lines, the cursor at column 6.
---@return __test__.support.UI
local function session()
  local ui = require("__test__.support.ui").open(t, { width = 100, height = 32, runtime = "ark" })
  ui:lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = 1", "local other = 2" })
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    source_winnr = vim.api.nvim_get_current_win()
    local props = { name = "mode searcher", title = "mode searcher", permanent = true, preview = false }
    for key, value in pairs({
      excludes = {},
      flag_exclude = false,
      flag_foldempty = false,
      flag_gitignore = false,
      flag_limit_matches = true,
      flag_regex = false,
      flag_replace = false,
      flag_case_sensitive = true,
      flag_selected = false,
      flag_viewtype = "tree",
      includes = { "*.txt" },
      max_filesize = "1M",
      max_matches = 500,
      replace_pattern = "",
      rootpath = vim.fn.getcwd(),
      search_pattern = "",
    }) do
      props[key] = stl.c.Observable.from_value(value)
    end
    searcher = era.m.searcher.FiletreeComposer.new(props)
    vim.keymap.set({ "n", "i" }, "<F5>", function()
      searcher:focus()
    end)
  ]])
  return ui
end

---@param ui                            __test__.support.UI
---@param keys                          string
---@param condition                     string Lua expression that holds once the keys took effect.
---@return nil
local function press(ui, keys, condition)
  ui:rpc("nvim_input", keys)
  ui:wait_lua("return " .. condition, 5000, keys .. " did not reach: " .. condition)
end

---Focuses the result from the finder in Insert mode and closes the searcher there.
---@param ui                            __test__.support.UI
---@return nil
local function close_from_result(ui)
  press(ui, "<F5>", "vim.api.nvim_get_current_win() ~= source_winnr")
  if ui:lua("return vim.api.nvim_get_mode().mode") ~= "i" then
    press(ui, "i", "vim.api.nvim_get_mode().mode == 'i'")
  end
  press(ui, "<M-j>", "vim.api.nvim_get_current_win() == searcher.result:get_winnr()")
  press(ui, "<M-q>", "vim.api.nvim_get_current_win() == source_winnr")
end

t:test("a searcher opened from Normal mode returns to Normal mode when it closes in Insert mode", function()
  local ui = session()

  close_from_result(ui)

  t.assert_eq("n", ui:lua("return vim.api.nvim_get_mode().mode"), "Insert mode from the finder does not carry over")
  t.assert_same({ 1, 6 }, ui:lua("return vim.api.nvim_win_get_cursor(source_winnr)"), "the cursor keeps its column")
end)

t:test("a searcher opened from Insert mode returns to Insert mode", function()
  local ui = session()
  press(ui, "i", "vim.api.nvim_get_mode().mode == 'i'")

  close_from_result(ui)

  t.assert_eq("i", ui:lua("return vim.api.nvim_get_mode().mode"), "Insert mode is resumed")
end)

t:run()
