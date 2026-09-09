--- Full-config E2E: open a tracked file with an unstaged change hunk, then execute this fixture.
--- Disables context saving and exits the disposable Neovim process without saving buffers.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.git.word_diff_runtime" ---@type string

dot.context.save_on_exit = function() end

---@param future                        stl.c.Future
---@return nil
local function await(future)
  assert(
    vim.wait(10000, function()
      return future:is_done()
    end, 1),
    "Future timed out"
  )
  assert(not future:is_failed(), future:get_error())
end

---@param bufnr                         integer
---@return table
local function capture(bufnr)
  local ranges = {}
  for _, mark in
    ipairs(
      vim.api.nvim_buf_get_extmarks(bufnr, vim.api.nvim_get_namespaces().board_git_hunk, 0, -1, { details = true })
    )
  do
    ranges[#ranges + 1] = { mark[2], mark[3], mark[4] }
  end
  return { lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), ranges = ranges }
end

---@return nil
local function run()
  local git = era.m.git
  local bufnr, winnr = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local source = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  await(git.state.refresh())
  assert(
    vim.wait(10000, function()
      return git.buffer.is_attached(bufnr)
    end, 1),
    "source did not attach"
  )
  await(git.buffer.refresh(bufnr))
  local selected
  for _, hunk in ipairs(git.buffer.get_unstaged_hunks(bufnr) or {}) do
    if hunk.type == "change" and #git.diff.compute_hunk_word_diff(hunk) > 0 then
      selected = hunk
      break
    end
  end
  assert(selected, "open a tracked file with an unstaged change hunk")
  vim.api.nvim_win_set_cursor(winnr, { math.max(selected.added.start, 1), 0 })
  local reference = assert(loadfile("__test__/fixtures/era/m/git/diff_lua_reference.lua"))()
  local compute = git.diff.compute_hunk_word_diff
  local results = {}
  for index = 1, 2 do
    git.diff.compute_hunk_word_diff = index == 1 and reference.compute_hunk_word_diff or compute
    local view = git.Hunkview.new({ bufnr = bufnr })
    view:open()
    assert(view:isvisible(), "hunk popup missing")
    local popup_bufnr = vim.api.nvim_get_current_buf()
    assert(popup_bufnr ~= bufnr, "popup did not own a buffer")
    results[index] = capture(popup_bufnr)
    local word_marks = 0
    for _, mark in ipairs(results[index].ranges) do
      if mark[3].hl_group == "DiffWordLeft" or mark[3].hl_group == "DiffWordRight" then
        word_marks = word_marks + 1
      end
    end
    assert(word_marks > 0, "word highlight extmarks missing")
    view:dispose()
    assert(not vim.api.nvim_buf_is_valid(popup_bufnr), "popup buffer not released")
    vim.api.nvim_set_current_win(winnr)
  end
  assert(vim.deep_equal(results[1], results[2]), "popup lines or highlight extmarks differ")
  assert(vim.deep_equal(source, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)), "source changed")
  io.stdout:write(
    string.format(
      "E2E word_diff=PASS popup_lines=%d extmarks=%d source=UNCHANGED cleanup=PASS\n",
      #results[2].lines,
      #results[2].ranges
    )
  )
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
end
vim.cmd(ok and "qa!" or "cquit 1")
