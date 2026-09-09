--- Manual full-config E2E; open a changed tracked file, then execute this fixture with :luafile.
--- Run in a disposable headless Neovim: this fixture disables context saving and exits the process.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.git.status_runtime" ---@type string

dot.context.save_on_exit = function() end

---@param future                        stl.c.Future
---@return any
local function await(future)
  assert(
    vim.wait(10000, function()
      return future:is_done()
    end, 1),
    "Future timed out"
  )
  assert(not future:is_failed(), future:get_error())
  return future:get_result()
end

---@return nil
local function run()
  local git = era.m.git
  await(git.state.refresh())
  local snapshot = git.state.snapshot()
  assert(type(snapshot) == "userdata", "state must own a native handle")

  local reference = assert(loadfile("__test__/fixtures/era/m/git/status_lua_reference.lua"))()
  local data = await(reference.collect({ include_numstat = true }))
  local entries = snapshot:entries()
  local own = entries[vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())]
  assert(own and own.stage, "open a changed tracked file to verify native Git signs")
  assert(vim.deep_equal(entries, data.status_map), "full-config snapshot differs from Lua oracle")
  local directory = dot.path.workspace()
  local expected = reference.compute_dir_status(reference.aggregate(data.status_map), directory)
  assert(snapshot:lookup(directory, true).display == expected.display, "directory status differs")

  local bufnr = vim.api.nvim_get_current_buf()
  assert(
    vim.wait(10000, function()
      return git.buffer.is_attached(bufnr)
    end, 1),
    "source buffer did not attach"
  )
  await(git.buffer.refresh(bufnr))
  vim.cmd("redraw")
  local signs = 0
  for _, name in ipairs({ "dot_module_git_sign", "dot_module_git_sign_staged" }) do
    local ns = assert(vim.api.nvim_get_namespaces()[name], "Git sign namespace missing")
    signs = signs + #vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
  end
  assert(signs > 0, "open a changed tracked file to verify native Git signs")

  local ignored = directory .. "/lua/yoz.so"
  local visible = directory .. "/lua/era/m/git/status.lua"
  local ignore_reference = assert(loadfile("__test__/fixtures/era/m/git/ignore_lua_reference.lua"))()
  await(git.state.preload_ignored({ ignored, visible }))
  await(ignore_reference.preload_ignored({ ignored, visible }))
  for _, path in ipairs({ ignored, visible }) do
    assert(git.state.is_ignored(path) == ignore_reference.is_ignored(path), "ignore cache differs from Lua oracle")
  end
  local view = require("era.m.explorer.view").new("git-native-ignore-e2e")
  ---@diagnostic disable-next-line: invisible
  assert(view:__is_ignored__({ filepath = ignored }), "Explorer did not consume native ignore state")

  local blame_reference = assert(loadfile("__test__/fixtures/era/m/git/blame_lua_reference.lua"))()
  local owner = assert(git.buffer.get_cache(bufnr))
  local blame_data = await(blame_reference.collect(bufnr, owner.relpath, owner.repo.toplevel))
  local blame_ns = assert(vim.api.nvim_get_namespaces().dot_module_git_buffer_blame)
  git.blame.buffer_show(bufnr)
  assert(
    vim.wait(10000, function()
      return #vim.api.nvim_buf_get_extmarks(bufnr, blame_ns, 0, -1, {}) == #blame_data - 1
    end, 5),
    "buffer blame overlay missing"
  )
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, blame_ns, 0, -1, { details = true })) do
    local info = assert(blame_data[mark[2] + 1])
    local text = "    Not committed yet"
    if not info.sha:match("^0+$") and info.author ~= "Not Committed Yet" then
      local author = info.author
      if git.state.get_user_name() == author or git.state.get_user_email() == info.author_mail then
        author = "You"
      end
      local date = info.author_time > 0 and os.date("%Y-%m-%d %H:%M:%S", info.author_time) or ""
      text = string.format("    %s, %s - %s", author, date, info.summary)
    end
    assert(mark[4].virt_text[1][1] == text, "blame annotation differs from source attribution")
    assert(mark[4].virt_text_win_col == 80, "blame column changed")
  end
  git.blame.buffer_hide(bufnr)

  await(git.state.refresh())
  assert(git.state.snapshot() == snapshot, "unchanged refresh replaced the native handle")
  io.stdout:write(
    string.format(
      "E2E native_entries=%d directory=%s signs=%d stable_handle=PASS parity=PASS ignore=PASS blame=PASS\n",
      vim.tbl_count(entries),
      expected.display,
      signs
    )
  )
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
end
vim.cmd(ok and "qa!" or "cquit 1")
