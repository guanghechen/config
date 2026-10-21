local t = require("__test__.support.harness").new()
local git = require("__test__.support.git")

-- Diffview end to end in a child with an attached UI, driven only through era.m.diffview.fn and buffer keymaps.
-- It pins the behavior the session refactor must keep, so the refactor's steps leave this file unchanged.

---One commit, then a staged addition (c.txt) and an unstaged edit (a.txt).
---@return string
local function repository()
  local root = assert(vim.uv.fs_realpath(git.repo(t)))
  vim.fn.writefile({ "one", "two", "three" }, root .. "/a.txt")
  vim.fn.writefile({ "bee" }, root .. "/b.txt")
  vim.fn.writefile({ "dee" }, root .. "/d.txt")
  git.run(root, { "add", "." })
  git.run(root, { "commit", "-q", "-m", "first" })
  vim.fn.writefile({ "one", "TWO", "three" }, root .. "/a.txt")
  vim.fn.writefile({ "new" }, root .. "/c.txt")
  git.run(root, { "add", "c.txt" })
  return root
end

---@param root                          string
---@return __test__.support.UI
local function child(root)
  local ui = require("__test__.support.ui").new({ cwd = root })
  t:defer(function()
    ui:close()
  end)
  ui:start({ width = 160, height = 48, runtime = "ark" })
  ui:lua(
    [[
    local root = ...
    dot.path.workspace = function() return root end
    dot.path.is_git_repo = function() return true end
    errors, warnings = {}, {}
    stl.reporter.error = function(value) errors[#errors + 1] = value end
    stl.reporter.warn = function(value) warnings[#warnings + 1] = value end

    -- The current tab's windows by role, column by column and top to bottom within a column.
    function panes()
      local winnrs = vim.api.nvim_tabpage_list_wins(0)
      table.sort(winnrs, function(a, b)
        local pa, pb = vim.api.nvim_win_get_position(a), vim.api.nvim_win_get_position(b)
        return pa[2] < pb[2] or pa[2] == pb[2] and pa[1] < pb[1]
      end)
      local result = { tab = vim.t.tabtype, changes = {}, previews = {} }
      for _, winnr in ipairs(winnrs) do
        local bufnr = vim.api.nvim_win_get_buf(winnr)
        local filetype = vim.bo[bufnr].filetype
        if filetype == "diffview-changes" then
          result.changes[#result.changes + 1] = winnr
        elseif filetype == "diffview-commits" then
          result.history = winnr
        elseif vim.api.nvim_buf_get_name(bufnr):match("^diffview://") then
          result.previews[#result.previews + 1] = winnr
        end
      end
      return result
    end

    -- The rows a pane shows, without indentation or empty rows.
    function labels(winnr)
      local result = {}
      if winnr then
        for _, line in ipairs(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winnr), 0, -1, false)) do
          if vim.trim(line) ~= "" then
            result[#result + 1] = vim.trim(line)
          end
        end
      end
      return result
    end

    -- The staged and unstaged Changes rows.
    function changes()
      local p = panes()
      return labels(p.changes[1]), labels(p.changes[2])
    end

    -- Whether a preview window shows exactly these lines.
    function previewed(...)
      local expected = table.concat({ ... }, "\n")
      for _, winnr in ipairs(panes().previews) do
        local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winnr), 0, -1, false)
        if table.concat(lines, "\n") == expected then
          return winnr
        end
      end
    end

    -- Whether window `winnr`'s buffer maps `lhs` in Normal mode.
    function mapped(winnr, lhs)
      for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(vim.api.nvim_win_get_buf(winnr), "n")) do
        if keymap.lhs == lhs then
          return true
        end
      end
      return false
    end

    function diffview_tabs()
      local count = 0
      for _, tabnr in ipairs(vim.api.nvim_list_tabpages()) do
        if (vim.t[tabnr].tabtype or ""):match("^diffview") then
          count = count + 1
        end
      end
      return count
    end
  ]],
    root
  )
  return ui
end

---Polls a child chunk until it returns a truthy value, and returns that value.
---@param ui                            __test__.support.UI
---@param chunk                         string
---@param message                       string
---@param ...                           any
---@return any
local function await(ui, chunk, message, ...)
  local args = { ... }
  local ok, result = pcall(ui.wait_until, ui, function()
    return ui:lua(chunk, unpack(args))
  end, 10000, message)
  if not ok then
    local state = ui:lua(
      "return vim.inspect({ tab = vim.t.tabtype, changes = { changes() }, errors = errors, warnings = warnings })"
    )
    error(tostring(result) .. "\n" .. state, 2)
  end
  return result
end

---Types `keys` into window `winnr` of the child.
---@param ui                            __test__.support.UI
---@param winnr                         integer
---@param keys                          string
---@return nil
local function press(ui, winnr, keys)
  ui:lua("vim.api.nvim_set_current_win(...)", winnr)
  ui:rpc("nvim_input", keys)
end

---Opens the workspace and waits until Changes lists these rows and History lists the commit.
---@param ui                            __test__.support.UI
---@param staged                        string[]
---@param unstaged                      string[]
---@return { changes: integer[], history: integer, previews: integer[] }
local function open_workspace(ui, staged, unstaged)
  ui:lua("era.m.diffview.fn.open_workspace()")
  return await(
    ui,
    [[
    local staged, unstaged = ...
    local p = panes()
    local s, u = changes()
    return p.tab == "diffview_workspace" and #p.changes == 2 and p.history and #labels(p.history) > 0
      and vim.deep_equal(s, staged) and vim.deep_equal(u, unstaged) and p
  ]],
    "workspace with Changes and History",
    staged,
    unstaged
  )
end

---@param ui                            __test__.support.UI
---@param path                          string
---@return integer tabnr
local function open_log(ui, path)
  ui:lua("era.m.diffview.fn.open_commits({ path = ... })", path)
  return await(
    ui,
    [[
    local p = panes()
    return p.tab == "diffview_commits" and #labels(p.history) > 0 and vim.api.nvim_get_current_tabpage()
  ]],
    "log for " .. path
  )
end

---@param root                          string
---@return string
local function cached(root)
  return git.run(root, { "diff", "--cached", "--name-only" })
end

t:test("workspace: opening lists Changes and History and previews the first file", function()
  local ui = child(repository())
  local p = open_workspace(ui, { "c.txt" }, { "a.txt" })

  t.assert_true(ui:lua("return labels(...)[1]", p.history):find("first", 1, true) ~= nil, "History lists the commit")
  await(ui, [[return previewed("new")]], "the first staged file is previewed")
  t.assert_eq(p.changes[1], ui:lua("return vim.api.nvim_get_current_win()"), "the cursor starts in Changes")
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("workspace: gs and gu move a file between the Changes panes and the index", function()
  local root = repository()
  local ui = child(root)
  local p = open_workspace(ui, { "c.txt" }, { "a.txt" })

  press(ui, p.changes[2], "gs")
  await(ui, [[local s, u = changes() return vim.deep_equal(s, { "a.txt", "c.txt" }) and #u == 0]], "a.txt staged")
  t.assert_eq("a.txt\nc.txt\n", cached(root))

  press(ui, p.changes[1], "gggu")
  await(
    ui,
    [[local s, u = changes() return vim.deep_equal(s, { "c.txt" }) and vim.deep_equal(u, { "a.txt" })]],
    "a.txt unstaged"
  )
  t.assert_eq("c.txt\n", cached(root))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("workspace: ghu in the index preview unstages the selected line", function()
  local root = repository()
  git.run(root, { "add", "a.txt" })
  local ui = child(root)
  open_workspace(ui, { "a.txt", "c.txt" }, {})

  -- Opening selects the first staged file, a.txt.
  local index = await(
    ui,
    [[local winnr = previewed("one", "TWO", "three") return winnr and mapped(winnr, "ghu") and winnr]],
    "a.txt's index side is previewed with its keymaps"
  )
  ui:lua("vim.api.nvim_win_set_cursor(..., { 2, 0 })", index)
  press(ui, index, "ghu")
  await(
    ui,
    [[local s, u = changes() return vim.deep_equal(s, { "c.txt" }) and vim.deep_equal(u, { "a.txt" })]],
    "the line left the index"
  )
  t.assert_eq("c.txt\n", cached(root))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("workspace: external edits reach Changes on a Git refresh or an explicit refresh", function()
  local root = repository()
  local ui = child(root)
  open_workspace(ui, { "c.txt" }, { "a.txt" })

  vim.fn.writefile({ "BEE" }, root .. "/b.txt")
  ui:lua("era.m.git.state.refresh()")
  await(ui, [[local _, u = changes() return vim.tbl_contains(u, "b.txt")]], "a Git status refresh reaches Changes")

  vim.fn.writefile({ "DEE" }, root .. "/d.txt")
  ui:lua("era.m.diffview.fn.refresh()")
  await(ui, [[local _, u = changes() return vim.tbl_contains(u, "d.txt")]], "an explicit refresh reaches Changes")
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("workspace: History previews a commit's file; reveal and the toggles switch the sidebar", function()
  local ui = child(repository())
  local p = open_workspace(ui, { "c.txt" }, { "a.txt" })

  press(ui, p.history, "gl")
  await(
    ui,
    [[local h = labels(panes().history) return h[2] == "a.txt" and h[3] == "b.txt" and h[4] == "d.txt"]],
    "the commit expands to its files"
  )
  ui:lua("vim.api.nvim_win_set_cursor(..., { 2, 0 })", p.history)
  press(ui, p.history, "<CR>")
  local preview = await(ui, [[return previewed("one", "two", "three")]], "the commit's a.txt is previewed")

  -- Reveal locates the current Changes entry, and hides Changes when they already have focus.
  ui:lua("vim.api.nvim_set_current_win(...) era.m.diffview.fn.reveal()", preview)
  await(ui, [[return vim.api.nvim_get_current_win() == panes().changes[1] ]], "reveal focuses Changes")
  ui:lua("era.m.diffview.fn.reveal()")
  await(ui, [[local p = panes() return #p.changes == 0 and p.history ~= nil]], "reveal from Changes hides them")
  ui:lua("era.m.diffview.fn.reveal()")
  await(
    ui,
    [[local p = panes() return #p.changes == 2 and vim.api.nvim_get_current_win() == p.changes[1] ]],
    "reveal shows Changes again"
  )

  ui:lua("era.m.diffview.fn.toggle_commits()")
  await(ui, [[return panes().history == nil]], "toggle_commits hides History")
  ui:lua("era.m.diffview.fn.toggle_commits()")
  await(
    ui,
    [[local p = panes() return p.history ~= nil and vim.api.nvim_get_current_win() == p.history]],
    "toggle_commits shows History"
  )
  ui:lua("era.m.diffview.fn.toggle_files()")
  await(ui, [[local p = panes() return #p.changes == 0 and p.history == nil]], "toggle_files hides the sidebar")
  ui:lua("era.m.diffview.fn.toggle_files()")
  await(ui, [[local p = panes() return #p.changes == 2 and p.history ~= nil]], "toggle_files shows the sidebar")
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("help: g? lists the keymaps of the focused view", function()
  local ui = child(repository())
  local p = open_workspace(ui, { "c.txt" }, { "a.txt" })
  local help = [[
    local wanted = { ... }
    for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(winnr).relative ~= "" then
        local text = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winnr), 0, -1, false), "\n")
        local found = true
        for _, desc in ipairs(wanted) do
          found = found and text:find(desc, 1, true) ~= nil
        end
        if found then
          return winnr
        end
      end
    end
  ]]

  press(ui, p.changes[1], "g?")
  local workspace_help =
    await(ui, help, "workspace help", "Stage file / directory", "Unstage selected index line", "Show commit details")
  ui:lua("vim.api.nvim_win_close(..., true)", workspace_help)

  local log = open_log(ui, "a.txt")
  press(ui, ui:lua("return panes().history"), "g?")
  await(ui, help, "log help", "Yank commit hash")
  t.assert_eq(log, ui:lua("return vim.api.nvim_get_current_tabpage()"))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("log: a path filter returns to its log, and another path opens its own", function()
  local root = repository()
  local ui = child(root)

  local first = open_log(ui, "a.txt")
  ui:lua("vim.cmd.tabfirst()")
  ui:lua("era.m.diffview.fn.open_file_history({ filepath = ... })", root .. "/a.txt")
  t.assert_eq(first, ui:lua("return vim.api.nvim_get_current_tabpage()"), "the same path returns to its log")

  local second = open_log(ui, "b.txt")
  t.assert_true(second ~= first, "another path opens its own log")
  t.assert_eq(2, ui:lua("return diffview_tabs()"))
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:test("close: q and :tabclose leave no session or autocmd behind", function()
  local ui = child(repository())
  local function cycle()
    local p = open_workspace(ui, { "c.txt" }, { "a.txt" })
    press(ui, p.changes[1], "q")
    await(ui, [[return diffview_tabs() == 0]], "q closes the workspace")
    open_log(ui, "a.txt")
    ui:lua("vim.cmd.tabclose()")
    await(ui, [[return diffview_tabs() == 0]], ":tabclose closes the log")
  end

  -- The first cycle loads every module; later cycles must end where it did.
  cycle()
  local baseline = ui:lua("return #vim.api.nvim_get_autocmds({})")
  cycle()
  cycle()
  await(ui, "return #vim.api.nvim_get_autocmds({}) == ...", "no autocmd outlives its session", baseline)

  -- A Git refresh after closing reaches no closed session.
  ui:lua("refreshed = era.m.git.state.refresh()")
  await(ui, "return refreshed:is_done()", "Git refresh")
  t.assert_eq(0, ui:lua("return #errors"))
end)

t:run()
