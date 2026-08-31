---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/fold.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.fold")

local layout = assert(loadfile("lua/era/m/diffview/layout.lua"))()

---@param winnr                         integer
---@param command                       string
local function normal(winnr, command)
  vim.api.nvim_win_call(winnr, function()
    vim.cmd("normal! " .. command)
  end)
end

---@param winnr                         integer
---@return boolean
local function is_fold_closed(winnr)
  return vim.api.nvim_win_call(winnr, function()
    return vim.fn.foldclosed(1) ~= -1
  end)
end

---@param winnr                         integer
---@param lines                         string[]
---@return integer
local function setup_fold_buffer(winnr, lines)
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_set_option_value("foldenable", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldmethod", "manual", { win = winnr, scope = "local" })
  vim.api.nvim_win_call(winnr, function()
    vim.cmd("1,3fold")
  end)
  return bufnr
end

t:test("side-by-side fold toggle derives state and preserves panel focus", function()
  local panel_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("belowright split")
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("belowright split")
  local right_winnr = vim.api.nvim_get_current_win() ---@type integer
  local lines = { "one", "two", "three", "four", "five" }
  local left_bufnr = setup_fold_buffer(left_winnr, lines) ---@type integer
  local right_bufnr = setup_fold_buffer(right_winnr, lines) ---@type integer

  t:_register_cleanup(function()
    for _, winnr in ipairs({ right_winnr, left_winnr }) do
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
    end
    for _, bufnr in ipairs({ right_bufnr, left_bufnr }) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    if vim.api.nvim_win_is_valid(panel_winnr) then
      vim.api.nvim_set_current_win(panel_winnr)
    end
  end)

  normal(left_winnr, "zM")
  normal(right_winnr, "zM")
  vim.api.nvim_set_current_win(panel_winnr)
  layout.toggle_all_folds(left_winnr, right_winnr)
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after expand")
  t.assert_false(is_fold_closed(left_winnr), "left expanded")
  t.assert_false(is_fold_closed(right_winnr), "right expanded")

  layout.toggle_all_folds(left_winnr, right_winnr)
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after collapse")
  t.assert_true(is_fold_closed(left_winnr), "left collapsed")
  t.assert_true(is_fold_closed(right_winnr), "right collapsed")

  normal(left_winnr, "zR")
  layout.toggle_all_folds(left_winnr, right_winnr)
  t.assert_false(is_fold_closed(left_winnr), "mixed left expanded")
  t.assert_false(is_fold_closed(right_winnr), "mixed right expanded")
end)

t:test("Changes zR toggles the preview while SBS zR keeps native open-all behavior", function()
  local calls = {} ---@type string[]
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", {
    open_all_folds = function()
      calls[#calls + 1] = "open"
    end,
    toggle_all_folds = function()
      calls[#calls + 1] = "toggle"
    end,
  })
  t:patch_table(package.loaded, "era.m.git.visual", {})

  local keymap = assert(loadfile("lua/era/m/diffview/view/workspace/keymap.lua"))()
  local ctx = {} ---@type era.m.diffview.view.workspace.IContext
  for _, candidate in ipairs(keymap.gen_changes(ctx)) do
    if candidate.key == "zR" then
      candidate.callback()
    end
  end
  for _, candidate in ipairs(keymap.gen_sbs(ctx)) do
    if candidate.key == "zR" then
      candidate.callback()
    end
  end

  t.assert_eq("toggle,open", table.concat(calls, ","), "zR scope")
end)

t:run()
