---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.dot.win.open_screen" ---@type string
local root = vim.uv.cwd()
local dir = assert(vim.env.OPEN_TEST_DIR)
vim.opt.runtimepath = { root, vim.env.VIMRUNTIME, vim.api.nvim__get_lib_dir() }
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
local harness = require("__test__.support.harness")
local t = harness.new("dot.win.open_screen.fixture")
t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
require("ark.bootstrap").setup_patches()
t:patch_global("dot", require("dot"))
t:patch_global("era", require("era"))
vim.t.tabtype = stl.e.TabTypeEnum.NORMAL
vim.o.swapfile = false
vim.o.hidden = true
vim.o.number = false
vim.o.relativenumber = false
vim.o.signcolumn = "no"
vim.o.foldcolumn = "0"
vim.o.foldenable = false
vim.o.laststatus = 0
vim.o.showtabline = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.cmdheight = 1
vim.o.shortmess = "atIF"
vim.o.wrap = false
vim.o.scrolloff = 0
vim.o.sidescrolloff = 0
vim.o.termguicolors = true
local main_winnr = vim.api.nvim_get_current_win()
local counts = {}
local hooks = {}
local result = { samples = {}, failures = {}, interceptions = {} }
vim.api.nvim_create_autocmd({ "BufReadPost", "FileType" }, {
  callback = function(ev)
    local path = vim.api.nvim_buf_get_name(ev.buf)
    if path:sub(1, #dir + 1) == dir .. "/" then
      counts[path] = counts[path] or { BufReadPost = 0, FileType = 0 }
      counts[path][ev.event] = counts[path][ev.event] + 1
    end
  end,
})
-- Deliberately precede ark's restoration handler, as third-party hooks may do.
vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function(ev)
    local path = vim.api.nvim_buf_get_name(ev.buf)
    local hook = hooks[path]
    if hook and vim.api.nvim_get_current_win() == hook.winnr then
      hooks[path] = nil
      result.interceptions[#result.interceptions + 1] = hook.kind
      hook.action(ev.buf)
    end
  end,
})
require("ark.autocmd")
vim.cmd("filetype plugin indent on")
local Win = dot.win
Win.resolve(main_winnr, true)
dot.tab.resolve(vim.api.nvim_get_current_tabpage(), true)
if vim.env.OPEN_TEST_SERVICES == "on" then
  era.dressing.scroll.dressing()
  era.dressing.indentline.dressing()
  era.dressing.indentscope.dressing()
end
local owned_files = {}
local other_winnr, other_bufnr
local initial_highlighter
local before
local scratch_winnr, scratch_bufnr
local wiped_bufnr, closed_bufnr

---@param name                          string
---@return string
local function path(name)
  local filepath = dir .. "/" .. name .. ".lua"
  if owned_files[filepath] == nil then
    owned_files[filepath] = vim.fn.readfile(filepath)
  end
  return filepath
end

---@param name                          string
---@return integer
local function bufnr(name)
  local value = assert(stl.nvim.buf.locate_bufnr(path(name)), "buffer not found: " .. name)
  return value
end

---@param value                         boolean
---@param message                       string
---@return nil
local function expect(value, message)
  assert(value, message)
end

---@param winnr                         integer
---@param expected_bufnr                integer
---@param line                          ?integer
---@param col                           ?integer
---@return nil
local function location(winnr, expected_bufnr, line, col)
  expect(vim.api.nvim_win_is_valid(winnr), "window is gone: " .. winnr)
  expect(vim.api.nvim_win_get_buf(winnr) == expected_bufnr, "window displays another buffer")
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  if line then
    expect(cursor[1] == line, "cursor line expected " .. line .. ", got " .. cursor[1])
  end
  if col then
    expect(cursor[2] == col, "cursor col expected " .. col .. ", got " .. cursor[2])
  end
  local pos = vim.fn.screenpos(winnr, cursor[1], cursor[2] + 1)
  expect(pos.row > 0 and pos.col > 0, "cursor is not visible")
  local text = vim.api.nvim_buf_get_lines(expected_bufnr, cursor[1] - 1, cursor[1], false)[1]
  if #text > 0 then
    local actual = vim.fn.screenstring(pos.row, pos.col)
    expect(actual == text:sub(cursor[2] + 1, cursor[2] + 1), "screen differs at cursor: " .. actual)
  end
end

---@param name                          string
---@param reads                         integer
---@param filetypes                     integer
---@return nil
local function events(name, reads, filetypes)
  local value = assert(counts[path(name)], "no events for " .. name)
  expect(
    value.BufReadPost == reads and value.FileType == filetypes,
    name .. " event counts: " .. vim.json.encode(value)
  )
end

---@return nil
local function untouched_other()
  location(other_winnr, other_bufnr, 5, 0)
end

local steps = {
  {
    name = "cold open restores real ShaDa mark",
    action = function()
      expect(Win.open_filepath(main_winnr, path("first")), "open failed")
    end,
    check = function()
      location(main_winnr, bufnr("first"), 80, 6)
      events("first", 1, 1)
      initial_highlighter = assert(vim.treesitter.highlighter.active[bufnr("first")], "highlighter missing")
    end,
  },
  {
    name = "reopen retains cursor and highlighter without initialization",
    action = function()
      vim.api.nvim_win_set_cursor(main_winnr, { 17, 2 })
      expect(Win.open_filepath(main_winnr, path("first")), "reopen failed")
    end,
    check = function()
      location(main_winnr, bufnr("first"), 17, 2)
      events("first", 1, 1)
      expect(initial_highlighter == vim.treesitter.highlighter.active[bufnr("first")], "highlighter was replaced")
    end,
  },
  {
    name = "explicit location on loaded file wins",
    action = function()
      Win.open_filepath(main_winnr, path("first"), 5, 3)
    end,
    check = function()
      location(main_winnr, bufnr("first"), 5, 3)
      events("first", 1, 1)
    end,
  },
  {
    name = "explicit location on cold file wins",
    action = function()
      Win.open_filepath(main_winnr, path("explicit"), 9, 2)
    end,
    check = function()
      location(main_winnr, bufnr("explicit"), 9, 2)
      events("explicit", 1, 1)
    end,
  },
  {
    name = "batch initializes once and restores last file",
    action = function()
      Win.open_filepaths(main_winnr, { path("batch_a"), path("batch_b"), path("batch_c") })
    end,
    check = function()
      location(main_winnr, bufnr("batch_c"), 80, 6)
      for _, name in ipairs({ "batch_a", "batch_b", "batch_c" }) do
        events(name, 1, 1)
      end
    end,
  },
  {
    name = "hidden batch file restores on first display",
    action = function()
      Win.open_filepath(main_winnr, path("batch_a"))
    end,
    check = function()
      location(main_winnr, bufnr("batch_a"), 80, 6)
      events("batch_a", 1, 1)
    end,
  },
  {
    name = "preload does not move current window",
    action = function()
      before = { bufnr = vim.api.nvim_win_get_buf(main_winnr), cursor = vim.api.nvim_win_get_cursor(main_winnr) }
      dot.buf.loadfile(path("preload"))
    end,
    check = function()
      location(main_winnr, before.bufnr, before.cursor[1], before.cursor[2])
      events("preload", 1, 1)
    end,
  },
  {
    name = "synchronous symbol navigation keeps cursor and view",
    action = function()
      vim.api.nvim_win_set_buf(main_winnr, bufnr("preload"))
      vim.api.nvim_win_set_cursor(main_winnr, { 23, 1 })
      vim.cmd("normal! zz")
      before = vim.fn.winsaveview()
    end,
    check = function()
      location(main_winnr, bufnr("preload"), 23, 1)
      expect(vim.fn.winsaveview().topline == before.topline, "explicit viewport changed")
    end,
  },
  {
    name = "native cold edit +1 keeps explicit line",
    action = function()
      vim.api.nvim_input(":edit +1 " .. vim.fn.fnameescape(path("native_plus")) .. "<CR>")
    end,
    check = function()
      location(main_winnr, bufnr("native_plus"), 1, nil)
    end,
  },
  {
    name = "native cold edit restores saved line",
    action = function()
      vim.api.nvim_input(":edit " .. vim.fn.fnameescape(path("native_default")) .. "<CR>")
    end,
    check = function()
      location(main_winnr, bufnr("native_default"), 80, 6)
    end,
  },
  {
    name = "enter insert before opening",
    mode = "i",
    action = function()
      vim.api.nvim_input("i")
    end,
    check = function()
      location(main_winnr, bufnr("native_default"), 80, 6)
    end,
  },
  {
    name = "opening from insert exits insert at requested location",
    action = function()
      Win.open_filepath(main_winnr, path("insert_open"), 12, 0)
    end,
    check = function()
      location(main_winnr, bufnr("insert_open"), 12, 0)
    end,
  },
  {
    name = "opening into inactive window preserves unrelated cursor",
    action = function()
      other_bufnr = vim.api.nvim_create_buf(false, true)
      local lines = {}
      for row = 1, 100 do
        lines[row] = "unrelated line " .. row
      end
      vim.api.nvim_buf_set_lines(other_bufnr, 0, -1, false, lines)
      other_winnr = vim.api.nvim_open_win(other_bufnr, true, { split = "right", win = main_winnr })
      vim.api.nvim_win_set_cursor(other_winnr, { 5, 0 })
      Win.open_filepath(main_winnr, path("first"), 15, 2)
    end,
    check = function()
      untouched_other()
      location(main_winnr, bufnr("first"), 15, 2)
    end,
  },
  {
    name = "earlier entry hook switching windows cannot redirect restoration",
    action = function()
      vim.api.nvim_set_current_win(main_winnr)
      hooks[path("redirect")] = {
        kind = "switch-window",
        winnr = main_winnr,
        action = function()
          vim.api.nvim_set_current_win(other_winnr)
        end,
      }
      Win.open_filepath(main_winnr, path("redirect"))
    end,
    check = function()
      untouched_other()
      expect(vim.api.nvim_win_get_buf(main_winnr) == bufnr("redirect"), "target file not displayed")
      expect(vim.b[bufnr("redirect")].eve_last_loc_winnr == nil, "unrelated window claimed")
    end,
  },
  {
    name = "earlier entry hook replacing buffer cannot redirect restoration",
    action = function()
      vim.api.nvim_set_current_win(main_winnr)
      hooks[path("replace")] = {
        kind = "replace-buffer",
        winnr = main_winnr,
        action = function()
          vim.api.nvim_win_set_buf(main_winnr, other_bufnr)
          vim.api.nvim_win_set_cursor(main_winnr, { 5, 0 })
        end,
      }
      Win.open_filepath(main_winnr, path("replace"))
    end,
    check = function()
      location(main_winnr, other_bufnr, 5, 0)
      untouched_other()
    end,
  },
  {
    name = "explicit navigation does not follow a replaced buffer",
    action = function()
      hooks[path("replace_explicit")] = {
        kind = "replace-before-explicit",
        winnr = main_winnr,
        action = function()
          vim.api.nvim_win_set_buf(main_winnr, other_bufnr)
          vim.api.nvim_win_set_cursor(main_winnr, { 5, 0 })
        end,
      }
      Win.open_filepath(main_winnr, path("replace_explicit"), 13, 2)
    end,
    check = function()
      location(main_winnr, other_bufnr, 5, 0)
      untouched_other()
    end,
  },
  {
    name = "closing target before scheduled navigation preserves surviving windows",
    action = function()
      vim.api.nvim_win_set_cursor(main_winnr, { 5, 0 })
      local winnr = vim.api.nvim_open_win(other_bufnr, true, { split = "below", win = main_winnr })
      Win.open_filepath(winnr, path("close"), 13, 2)
      closed_bufnr = bufnr("close")
      vim.api.nvim_win_close(winnr, true)
      vim.api.nvim_set_current_win(main_winnr)
    end,
    check = function()
      location(main_winnr, other_bufnr, 5, 0)
      untouched_other()
    end,
  },
  {
    name = "reenter after closed restoration window restores mark",
    action = function()
      Win.open_filepath(main_winnr, path("close"))
    end,
    check = function()
      location(main_winnr, closed_bufnr, 80, 6)
      untouched_other()
    end,
  },
  {
    name = "wiping target before deferred work preserves surviving windows",
    action = function()
      before = { bufnr = vim.api.nvim_win_get_buf(main_winnr), cursor = vim.api.nvim_win_get_cursor(main_winnr) }
      local winnr = vim.api.nvim_open_win(other_bufnr, true, { split = "below", win = main_winnr })
      Win.open_filepath(winnr, path("wipe"), 13, 2)
      wiped_bufnr = bufnr("wipe")
      vim.api.nvim_buf_delete(wiped_bufnr, { force = true })
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
      vim.api.nvim_set_current_win(main_winnr)
    end,
    check = function()
      expect(not vim.api.nvim_buf_is_valid(wiped_bufnr), "wiped buffer still valid")
      location(main_winnr, before.bufnr, before.cursor[1], before.cursor[2])
      untouched_other()
    end,
  },
  {
    name = "rapid opens cannot apply old coordinates to the next file",
    action = function()
      Win.open_filepath(main_winnr, path("rapid_a"), 7, 1)
      Win.open_filepath(main_winnr, path("rapid_b"))
    end,
    check = function()
      location(main_winnr, bufnr("rapid_b"), 80, 6)
    end,
  },
  {
    name = "rapid batch then single open cannot apply stale batch coordinates",
    action = function()
      Win.open_filepaths(main_winnr, { path("batch_x"), path("batch_y") }, 14, 2)
      Win.open_filepath(main_winnr, path("final"))
    end,
    check = function()
      location(main_winnr, bufnr("final"), 80, 6)
    end,
  },
  {
    name = "all missing batch leaves current cursor unchanged",
    action = function()
      before = { bufnr = vim.api.nvim_win_get_buf(main_winnr), cursor = vim.api.nvim_win_get_cursor(main_winnr) }
      Win.open_filepaths(main_winnr, { dir .. "/missing-a.lua", dir .. "/missing-b.lua" }, 12, 0)
    end,
    check = function()
      location(main_winnr, before.bufnr, before.cursor[1], before.cursor[2])
    end,
  },
  {
    name = "enter insert before invalid batch",
    mode = "i",
    action = function()
      vim.api.nvim_input("i")
    end,
    check = function() end,
  },
  {
    name = "all missing batch does not leave insert mode",
    mode = "i",
    action = function()
      before = { bufnr = vim.api.nvim_win_get_buf(main_winnr), cursor = vim.api.nvim_win_get_cursor(main_winnr) }
      Win.open_filepaths(main_winnr, { dir .. "/still-missing.lua" }, 12, 0)
    end,
    check = function()
      location(main_winnr, before.bufnr, before.cursor[1], before.cursor[2])
    end,
  },
  {
    name = "leave insert without editing",
    action = function()
      vim.api.nvim_input("<Esc>")
    end,
    check = function() end,
  },
  {
    name = "entry autocmd can close target without moving surviving windows",
    action = function()
      before = { bufnr = vim.api.nvim_win_get_buf(main_winnr), cursor = vim.api.nvim_win_get_cursor(main_winnr) }
      local winnr = vim.api.nvim_open_win(other_bufnr, true, { split = "below", win = main_winnr })
      hooks[path("autocmd_close")] = {
        kind = "close-target-window",
        winnr = winnr,
        action = function()
          vim.api.nvim_win_close(winnr, true)
        end,
      }
      Win.open_filepath(winnr, path("autocmd_close"), 13, 2)
      expect(not vim.api.nvim_win_is_valid(winnr), "entry handler did not close target")
      vim.api.nvim_set_current_win(main_winnr)
    end,
    check = function()
      location(main_winnr, before.bufnr, before.cursor[1], before.cursor[2])
      untouched_other()
    end,
  },
  {
    name = "existing unloaded buffer loads and restores once",
    action = function()
      local target = vim.fn.bufadd(path("unloaded"))
      expect(not vim.api.nvim_buf_is_loaded(target), "fixture already loaded")
      Win.open_filepath(main_winnr, path("unloaded"))
    end,
    check = function()
      location(main_winnr, bufnr("unloaded"), 80, 6)
      events("unloaded", 1, 1)
    end,
  },
  {
    name = "spaces and unicode in path preserve restoration",
    action = function()
      Win.open_filepath(main_winnr, path("space name_测试"))
    end,
    check = function()
      location(main_winnr, bufnr("space name_测试"), 80, 6)
    end,
  },
  {
    name = "truncated one-line file handles stale saved mark",
    action = function()
      Win.open_filepath(main_winnr, path("short"))
    end,
    check = function()
      location(main_winnr, bufnr("short"), 1, 0)
    end,
  },
  {
    name = "empty file handles stale saved mark",
    action = function()
      Win.open_filepath(main_winnr, path("empty"))
    end,
    check = function()
      location(main_winnr, bufnr("empty"), 1, 0)
    end,
  },
  {
    name = "scratch float keeps explicit cursor",
    action = function()
      scratch_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(scratch_bufnr, 0, -1, false, { "one", "two", "three", "four" })
      vim.api.nvim_buf_set_mark(scratch_bufnr, '"', 1, 0, {})
      scratch_winnr = vim.api.nvim_open_win(
        scratch_bufnr,
        true,
        { relative = "editor", row = 2, col = 2, width = 20, height = 4, style = "minimal" }
      )
      vim.api.nvim_win_set_cursor(scratch_winnr, { 4, 1 })
    end,
    check = function()
      location(scratch_winnr, scratch_bufnr, 4, 1)
      expect(vim.b[scratch_bufnr].eve_last_loc == nil, "scratch acquired restore state")
    end,
  },
  {
    name = "native cold edit +42 takes precedence over saved mark",
    action = function()
      vim.api.nvim_win_close(scratch_winnr, true)
      vim.api.nvim_buf_delete(scratch_bufnr, { force = true })
      vim.api.nvim_set_current_win(main_winnr)
      vim.api.nvim_input(":edit +42 " .. vim.fn.fnameescape(path("native_jump")) .. "<CR>")
    end,
    check = function()
      location(main_winnr, bufnr("native_jump"), 42, nil)
    end,
  },
  {
    name = "native explicit cursor command preserves row and column",
    action = function()
      vim.api.nvim_input(":edit +call\\ cursor(42,2) " .. vim.fn.fnameescape(path("native_cursor")) .. "<CR>")
    end,
    check = function()
      location(main_winnr, bufnr("native_cursor"), 42, 1)
    end,
  },
  {
    name = "startofline edit +1 moves to first column",
    action = function()
      vim.o.startofline = true
      vim.api.nvim_input(":edit +1 " .. vim.fn.fnameescape(path("native_start")) .. "<CR>")
    end,
    check = function()
      location(main_winnr, bufnr("native_start"), 1, 0)
    end,
  },
}

---@return table
local function snapshot()
  local windows = {}
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    windows[#windows + 1] = {
      winnr = winnr,
      bufnr = vim.api.nvim_win_get_buf(winnr),
      cursor = vim.api.nvim_win_get_cursor(winnr),
      info = vim.fn.getwininfo(winnr)[1],
    }
  end
  return { windows = windows, current_window = vim.api.nvim_get_current_win(), mode = vim.api.nvim_get_mode().mode }
end

---@return nil
local function finish()
  result.messages = vim.api.nvim_exec2("messages", { output = true }).output
  result.counts = counts
  result.files_unchanged = true
  for filepath, original in pairs(owned_files) do
    if not vim.deep_equal(vim.fn.readfile(filepath), original) then
      result.files_unchanged = false
    end
    local target = stl.nvim.buf.locate_bufnr(filepath)
    if target and vim.api.nvim_buf_is_loaded(target) then
      local lines = vim.api.nvim_buf_get_lines(target, 0, -1, false)
      local expected = #original == 0 and { "" } or original
      if not vim.deep_equal(lines, expected) then
        result.files_unchanged = false
      end
    end
  end
  vim.fn.writefile({ vim.json.encode(result) }, vim.env.OPEN_TEST_RESULT)
  vim.cmd("qa!")
end

local index = 0
---@return nil
local function advance()
  index = index + 1
  local step = steps[index]
  if not step then
    finish()
    return
  end
  local sample = { name = step.name }
  local ok, err = xpcall(step.action, debug.traceback)
  if not ok then
    sample.action_error = err
  end
  vim.defer_fn(function()
    local valid, reason = xpcall(function()
      expect(vim.api.nvim_get_mode().mode == (step.mode or "n"), "unexpected mode: " .. vim.api.nvim_get_mode().mode)
      step.check()
    end, debug.traceback)
    sample.ok = ok and valid
    if not sample.ok then
      result.failures[#result.failures + 1] = { name = step.name, error = sample.action_error or reason }
    end
    sample.state = snapshot()
    result.samples[#result.samples + 1] = sample
    vim.defer_fn(advance, 15)
  end, 350)
end
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(advance, 150)
  end,
})
