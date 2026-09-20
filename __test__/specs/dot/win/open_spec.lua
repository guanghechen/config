local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("dot.win.open")

bootstrap.with_runtime(t, {
  yoz = require("yoz"),
  stl = {
    e = require("stl.e"),
    env = { IS_WIN = vim.fn.has("win32") == 1 },
    nvim = { buf = require("stl.nvim.buf"), win = require("stl.nvim.win") },
    reporter = {
      error = function(details)
        error(vim.inspect(details))
      end,
    },
  },
  dot = {
    buf = require("dot.buf"),
    tab = { on_buf_enter = function() end },
  },
  era = { dressing = { scroll = { accept_current_view = function() end } } },
})

local Win = require("dot.win")
t:patch_table(Win, "on_buf_enter", function() end)
vim.cmd("filetype plugin indent on")
require("ark.autocmd")

---@return string
---@return table<string, integer>
local function new_file()
  local filepath = vim.fn.tempname() .. ".lua" ---@type string
  t:defer(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(bufnr) == filepath then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    vim.fn.delete(filepath)
  end)
  vim.fn.writefile({ "local value = 1", "", "return value", "" }, filepath)
  filepath = assert(vim.uv.fs_realpath(filepath))

  local counts = { BufReadPost = 0, FileType = 0 } ---@type table<string, integer>
  local group = vim.api.nvim_create_augroup("test_open_" .. filepath, { clear = true })
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(group)
  end)
  vim.api.nvim_create_autocmd({ "BufReadPost", "FileType" }, {
    group = group,
    callback = function(event)
      if vim.api.nvim_buf_get_name(event.buf) == filepath then
        counts[event.event] = counts[event.event] + 1
        if event.event == "BufReadPost" then
          vim.api.nvim_buf_set_mark(event.buf, '"', 3, 0, {})
        end
      end
    end,
  })
  return filepath, counts
end

---@return nil
local function settle()
  local done = false ---@type boolean
  vim.schedule(function()
    done = true
  end)
  t.wait_until(function()
    return done
  end, 1000, "scheduled opening work")
end

t:test("first display restores the saved cursor without replaying file initialization", function()
  local filepath, counts = new_file()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  t.assert_true(Win.open_filepath(winnr, filepath), "opened")
  settle()
  t.assert_eq(1, counts.BufReadPost, "one file read")
  t.assert_eq(1, counts.FileType, "one filetype initialization")
  t.assert_eq(3, vim.api.nvim_win_get_cursor(winnr)[1], "saved cursor restored in the displayed window")

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local highlighter = assert(vim.treesitter.highlighter.active[bufnr])
  vim.api.nvim_win_set_cursor(winnr, { 1, 0 })
  t.assert_true(Win.open_filepath(winnr, filepath), "reopened")
  settle()
  t.assert_eq(1, counts.BufReadPost, "no repeated read")
  t.assert_eq(1, counts.FileType, "no repeated initialization")
  t.assert_true(highlighter == vim.treesitter.highlighter.active[bufnr], "highlighter retained")
  t.assert_eq(1, vim.api.nvim_win_get_cursor(winnr)[1], "current cursor retained")
end)

t:test("explicit navigation takes precedence over the saved cursor", function()
  local filepath = new_file()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  t.assert_true(Win.open_filepath(winnr, filepath, 1, 2), "opened at location")
  settle()
  t.assert_true(vim.deep_equal({ 1, 2 }, vim.api.nvim_win_get_cursor(winnr)), "explicit location")
end)

t:test("synchronous symbol navigation takes precedence over first-display restoration", function()
  local filepath = new_file()
  local bufnr = assert(dot.buf.loadfile(filepath)) ---@type integer
  settle()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_win_set_cursor(winnr, { 4, 0 })
  vim.cmd("normal! zv zz")
  local view = vim.fn.winsaveview()
  settle()
  t.assert_eq(4, vim.api.nvim_win_get_cursor(winnr)[1], "symbol location retained")
  t.assert_eq(view.topline, vim.fn.winsaveview().topline, "symbol viewport retained")
  t.assert_true(vim.b[bufnr].eve_last_loc, "explicit navigation consumes the pending restoration")
end)

t:test("native buffer +1 takes precedence even when entry starts at line one", function()
  local filepath = new_file()
  local bufnr = assert(dot.buf.loadfile(filepath)) ---@type integer
  settle()
  vim.cmd("buffer +1 " .. bufnr)
  settle()
  t.assert_eq(1, vim.api.nvim_win_get_cursor(0)[1], "native +cmd retained")
end)

t:test("opening a multi-line scratch window preserves its explicit text cursor", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three", "four" })
  vim.api.nvim_buf_set_mark(bufnr, '"', 1, 0, {})
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 20,
    height = 4,
    style = "minimal",
  }) ---@type integer
  t:defer(function()
    vim.api.nvim_win_close(winnr, true)
  end)
  vim.api.nvim_win_set_cursor(winnr, { 4, 1 })
  settle()
  t.assert_true(vim.deep_equal({ 4, 1 }, vim.api.nvim_win_get_cursor(winnr)), "scratch text cursor retained")
  t.assert_nil(vim.b[bufnr].eve_last_loc, "scratch buffer has no file restoration state")
end)

t:test("batch opening initializes each file once and restores hidden files on first display", function()
  local first, first_counts = new_file()
  local last, last_counts = new_file()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  Win.open_filepaths(winnr, { first, last })
  settle()
  t.assert_eq(last, vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winnr)), "last file displayed")
  t.assert_eq(3, vim.api.nvim_win_get_cursor(winnr)[1], "last file saved cursor")
  t.assert_true(vim.deep_equal({ BufReadPost = 1, FileType = 1 }, first_counts), "first file initialized once")
  t.assert_true(vim.deep_equal({ BufReadPost = 1, FileType = 1 }, last_counts), "last file initialized once")

  t.assert_true(Win.open_filepath(winnr, first), "first file displayed later")
  settle()
  t.assert_eq(3, vim.api.nvim_win_get_cursor(winnr)[1], "hidden file saved cursor")
  t.assert_true(vim.deep_equal({ BufReadPost = 1, FileType = 1 }, first_counts), "hidden file not reinitialized")
end)

t:test("an earlier entry handler cannot redirect saved cursor restoration to another window", function()
  local filepath = new_file()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local other_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(other_bufnr) then
      vim.api.nvim_buf_delete(other_bufnr, { force = true })
    end
  end)
  vim.api.nvim_buf_set_lines(other_bufnr, 0, -1, false, { "one", "two", "three", "four", "five", "six" })
  local other_winnr = vim.api.nvim_open_win(other_bufnr, false, { split = "right", win = winnr }) ---@type integer
  t:defer(function()
    if vim.api.nvim_win_is_valid(other_winnr) then
      vim.api.nvim_win_close(other_winnr, true)
    end
  end)
  vim.api.nvim_win_set_cursor(other_winnr, { 5, 0 })

  local redirect = false ---@type boolean
  local group = vim.api.nvim_create_augroup("test_open_redirected_entry", { clear = true }) ---@type integer
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(group)
  end)
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    pattern = filepath,
    callback = function()
      if redirect then
        vim.api.nvim_set_current_win(other_winnr)
      end
    end,
  })
  -- Re-register restoration after the handler that changes the current window.
  dofile("lua/ark/autocmd.lua")
  local bufnr = assert(dot.buf.loadfile(filepath)) ---@type integer
  settle()

  redirect = true
  vim.api.nvim_win_set_buf(winnr, bufnr)
  t.assert_eq(5, vim.api.nvim_win_get_cursor(other_winnr)[1], "unrelated cursor is unchanged synchronously")
  settle()
  t.assert_eq(5, vim.api.nvim_win_get_cursor(other_winnr)[1], "unrelated cursor remains unchanged")
  t.assert_false(vim.b[bufnr].eve_last_loc, "restoration remains pending")
  t.assert_nil(vim.b[bufnr].eve_last_loc_winnr, "unrelated window is not claimed")

  redirect = false
  vim.api.nvim_win_set_buf(winnr, other_bufnr)
  -- Leaving the buffer records its current cursor; seed the next saved position.
  vim.api.nvim_buf_set_mark(bufnr, '"', 3, 0, {})
  vim.api.nvim_win_set_buf(winnr, bufnr)
  settle()
  t.assert_eq(3, vim.api.nvim_win_get_cursor(winnr)[1], "later entry restores the target window")
  t.assert_eq(5, vim.api.nvim_win_get_cursor(other_winnr)[1], "unrelated window stays untouched")
end)

for _, batch in ipairs({ false, true }) do
  t:test(
    (batch and "batch" or "single") .. " opening does not apply coordinates after the window changes buffers",
    function()
      local filepath = new_file()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local other_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      t:defer(function()
        vim.api.nvim_buf_delete(other_bufnr, { force = true })
      end)
      vim.api.nvim_buf_set_lines(other_bufnr, 0, -1, false, { "one", "two", "three", "four" })

      if batch then
        Win.open_filepaths(winnr, { filepath }, 3, 0)
      else
        t.assert_true(Win.open_filepath(winnr, filepath, 3, 0), "opened")
      end
      vim.api.nvim_win_set_buf(winnr, other_bufnr)
      vim.api.nvim_win_set_cursor(winnr, { 2, 1 })
      settle()
      t.assert_true(vim.deep_equal({ 2, 1 }, vim.api.nvim_win_get_cursor(winnr)), "replacement buffer cursor retained")
    end
  )
end

t:test("a batch with no existing files does not move the current cursor", function()
  local filepath = new_file()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  t.assert_true(Win.open_filepath(winnr, filepath), "opened")
  settle()

  Win.open_filepaths(winnr, { vim.fn.tempname() .. ".missing" }, 1, 0)
  settle()
  t.assert_eq(3, vim.api.nvim_win_get_cursor(winnr)[1], "no file opened, saved cursor retained")
end)

t:run()
