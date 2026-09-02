---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/modal_focus.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.modal_focus")

bootstrap.with_global(t, "dot", {
  context = {
    theme = {
      get_float_winblend = function()
        return 0
      end,
    },
  },
  var = {
    N_WINLINE_DISABLED = "test_winline_disabled",
    nsnr = {
      input_confirmation = vim.api.nvim_create_namespace("test:modal-focus:input"),
    },
    sign = {
      GROUP_CHOICES_CURRENT = "test_modal_focus",
      NR_CHOICES_CURRENT = 1,
      CHOICES_CURRENT = "TestModalFocus",
    },
  },
  win = {
    resolve_zindex = function()
      return 50
    end,
  },
})

bootstrap.with_global(t, "stl", {
  e = {
    WinTypeEnum = {
      INPUT = "input",
      SELECT = "select",
    },
  },
  filetype = {
    UX_INPUT = "ux-input",
  },
  fn = {
    noop = function() end,
  },
  icon = {
    ui = {
      Edit = "E",
    },
  },
  nvim = {
    fn = {
      bindkeys = function() end,
    },
  },
})

vim.fn.sign_define("TestModalFocus", { text = ">", texthl = "Normal" })

local input = assert(loadfile("lua/era/m/input.lua"))()
local select_view = assert(loadfile("lua/era/m/select/view.lua"))()

---@param winnr                         integer
---@return nil
local function register_window(winnr)
  ---@diagnostic disable-next-line: invisible
  t:_register_cleanup(function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
end

---@return integer, integer
local function create_window_pair()
  local parent_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vsplit")
  local other_winnr = vim.api.nvim_get_current_win() ---@type integer
  register_window(other_winnr)
  vim.api.nvim_set_current_win(parent_winnr)
  return parent_winnr, other_winnr
end

---@return integer, integer, integer
local function create_window_triplet()
  local origin_winnr, anchor_winnr = create_window_pair()
  vim.api.nvim_set_current_win(anchor_winnr)
  vim.cmd("vsplit")
  local third_winnr = vim.api.nvim_get_current_win() ---@type integer
  register_window(third_winnr)
  vim.api.nvim_set_current_win(origin_winnr)
  return origin_winnr, anchor_winnr, third_winnr
end

---@param title                         string
---@param on_choice                     ?fun(): nil
---@return integer
local function open_select(title, on_choice)
  return select_view.open({
    title = title,
    items = { { key = "1", text = "one" } },
    on_choice = on_choice or function() end,
  })
end

t:test("input keeps a user-selected window after BufLeave cancellation", function()
  local _, other_winnr = create_window_pair()
  local callback_winnr = nil ---@type integer|nil
  local input_winnr = input.open({ prompt = "Race", startinsert = false }, function()
    callback_winnr = vim.api.nvim_get_current_win()
  end)

  vim.api.nvim_set_current_win(other_winnr)
  t.wait_until(function()
    return not vim.api.nvim_win_is_valid(input_winnr) and callback_winnr ~= nil
  end, 100, "input window was not disposed")

  t.assert_eq(other_winnr, vim.api.nvim_get_current_win(), "current window")
  t.assert_eq(other_winnr, callback_winnr, "callback window")
end)

t:test("input does not restore a cursor into a replacement parent buffer", function()
  local parent_winnr, other_winnr = create_window_pair()
  local parent_bufnr = vim.api.nvim_win_get_buf(parent_winnr) ---@type integer
  vim.api.nvim_buf_set_lines(parent_bufnr, 0, -1, false, { "1", "2", "3", "4", "5", "6", "7", "8" })
  vim.api.nvim_win_set_cursor(parent_winnr, { 8, 0 })

  local input_winnr = input.open({ prompt = "Race", startinsert = false }, function() end)
  local replacement_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  ---@diagnostic disable-next-line: invisible
  t:_register_cleanup(function()
    if vim.api.nvim_win_is_valid(parent_winnr) and vim.api.nvim_buf_is_valid(parent_bufnr) then
      vim.api.nvim_win_set_buf(parent_winnr, parent_bufnr)
    end
    if vim.api.nvim_buf_is_valid(replacement_bufnr) then
      vim.api.nvim_buf_delete(replacement_bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_lines(replacement_bufnr, 0, -1, false, { "a", "b", "c", "d", "e", "f", "g", "h" })
  vim.api.nvim_win_set_buf(parent_winnr, replacement_bufnr)
  vim.api.nvim_set_current_win(other_winnr)

  t.wait_until(function()
    return not vim.api.nvim_win_is_valid(input_winnr)
  end, 100, "input window was not disposed")

  t.assert_eq(replacement_bufnr, vim.api.nvim_win_get_buf(parent_winnr), "parent buffer")
  t.assert_eq(1, vim.api.nvim_win_get_cursor(parent_winnr)[1], "replacement cursor line")
  t.assert_eq(other_winnr, vim.api.nvim_get_current_win(), "current window")
end)

t:test("input retains deferred focus after nvim_win_call", function()
  local origin_winnr, anchor_winnr = create_window_pair()
  local input_winnr ---@type integer
  local callback_winnr = nil ---@type integer|nil

  vim.api.nvim_win_call(anchor_winnr, function()
    input_winnr = input.open({ prompt = "Call", startinsert = false }, function()
      callback_winnr = vim.api.nvim_get_current_win()
    end)
  end)

  t.wait_until(function()
    return vim.api.nvim_get_current_win() == input_winnr
  end, 100, "input did not receive deferred focus")
  t.assert_true(vim.api.nvim_win_is_valid(input_winnr), "input window")

  vim.api.nvim_win_close(input_winnr, true)
  t.wait_until(function()
    return callback_winnr ~= nil
  end, 100, "input callback was not delivered")
  t.assert_eq(origin_winnr, vim.api.nvim_get_current_win(), "origin window")
  t.assert_eq(origin_winnr, callback_winnr, "callback window")
end)

t:test("input cancels deferred focus after entering a third window", function()
  local _, anchor_winnr, third_winnr = create_window_triplet()
  local input_winnr ---@type integer
  local callback_winnr = nil ---@type integer|nil

  vim.api.nvim_win_call(anchor_winnr, function()
    input_winnr = input.open({ prompt = "Call", startinsert = false }, function()
      callback_winnr = vim.api.nvim_get_current_win()
    end)
  end)
  vim.api.nvim_set_current_win(third_winnr)

  t.wait_until(function()
    return not vim.api.nvim_win_is_valid(input_winnr) and callback_winnr ~= nil
  end, 100, "input deferred focus was not cancelled")
  t.assert_eq(third_winnr, vim.api.nvim_get_current_win(), "current window")
  t.assert_eq(third_winnr, callback_winnr, "callback window")
end)

t:test("select keeps a user-selected window after BufLeave cancellation", function()
  local _, other_winnr = create_window_pair()
  local callback_winnr = nil ---@type integer|nil
  local select_winnr = open_select("Race", function()
    callback_winnr = vim.api.nvim_get_current_win()
  end)

  vim.api.nvim_set_current_win(other_winnr)
  t.wait_until(function()
    return not vim.api.nvim_win_is_valid(select_winnr) and callback_winnr ~= nil
  end, 100, "select window was not disposed")

  t.assert_eq(other_winnr, vim.api.nvim_get_current_win(), "current window")
  t.assert_eq(other_winnr, callback_winnr, "callback window")
end)

t:test("select retains deferred focus after nvim_win_call", function()
  local origin_winnr, anchor_winnr = create_window_pair()
  local select_winnr ---@type integer
  local callback_winnr = nil ---@type integer|nil

  vim.api.nvim_win_call(anchor_winnr, function()
    select_winnr = open_select("Call", function()
      callback_winnr = vim.api.nvim_get_current_win()
    end)
  end)

  t.wait_until(function()
    return vim.api.nvim_get_current_win() == select_winnr
  end, 100, "select did not receive deferred focus")
  t.assert_true(vim.api.nvim_win_is_valid(select_winnr), "select window")

  vim.api.nvim_win_close(select_winnr, true)
  t.wait_until(function()
    return callback_winnr ~= nil
  end, 100, "select callback was not delivered")
  t.assert_eq(origin_winnr, vim.api.nvim_get_current_win(), "origin window")
  t.assert_eq(origin_winnr, callback_winnr, "callback window")
end)

t:test("select cancels deferred focus after entering a third window", function()
  local _, anchor_winnr, third_winnr = create_window_triplet()
  local select_winnr ---@type integer
  local callback_winnr = nil ---@type integer|nil

  vim.api.nvim_win_call(anchor_winnr, function()
    select_winnr = open_select("Call", function()
      callback_winnr = vim.api.nvim_get_current_win()
    end)
  end)
  vim.api.nvim_set_current_win(third_winnr)

  t.wait_until(function()
    return not vim.api.nvim_win_is_valid(select_winnr) and callback_winnr ~= nil
  end, 100, "select deferred focus was not cancelled")
  t.assert_eq(third_winnr, vim.api.nvim_get_current_win(), "current window")
  t.assert_eq(third_winnr, callback_winnr, "callback window")
end)

t:run()
