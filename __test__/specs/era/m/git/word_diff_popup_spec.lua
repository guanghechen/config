---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.git.word_diff_popup" ---@type string

local harness = require("__test__.support.harness")
local bootstrap = require("__test__.support.bootstrap")
local diff = require("era.m.git.diff")
local reference = assert(loadfile("__test__/fixtures/era/m/git/diff_lua_reference.lua"))()
local Hunkview = require("era.m.git.hunkview")
local t = harness.new("era.m.git.word_diff_popup")

bootstrap.with_runtime(t, {
  stl = {
    icon = { git = { Diff = "G" } },
    nvim = { fn = require("stl.nvim.fn") },
  },
  dot = { context = { theme = {
    get_float_winblend = function()
      return 0
    end,
  } } },
  era = { m = { git = { diff = diff } } },
})

---@param bufnr                         integer
---@return table
local function capture(bufnr)
  local ranges = {}
  local ns = assert(vim.api.nvim_get_namespaces().board_git_hunk)
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })) do
    ranges[#ranges + 1] = { mark[2], mark[3], mark[4] }
  end
  return {
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    ranges = ranges,
    modifiable = vim.api.nvim_get_option_value("modifiable", { buf = bufnr }),
    readonly = vim.api.nvim_get_option_value("readonly", { buf = bufnr }),
  }
end

t:test("real popup text, byte highlights and cleanup match the Lua renderer input", function()
  local source_bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    if vim.api.nvim_buf_is_valid(source_bufnr) then
      vim.api.nvim_buf_delete(source_bufnr, { force = true })
    end
  end)
  vim.api.nvim_set_current_buf(source_bufnr)
  for _, case in ipairs({
    {
      { "fooBar", "local 文本 = '你好🙂'", "tail", "" },
      { "fooBaz", "local 文本 = '您好🙃'", "tail", "" },
    },
    { { "a\0\255Z", "" }, { "a\0\254Y", "" } },
    { { string.rep("a", 499) .. "é", "" }, { string.rep("a", 499) .. "中", "" } },
    { { "a b", "" }, { "aXY b", "" } },
    { { "aXY b", "" }, { "a b", "" } },
    { { "" }, { "new", "" } },
    { { "old", "" }, { "" } },
  }) do
    local hunks = diff.run_diff(case[1], case[2])
    local source_lines = vim.list_slice(case[2], 1, math.max(1, #case[2] - 1))
    vim.api.nvim_buf_set_lines(source_bufnr, 0, -1, false, source_lines)
    local source_winnr = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(source_winnr, { 1, 0 })
    for _, hunk in ipairs(hunks) do
      local restore_buffer = bootstrap.with_era(t, {
        m = {
          git = {
            buffer = {
              is_attached = function()
                return true
              end,
              get_hunk_at = function()
                return hunk
              end,
            },
          },
        },
      })
      local results = {}
      for index = 1, 2 do
        local restore = index == 1 and t:patch_table(diff, "compute_hunk_word_diff", reference.compute_hunk_word_diff)
          or nil
        local view = Hunkview.new({ bufnr = source_bufnr })
        t:defer(function()
          view:dispose()
        end)
        view:open()
        t.assert_true(view:isvisible(), "popup opened through its public API")
        local popup_bufnr = vim.api.nvim_get_current_buf()
        t.assert_true(popup_bufnr ~= source_bufnr, "real floating buffer")
        results[index] = capture(popup_bufnr)
        local close_key
        for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(popup_bufnr, "n")) do
          if keymap.lhs == "q" then
            close_key = keymap.callback
          end
        end
        t.assert_true(type(close_key) == "function", "real close keymap installed")
        close_key()
        t.assert_false(view:isvisible(), "close key callback hides popup")
        t.assert_false(vim.api.nvim_buf_is_valid(popup_bufnr), "popup buffer released")
        if restore then
          restore()
        end
      end
      t.assert_true(vim.deep_equal(results[1], results[2]), vim.inspect(results))
      t.assert_false(results[2].modifiable)
      t.assert_true(results[2].readonly)
      t.assert_true(
        vim.deep_equal(source_lines, vim.api.nvim_buf_get_lines(source_bufnr, 0, -1, false)),
        "source unchanged"
      )
      restore_buffer()
    end
  end
end)

t:run()
