-- Run from the repository root in a disposable headless Neovim with the full configuration, on a tracked file with
-- unstaged changes (such as `lua/era/m/git/ignore.lua` after editing it), with this checkout's runtime, Lua path and
-- native module ahead of the default configuration's:
--   nvim --headless \
--     --cmd 'lua local root = vim.uv.cwd(); vim.opt.runtimepath:prepend(root); package.path = root .. "/?.lua;" .. package.path; package.cpath = root .. "/lua/?.so;" .. package.cpath' \
--     -u init.lua -i NONE -n lua/era/m/git/ignore.lua \
--     -c 'luafile __test__/manual/era/m/git/status_runtime.lua'
-- Requires the installed plugins and native library. Compares the native Git status, signs, ignore cache and buffer
-- blame with the Lua oracles, and checks the default Explorer's native ignore decoration; context saving is disabled,
-- and the process exits without writing source buffers.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.manual.era.m.git.status_runtime" ---@type string

local t = require("__test__.support.harness").new()

-- The run ends the process, which must not save the context of this disposable session.
dot.context.save_on_exit = function() end

t:test("full-config status, signs, ignore and blame match the Lua oracles", function()
  local git = era.m.git
  t.await(git.state.refresh())
  local snapshot = git.state.snapshot()
  assert(type(snapshot) == "userdata", "state must own a native handle")

  local reference = assert(loadfile("__test__/fixtures/era/m/git/status_lua_reference.lua"))()
  local data = t.await(reference.collect({ include_numstat = true }))
  local entries = snapshot:entries()
  local own = entries[vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())]
  assert(own and own.stage, "open a changed tracked file to verify native Git signs")
  assert(vim.deep_equal(entries, data.status_map), "full-config snapshot differs from Lua oracle")
  local directory = dot.path.workspace()
  local expected = reference.compute_dir_status(reference.aggregate(data.status_map), directory)
  assert(snapshot:lookup(directory, true).display == expected.display, "directory status differs")

  local bufnr = vim.api.nvim_get_current_buf()
  t.wait_until(function()
    return git.buffer.is_attached(bufnr)
  end, 10000, "source buffer did not attach")
  t.await(git.buffer.refresh(bufnr))
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
  t.await(git.ignore.preload({ ignored, visible }))
  t.await(ignore_reference.preload_ignored({ ignored, visible }))
  for _, path in ipairs({ ignored, visible }) do
    assert(git.ignore.is_ignored(path) == ignore_reference.is_ignored(path), "ignore cache differs from Lua oracle")
  end
  local source_winnr = vim.api.nvim_get_current_win()
  local widget = era.widget.explorer.get_widget()
  widget:focus()
  t.await(widget._ready)
  t.await(widget:reveal(ignored))
  local session = widget:context()
  local resource = t.await(session.data:resolve(ignored))
  t.wait_until(function()
    local _, _, view = pcall(widget.context, widget)
    if not view or not view:frame() then
      return false
    end
    local at = view:frame():position(resource:node())
    local annotations = view._filetree_annotations
    local value = at and annotations and annotations.rows[at - annotations.first + 1]
    return value and bit.band(value.git, 256) ~= 0
  end, 10000, "Explorer did not consume native ignore state")
  widget:hide()
  vim.api.nvim_set_current_win(source_winnr)

  local blame_reference = assert(loadfile("__test__/fixtures/era/m/git/blame_lua_reference.lua"))()
  local owner = assert(git.buffer.get_cache(bufnr))
  local blame_data = t.await(blame_reference.collect(bufnr, owner.relpath, owner.repo.toplevel))
  local blame_ns = assert(vim.api.nvim_get_namespaces().dot_module_git_buffer_blame)
  git.blame.buffer_show(bufnr)
  t.wait_until(function()
    return #vim.api.nvim_buf_get_extmarks(bufnr, blame_ns, 0, -1, {}) == #blame_data - 1
  end, 10000, "buffer blame overlay missing")
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, blame_ns, 0, -1, { details = true })) do
    local info = assert(blame_data[mark[2] + 1])
    local text = "    Not committed yet"
    if not info.sha:match("^0+$") and info.author ~= "Not Committed Yet" then
      local author = info.author
      if git.user.name() == author or git.user.email() == info.author_mail then
        author = "You"
      end
      local date = info.author_time > 0 and os.date("%Y-%m-%d %H:%M:%S", info.author_time) or ""
      text = string.format("    %s, %s - %s", author, date, info.summary)
    end
    assert(mark[4].virt_text[1][1] == text, "blame annotation differs from source attribution")
    assert(mark[4].virt_text_win_col == 80, "blame column changed")
  end
  git.blame.buffer_hide(bufnr)

  t.await(git.state.refresh())
  assert(git.state.snapshot() == snapshot, "unchanged refresh replaced the native handle")
  io.stdout:write(
    string.format(
      "E2E native_entries=%d directory=%s signs=%d stable_handle=PASS parity=PASS ignore=PASS blame=PASS\n",
      vim.tbl_count(entries),
      expected.display,
      signs
    )
  )
end)

t:run()
