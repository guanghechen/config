require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.commits.action")
local commits_view = require("era.m.diffview.view.commits.view")

---A history in which old.txt is edited, renamed to new.txt along with an edit of other.txt, and edited again; Diffview
---reads it as the workspace for the rest of the case.
---@return nil
local function rename_history()
  local lines = { "one", "two", "three", "four", "five" }
  local root = diffview.committed(t, { ["old.txt"] = lines, ["other.txt"] = { "other" } })
  lines[2] = "TWO"
  diffview.write(root, "old.txt", lines)
  git.run(root, { "commit", "-q", "-am", "edit old.txt" })
  git.run(root, { "mv", "old.txt", "new.txt" })
  lines[3] = "THREE"
  diffview.write(root, "new.txt", lines)
  diffview.write(root, "other.txt", { "OTHER" })
  git.run(root, { "commit", "-q", "-am", "rename old.txt to new.txt" })
  lines[4] = "FOUR"
  diffview.write(root, "new.txt", lines)
  git.run(root, { "commit", "-q", "-am", "edit new.txt" })
end

---The name of the buffer side-by-side window `winnr` shows.
---@param winnr                         integer
---@return string
local function shown(winnr)
  return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winnr))
end

t:test("file history opens each commit at the name the file had in it", function()
  rename_history()
  local session = diffview.open_log(t, { path = "new.txt" })
  local warnings = {} ---@type string[]
  t:patch_table(stl.reporter, "warn", function(report)
    warnings[#warnings + 1] = report.message
  end)

  local opened = {} ---@type string[]
  for _, commit in ipairs(session.state:get_commits()) do
    local previous = session.state:get_current_entry()
    action.__open_target_file_diff__(session, commit, "new.txt")
    t.wait_until(function()
      return session.state:get_current_entry() ~= previous or #warnings > 0
    end, 5000, "the file of " .. commit.message)
    local entry = session.state:get_current_entry()
    opened[#opened + 1] = string.format(
      "%s %s%s",
      entry.status,
      entry.filepath,
      entry.prev_filepath and (" <- " .. entry.prev_filepath) or ""
    )
  end

  t.assert_same({}, warnings, "warnings")
  t.assert_same({ "M new.txt", "R new.txt <- old.txt", "M old.txt", "A old.txt" }, opened, "newest first")
end)

t:test("a file of a rename commit compares with its own previous version", function()
  rename_history()
  local session = diffview.open_log(t, { path = "new.txt" })
  local rename = session.state:get_commits()[2]
  local left = assert(session.layout.sbs_left_winnr)
  action.__open_target_file_diff__(session, rename, "new.txt")
  t.wait_until(function()
    return vim.endswith(shown(left), "^/old.txt")
  end, 5000, "the renamed file at its previous name")

  local other = assert(vim.iter(rename.files):find(function(entry)
    return entry.filepath == "other.txt"
  end))
  stl.async.run(function()
    commits_view.open_entry(session, rename, other)
  end)
  t.wait_until(function()
    return vim.endswith(shown(left), "^/other.txt")
  end, 5000, "other.txt in the parent commit, not the renamed file")
end)

t:run()
