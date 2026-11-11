local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_global(t, "dot", {
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
  t:defer(function()
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

t:test("input does not restore a cursor into a replacement parent buffer", function()
  local parent_winnr, other_winnr = create_window_pair()
  local parent_bufnr = vim.api.nvim_win_get_buf(parent_winnr) ---@type integer
  vim.api.nvim_buf_set_lines(parent_bufnr, 0, -1, false, { "1", "2", "3", "4", "5", "6", "7", "8" })
  vim.api.nvim_win_set_cursor(parent_winnr, { 8, 0 })

  local input_winnr = input.open({ prompt = "Race", startinsert = false }, function() end)
  local replacement_bufnr = t:buffer({ "a", "b", "c", "d", "e", "f", "g", "h" })
  t:defer(function()
    if vim.api.nvim_win_is_valid(parent_winnr) and vim.api.nvim_buf_is_valid(parent_bufnr) then
      vim.api.nvim_win_set_buf(parent_winnr, parent_bufnr)
    end
  end)
  vim.api.nvim_win_set_buf(parent_winnr, replacement_bufnr)
  vim.api.nvim_set_current_win(other_winnr)

  t.wait_until(function()
    return not vim.api.nvim_win_is_valid(input_winnr)
  end, 5000, "input window was not disposed")

  t.assert_eq(replacement_bufnr, vim.api.nvim_win_get_buf(parent_winnr), "parent buffer")
  t.assert_eq(1, vim.api.nvim_win_get_cursor(parent_winnr)[1], "replacement cursor line")
  t.assert_eq(other_winnr, vim.api.nvim_get_current_win(), "current window")
end)

-- The input and the select window take the deferred focus and give it back alike.
for _, modal in ipairs({
  {
    kind = "input",
    ---@param prompt                    string
    ---@param on_done                   fun(): nil
    ---@return integer
    open = function(prompt, on_done)
      return input.open({ prompt = prompt, startinsert = false }, on_done)
    end,
  },
  { kind = "select", open = open_select },
}) do
  t:test(modal.kind .. " keeps a user-selected window after BufLeave cancellation", function()
    local _, other_winnr = create_window_pair()
    local callback_winnr = nil ---@type integer|nil
    local modal_winnr = modal.open("Race", function()
      callback_winnr = vim.api.nvim_get_current_win()
    end)

    vim.api.nvim_set_current_win(other_winnr)
    t.wait_until(function()
      return not vim.api.nvim_win_is_valid(modal_winnr) and callback_winnr ~= nil
    end, 5000, modal.kind .. " window was not disposed")

    t.assert_eq(other_winnr, vim.api.nvim_get_current_win(), "current window")
    t.assert_eq(other_winnr, callback_winnr, "callback window")
  end)

  t:test(modal.kind .. " retains deferred focus after nvim_win_call", function()
    local origin_winnr, anchor_winnr = create_window_pair()
    local modal_winnr ---@type integer
    local callback_winnr = nil ---@type integer|nil

    vim.api.nvim_win_call(anchor_winnr, function()
      modal_winnr = modal.open("Call", function()
        callback_winnr = vim.api.nvim_get_current_win()
      end)
    end)

    t.wait_until(function()
      return vim.api.nvim_get_current_win() == modal_winnr
    end, 5000, modal.kind .. " did not receive deferred focus")
    t.assert_true(vim.api.nvim_win_is_valid(modal_winnr), modal.kind .. " window")

    vim.api.nvim_win_close(modal_winnr, true)
    t.wait_until(function()
      return callback_winnr ~= nil
    end, 5000, modal.kind .. " callback was not delivered")
    t.assert_eq(origin_winnr, vim.api.nvim_get_current_win(), "origin window")
    t.assert_eq(origin_winnr, callback_winnr, "callback window")
  end)

  t:test(modal.kind .. " cancels deferred focus after entering a third window", function()
    local _, anchor_winnr, third_winnr = create_window_triplet()
    local modal_winnr ---@type integer
    local callback_winnr = nil ---@type integer|nil

    vim.api.nvim_win_call(anchor_winnr, function()
      modal_winnr = modal.open("Call", function()
        callback_winnr = vim.api.nvim_get_current_win()
      end)
    end)
    vim.api.nvim_set_current_win(third_winnr)

    t.wait_until(function()
      return not vim.api.nvim_win_is_valid(modal_winnr) and callback_winnr ~= nil
    end, 5000, modal.kind .. " deferred focus was not cancelled")
    t.assert_eq(third_winnr, vim.api.nvim_get_current_win(), "current window")
    t.assert_eq(third_winnr, callback_winnr, "callback window")
  end)
end

t:run()
