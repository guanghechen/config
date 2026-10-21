require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.commits.action")
local commits_view = require("era.m.diffview.view.commits.view")
local data = require("era.m.diffview.data")
local pane_commits = require("era.m.diffview.pane.commits")
local tree = require("era.m.diffview.pane.tree")

---A repository on main whose history is `messages`, oldest first, each commit editing f.txt; Diffview reads it as the
---workspace for the rest of the case.
---@param messages                      string[]
---@return string root
local function history(messages)
  local root = diffview.workspace(t, git.repo(t, { "-b", "main" }))
  local stream = {} ---@type string[]
  for i, message in ipairs(messages) do
    local content = tostring(i) .. "\n"
    vim.list_extend(stream, {
      "commit refs/heads/main",
      "mark :" .. i,
      string.format("committer Test <test@example.com> %d +0000", 1700000000 + i),
      "data " .. #message,
      message,
    })
    if i > 1 then
      stream[#stream + 1] = "from :" .. (i - 1)
    end
    vim.list_extend(stream, { "M 100644 inline f.txt", "data " .. #content, content })
  end
  git.run(root, { "fast-import", "--quiet" }, table.concat(stream, "\n") .. "\n")
  git.run(root, { "reset", "-q", "--hard", "main" })
  return root
end

---Counts tabline refreshes for the rest of the case.
---@return { count: integer }
local function count_dirty()
  local dirty = { count = 0 }
  t:patch_table(dot.state.status.dirtier_tabline, "mark_dirty", function()
    dirty.count = dirty.count + 1
  end)
  return dirty
end

---Records the last row identity the commits tree is asked to focus.
---@param session                       era.m.diffview.CommitsSession
---@return { key: string|nil }
local function record_tree_focus(session)
  local focus = { key = nil }
  local owner = session.state:get_tree("commits")
  local focus_key = owner.focus_key
  t:patch_table(owner, "focus_key", function(self, key, ...)
    focus.key = key
    return focus_key(self, key, ...)
  end)
  return focus
end

---Answers the search prompt with `answers`, in order.
---@param answers                       string[]
---@return nil
local function answer_search(answers)
  t:patch_table(vim.ui, "input", function(opts, callback)
    t.assert_eq("Commit hash or message: ", opts.prompt, "search prompt")
    callback(table.remove(answers, 1))
  end)
end

t:test("commit details popup opens above a trigger near the bottom", function()
  local anchor_row = vim.o.lines - 3 ---@type integer
  action.__show_commit_popup__("abc123", { "commit abc123", "Author: Alice" }, {
    row = anchor_row,
    col = 1,
  })

  local popup_winnr = vim.api.nvim_get_current_win() ---@type integer
  local config = vim.api.nvim_win_get_config(popup_winnr)
  t.assert_eq("editor", config.relative, "editor-relative captured position")
  t.assert_eq(anchor_row - config.height - 2, config.row, "popup above trigger row")
  t.assert_true(config.row ~= math.floor((vim.o.lines - config.height) / 2), "popup is not centered")
  vim.api.nvim_win_close(popup_winnr, true)
end)

t:test("hide_commits keeps a commits-only tab alive", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 4 })
  local lyt = session.layout
  local commits_winnr = assert(lyt.commits_winnr)

  commits_view.hide_commits(lyt)

  t.assert_true(vim.api.nvim_tabpage_is_valid(session.tabnr), "commits-only tab")
  t.assert_true(vim.api.nvim_win_is_valid(commits_winnr), "last window")
  t.assert_eq(commits_winnr, lyt.commits_winnr, "layout reference")
end)

t:test("reveal expands and focuses the active file, then hides Commits", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 3 })
  local state = session.state
  local commit = state:get_commits()[1]
  -- The active file is one of the commit's files, as opening it from Commits leaves it.
  stl.async.run(function()
    action.__expand_commit__(session, commit)
  end)
  t.wait_until(function()
    return commit.files ~= nil
  end, 10000, "the commit's files")
  state:collapse_commit(commit.hash)
  local entry = nil ---@type era.m.diffview.IFileEntry|nil
  for _, file in ipairs(commit.files) do
    if file.filepath == "a.txt" then
      entry = file
    end
  end
  state:set_current_commit(commit)
  state:set_current_entry(assert(entry))
  local focus = record_tree_focus(session)
  local sbs_winnr = assert(session.layout.sbs_left_winnr)
  vim.api.nvim_set_current_win(sbs_winnr)

  action.reveal(session)
  local commits_winnr = assert(session.layout.commits_winnr)
  t.wait_until(function()
    return focus.key == tree.key("commit:" .. commit.hash, "a.txt", false)
  end, 10000, "active file cursor identity")
  t.assert_true(session.state:is_commit_expanded(commit.hash), "active commit expanded")
  t.assert_eq(commits_winnr, vim.api.nvim_get_current_win(), "Commits focused")

  action.reveal(session)
  t.assert_true(vim.api.nvim_tabpage_is_valid(session.tabnr), "tab remains valid")
  t.assert_nil(session.layout.commits_winnr, "Commits hidden")
  t.assert_eq(sbs_winnr, vim.api.nvim_get_current_win(), "SBS retained")
end)

t:test("search jumps across pages and selects the matching commit", function()
  local messages = {} ---@type string[]
  for i = 1, 151 do
    messages[i] = "commit " .. i
  end
  -- The log lists the newest first, so the 49th commit is the 103rd entry.
  messages[49] = "target"
  history(messages)
  local session = diffview.open_log(t, { layout = 4, path = "f.txt" })
  local state = session.state
  local first = state:get_commits()[1]
  state:expand_commit(first.hash)
  state:set_current_entry({ filepath = "stale.lua", status = "M" })
  local found, fetched = nil, nil ---@type table|nil, table|nil
  local find_log_commit, fetch_log_page = data.find_log_commit, data.fetch_log_page
  t:patch_table(data, "find_log_commit", function(query, path_filter, ...)
    found = { query = query, path_filter = path_filter }
    return find_log_commit(query, path_filter, ...)
  end)
  t:patch_table(data, "fetch_log_page", function(page, per_page, ...)
    fetched = { page = page, per_page = per_page }
    return fetch_log_page(page, per_page, ...)
  end)
  local dirty = count_dirty()
  local focus = record_tree_focus(session)
  local errors = {} ---@type string[]
  t:patch_table(stl.reporter, "error", function(report)
    errors[#errors + 1] = report.message
  end)
  answer_search({ "  target  " })

  action.search_commit(session)
  t.wait_until(function()
    return dirty.count > 0
  end, 10000, "the search result")

  local target = assert(state:get_current_commit(), "current commit")
  t.assert_eq("target", assert(found).query, "trimmed query")
  t.assert_eq("f.txt", assert(found).path_filter, "path filter")
  t.assert_eq(2, assert(fetched).page, "target page")
  t.assert_eq(100, assert(fetched).per_page, "page size")
  t.assert_eq(2, state:get_commits_page(), "state page")
  t.assert_eq(151, state:get_commits_total(), "state total")
  t.assert_eq("target", target.message, "current commit")
  t.assert_nil(state:get_current_entry(), "stale entry")
  t.assert_false(state:is_commit_expanded(first.hash), "expanded commits")
  t.assert_eq(3, state:get_lnum_present(), "present line")
  t.assert_eq("commit:" .. target.hash, focus.key, "cursor identity")
  t.assert_eq(1, dirty.count, "tabline refresh")
  local settled = false
  session.state:get_tree("commits"):ready():finally(function()
    settled = true
  end)
  t.wait_until(function()
    return settled
  end, 5000, "settled tree changes")
  t.assert_same({}, errors, "no errors")
end)

t:test("search keeps only the latest overlapping result", function()
  history({ "first", "second" })
  local session = diffview.open_log(t, { layout = 4 })
  local settled = 0
  local find_log_commit = data.find_log_commit
  t:patch_table(data, "find_log_commit", function(query, ...)
    if query == "first" then
      -- A newer search starts while this one is in flight.
      action.search_commit(session)
    end
    local match, err = find_log_commit(query, ...)
    settled = settled + 1
    return match, err
  end)
  local dirty = count_dirty()
  answer_search({ "first", "second" })

  action.search_commit(session)
  t.wait_until(function()
    return settled == 2 and dirty.count > 0
  end, 10000, "both searches")
  local flushed = false
  vim.schedule(function()
    flushed = true
  end)
  t.wait_until(function()
    return flushed
  end, 1000, "scheduled work")

  t.assert_eq("second", session.state:get_current_commit().message, "latest current commit")
  t.assert_eq(2, session.state:get_commits_total(), "latest total")
  t.assert_eq(1, dirty.count, "single committed result")
end)

t:test("search reports a missing commit without changing pages", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 4 })
  session.state:request_commits_page(2)
  local reports = {} ---@type table[]
  t:patch_table(stl.reporter, "warn", function(report)
    reports[#reports + 1] = report
  end)
  local fetches = 0
  local fetch_log_page = data.fetch_log_page
  t:patch_table(data, "fetch_log_page", function(...)
    fetches = fetches + 1
    return fetch_log_page(...)
  end)
  local dirty = count_dirty()
  answer_search({ "missing" })

  action.search_commit(session)
  t.wait_until(function()
    return #reports > 0
  end, 10000, "the report")

  t.assert_eq(1, #reports, "warning count")
  t.assert_eq('No commit matched "missing".', reports[1].message, "warning message")
  t.assert_eq(1, session.state:get_commits_page(), "applied page restored")
  t.assert_eq(0, fetches, "page fetch")
  t.assert_eq(0, dirty.count, "tabline refresh")
end)

t:test("rapid page commands preserve every requested step", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 4 })
  local state = session.state
  state:set_commits_total(300)
  local first = state:get_commits()[1]
  state:expand_commit(first.hash)
  local pending = {} ---@type function[]
  t:patch_table(stl.async, "run", function(callback)
    pending[#pending + 1] = callback
  end)

  action.next_page(session)
  action.next_page(session)

  t.assert_eq(3, state:get_commits_page(), "requested page")
  t.assert_false(state:is_commit_expanded(first.hash), "expanded commits")
  t.assert_eq(2, #pending, "page requests")
end)

t:test("commit pane directories toggle independently and copy their displayed path", function()
  local root = diffview.committed(t, { ["lua/era/a.lua"] = { "a" }, ["lua/era/b.lua"] = { "b" } })
  local session = diffview.open_log(t, { layout = 4 })
  local commit = session.state:get_commits()[1]
  local lyt = session.layout
  stl.async.run(function()
    action.__expand_commit__(session, commit)
  end)
  local row, directory = nil, nil ---@type integer|nil, table|nil
  t.wait_until(function()
    for lnum = 1, vim.api.nvim_buf_line_count(lyt.commits_bufnr) do
      local item = pane_commits.get_item_at_line(lyt.commits_bufnr, lnum)
      if item and item.type == "directory" then
        row, directory = lnum, item
        return true
      end
    end
    return false
  end, 10000, "the directory row")
  vim.api.nvim_set_current_win(lyt.commits_winnr)
  vim.api.nvim_win_set_cursor(lyt.commits_winnr, { assert(row), 0 })

  local operations = {} ---@type string[]
  for name, label in pairs({
    toggle_commit_dir = "toggle",
    collapse_commit_dir = "collapse",
    expand_commit_dir = "expand",
  }) do
    local original = session.state[name]
    t:patch_table(session.state, name, function(self, hash, uuid)
      operations[#operations + 1] = label .. ":" .. hash .. ":" .. uuid
      return original(self, hash, uuid)
    end)
  end
  local renders = 0
  local render_commits = commits_view.render_commits
  t:patch_table(commits_view, "render_commits", function(...)
    renders = renders + 1
    return render_commits(...)
  end)
  local copied = nil ---@type table|nil
  t:patch_table(era.fn, "select_copy_filepath", function(opts)
    copied = opts
  end)

  action.select(session)
  action.collapse(session)
  action.expand(session)
  action.copy_filepath(session)

  local key = commit.hash .. ":" .. assert(directory).uuid
  t.assert_eq("toggle:" .. key, operations[1], "select toggles directory")
  t.assert_eq("collapse:" .. key, operations[2], "collapse action")
  t.assert_eq("expand:" .. key, operations[3], "expand action")
  t.assert_eq(0, renders, "native directory expansion preserves the producer")
  local copy_opts = assert(copied)
  t.assert_eq(root .. "/lua/era", copy_opts.filepath, "displayed directory path")
  t.assert_eq("cursor", copy_opts.relative, "copy picker anchor")
end)

t:run()
