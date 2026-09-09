--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/blame_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.git.blame")
local attached = {} ---@type table<integer, era.m.git.buffer.ICache>

bootstrap.with_runtime(t, {
  yoz = require("yoz"),
  era = {
    m = {
      git = {
        buffer = {
          get_cache = function(bufnr)
            return attached[bufnr]
          end,
          is_attached = function(bufnr)
            return attached[bufnr] ~= nil
          end,
        },
        staging = require("era.m.git.staging"),
        state = {
          get_user_email = function()
            return nil
          end,
          get_user_name = function()
            return nil
          end,
        },
      },
    },
  },
  stl = {
    c = {
      CancellationToken = require("stl.c.cancellation_token"),
      Future = require("stl.c.future"),
    },
    reporter = {
      debug = function() end,
    },
    timer = require("stl.timer"),
  },
})

local blame = require("era.m.git.blame")
blame.setup()

---@param repo                          string
---@param ...                           string
---@return vim.SystemCompleted
local function git(repo, ...)
  return vim.system({ "git", "-C", repo, ... }, { text = true }):wait()
end

---@return string
local function make_repo()
  local repo = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo, "p")
  git(repo, "init", "-q")
  git(repo, "config", "user.email", "test@test")
  git(repo, "config", "user.name", "test")
  vim.fn.writefile({ "base" }, repo .. "/f.txt")
  git(repo, "add", "f.txt")
  git(repo, "commit", "-qm", "base")
  vim.fn.writefile({ "base" }, repo .. "/g.txt")
  git(repo, "add", "g.txt")
  git(repo, "commit", "-qm", "second")
  t:defer(function()
    vim.fn.delete(repo, "rf")
  end)
  return repo
end

---@param repo                          string
---@param relpath                       string|nil
---@param lines                         string[]|nil
---@return integer
local function create_buffer(repo, relpath, lines)
  relpath = relpath or "f.txt"
  local previous = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, repo .. "/" .. relpath)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or { "UNSAVED", "base" })
  vim.api.nvim_set_current_buf(bufnr)
  attached[bufnr] = {
    attached = true,
    bufnr = bufnr,
    file = repo .. "/" .. relpath,
    relpath = relpath,
    repo = { toplevel = repo },
    untracked = false,
  }
  t:defer(function()
    attached[bufnr] = nil
    if vim.api.nvim_buf_is_valid(previous) then
      vim.api.nvim_set_current_buf(previous)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr
end

---@param bufnr                      integer
---@return table[]
local function inline_marks(bufnr)
  local ns = vim.api.nvim_get_namespaces().dot_module_git_inline_blame ---@type integer
  return vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
end

---@param bufnr                         integer
---@return table[]
local function buffer_marks(bufnr)
  local ns = vim.api.nvim_get_namespaces().dot_module_git_buffer_blame
  return vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
end

---@param bufnr                         integer
---@return table[]
local function fake_jobs(bufnr)
  local jobs = {}
  t:patch_table(yoz.git, "start_blame", function(options)
    local info = {
      sha = string.rep("a", 40),
      abbrev_sha = string.rep("a", 8),
      author = "Alice",
      author_mail = "alice@test",
      committer = "Bob",
      committer_mail = "bob@test",
      author_time = 1,
      committer_time = 1,
      summary = "version-" .. (#jobs + 1),
      uncommitted = false,
    }
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local snapshot = {
      commit_at = function()
        return info
      end,
      commits = function()
        info.presentation_builds = (info.presentation_builds or 0) + 1
        return { info }
      end,
      annotations = function(_, labels)
        local lines = {}
        for lnum = 1, line_count do
          lines[lnum] = labels[1]
        end
        return lines
      end,
    }
    local job = { state = "running", cancelled = 0, disposed = false, info = info, options = options }
    job.poll = function()
      return job.state, snapshot, job.err
    end
    job.cancel = function()
      job.cancelled = job.cancelled + 1
    end
    job.dispose = function()
      job.disposed = true
    end
    jobs[#jobs + 1] = job
    return job
  end)
  t:defer(function()
    for _, job in ipairs(jobs) do
      job.state = "cancelled"
    end
    t.wait_until(function()
      for _, job in ipairs(jobs) do
        if not job.disposed then
          return false
        end
      end
      return true
    end, 1000, "fake native jobs did not dispose")
  end)
  return jobs
end

t:test("inline blame uses the current unsaved buffer document", function()
  local bufnr = create_buffer(make_repo())
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })

  t.wait_until(function()
    return #inline_marks(bufnr) == 1
  end, 3000, "inline blame should render")

  local text = inline_marks(bufnr)[1][4].virt_text[1][1] ---@type string
  t.assert_true(text:find("Not committed yet", 1, true) ~= nil, "unsaved line attribution")
end)

t:test("inline blame cache follows the current Git attachment owner", function()
  local repo = make_repo()
  local bufnr = create_buffer(repo, "f.txt", { "base" })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })

  t.wait_until(function()
    local current = inline_marks(bufnr)
    return #current == 1 and current[1][4].virt_text[1][1]:find("base", 1, true) ~= nil
  end, 3000, "first pathname blame")

  attached[bufnr] = nil
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname())
  t.wait_until(function()
    return #inline_marks(bufnr) == 0
  end, 1000, "detached pathname clears blame")

  attached[bufnr] = {
    attached = true,
    bufnr = bufnr,
    file = repo .. "/g.txt",
    relpath = "g.txt",
    repo = { toplevel = repo },
    untracked = false,
  }
  vim.api.nvim_buf_set_name(bufnr, repo .. "/g.txt")

  t.wait_until(function()
    local current = inline_marks(bufnr)
    return #current == 1 and current[1][4].virt_text[1][1]:find("second", 1, true) ~= nil
  end, 3000, "rebound pathname blame")
end)

t:test("disabling inline blame cancels and rejects an inflight publish", function()
  local bufnr = create_buffer(make_repo())
  local jobs = fake_jobs(bufnr)

  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
  t.wait_until(function()
    return #jobs == 1
  end, 2000, "blame process should start")

  local disabled = false ---@type boolean
  t:defer(function()
    if disabled then
      blame.inline_toggle()
    end
  end)
  blame.inline_toggle()
  disabled = true
  t.assert_eq(1, jobs[1].cancelled, "native cancellation requested")

  jobs[1].state = "completed"
  vim.wait(100, function()
    return false
  end)

  t.assert_eq(0, #inline_marks(bufnr), "disabled inline blame remains clear")
end)

t:test("invalidate and hide/show replace cancelled runs without waiting for native acknowledgement", function()
  local bufnr = create_buffer(make_repo(), "f.txt", { "one", "two", "three" })
  local jobs = fake_jobs(bufnr)
  t:defer(function()
    blame.buffer_hide(bufnr)
  end)
  blame.buffer_show(bufnr)
  t.assert_eq(1, #jobs, "first overlay query")
  blame.invalidate(bufnr)
  t.assert_eq(2, #jobs, "same-tick invalidation starts a replacement")
  t.assert_eq(1, jobs[1].cancelled, "first query cancelled")
  blame.buffer_hide(bufnr)
  blame.buffer_show(bufnr)
  t.assert_eq(3, #jobs, "show does not coalesce into a cancelled run")
  jobs[1].state, jobs[2].state, jobs[3].state = "completed", "completed", "completed"
  t.wait_until(function()
    return #buffer_marks(bufnr) == 2
  end, 1000, "replacement overlay missing")
  for _, mark in ipairs(buffer_marks(bufnr)) do
    t.assert_true(mark[4].virt_text[1][1]:find("version-3", 1, true) ~= nil, "only replacement data is rendered")
  end
end)

t:test("changedtick changes reject stale completion and permit a later query", function()
  local bufnr = create_buffer(make_repo(), "f.txt", { "one", "two" })
  local jobs = fake_jobs(bufnr)
  t:defer(function()
    blame.buffer_hide(bufnr)
  end)
  blame.buffer_show(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "edited" })
  jobs[1].state = "completed"
  t.wait_until(function()
    return jobs[1].disposed
  end, 1000, "stale job did not finish")
  t.assert_eq(0, #buffer_marks(bufnr), "stale changedtick is not rendered")
  blame.buffer_show(bufnr)
  t.assert_eq(2, #jobs, "current content can retry")
  jobs[2].state = "completed"
  t.wait_until(function()
    return #buffer_marks(bufnr) == 1
  end, 1000, "fresh overlay missing")
end)

t:test("metadata is literal and presentation follows current user identity and timezone", function()
  local bufnr = create_buffer(make_repo(), "f.txt", { "one", "two" })
  local jobs = fake_jobs(bufnr)
  t:defer(function()
    blame.buffer_hide(bufnr)
  end)
  local previous_tz = vim.env.TZ
  vim.env.TZ = "UTC0"
  t:defer(function()
    vim.env.TZ = previous_tz
  end)
  blame.buffer_show(bufnr)
  jobs[1].info.summary = "100% ready <sha> %1"
  jobs[1].state = "completed"
  t.wait_until(function()
    return #buffer_marks(bufnr) == 1
  end, 1000, "literal metadata was not rendered")
  local original = buffer_marks(bufnr)[1][4].virt_text[1][1]
  t.assert_true(original:find("100% ready <sha> %1", 1, true) ~= nil, "metadata is not reinterpreted")
  t:patch_table(era.m.git.state, "get_user_email", function()
    return "alice@test"
  end)
  blame.buffer_show(bufnr)
  local current = buffer_marks(bufnr)[1][4].virt_text[1][1]
  t.assert_true(current:find("You,", 1, true) ~= nil, "identity invalidates presentation")
  local builds = jobs[1].info.presentation_builds
  blame.buffer_show(bufnr)
  t.assert_eq(builds, jobs[1].info.presentation_builds, "same context reuses rendered labels")
  vim.env.TZ = "UTC-8"
  blame.buffer_show(bufnr)
  t.assert_eq(builds + 1, jobs[1].info.presentation_builds, "timezone invalidates presentation")
  t.assert_eq(1, #jobs, "presentation refresh needs no Git query")
end)

t:test("failed runs are suppressed until invalidation without treating cancellation as failure", function()
  local bufnr = create_buffer(make_repo(), "f.txt", { "one", "two" })
  local jobs = fake_jobs(bufnr)
  t:defer(function()
    blame.buffer_hide(bufnr)
  end)
  blame.buffer_show(bufnr)
  jobs[1].state, jobs[1].err = "failed", "git failure"
  t.wait_until(function()
    return jobs[1].disposed
  end, 1000, "failure did not settle")
  blame.buffer_show(bufnr)
  t.assert_eq(1, #jobs, "negative cache avoids repeated failure")
  blame.clear_failed()
  blame.buffer_show(bufnr)
  t.assert_eq(2, #jobs, "index invalidation clears failure")
  jobs[2].state = "completed"
  t.wait_until(function()
    return #buffer_marks(bufnr) == 1
  end, 1000, "retry did not render")
end)

t:test("rapid inline off/on can replace a cancellation that has not been acknowledged", function()
  local bufnr = create_buffer(make_repo())
  local jobs = fake_jobs(bufnr)
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
  t.wait_until(function()
    return #jobs == 1
  end, 2000, "first inline query")
  blame.inline_toggle()
  blame.inline_toggle()
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
  t.wait_until(function()
    return #jobs == 2
  end, 2000, "cancelled query was incorrectly reused")
  jobs[1].state, jobs[2].state = "completed", "completed"
  t.wait_until(function()
    return #inline_marks(bufnr) == 1
  end, 1000, "replacement inline mark")
  t.assert_true(inline_marks(bufnr)[1][4].virt_text[1][1]:find("version-2", 1, true) ~= nil, "new inline data")
end)

t:test("cursor-driven overlay refresh validates attachment identity even at the same changedtick", function()
  local bufnr = create_buffer(make_repo(), "f.txt", { "one", "two", "three" })
  local jobs = fake_jobs(bufnr)
  t:defer(function()
    blame.buffer_hide(bufnr)
  end)
  blame.buffer_show(bufnr)
  jobs[1].state = "completed"
  t.wait_until(function()
    return #buffer_marks(bufnr) == 2
  end, 1000, "initial overlay")
  local previous = attached[bufnr]
  attached[bufnr] = vim.tbl_extend("force", {}, previous, { relpath = "g.txt" })
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { 2, 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
  t.wait_until(function()
    return #jobs == 2
  end, 1000, "new attachment must query again")
  t.assert_eq("g.txt", jobs[2].options.path, "replacement pathname")
  jobs[2].state = "completed"
  t.wait_until(function()
    return jobs[2].disposed
  end, 1000, "new attachment result")
end)

t:test("exit disposes blame scheduling and cancels a native query before late completion", function()
  local bufnr = create_buffer(make_repo(), "f.txt", { "one", "two" })
  local jobs = fake_jobs(bufnr)
  blame.buffer_show(bufnr)
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "DotModuleGitBlameInvalidate" })
  t.assert_eq(1, jobs[1].cancelled, "exit cancels the native query")
  jobs[1].state = "completed"
  t.wait_until(function()
    return jobs[1].disposed
  end, 1000, "exit query did not settle")
  t.assert_eq(0, #buffer_marks(bufnr), "late exit result is not rendered")
  blame.buffer_show(bufnr)
  t.assert_eq(1, #jobs, "no new work after exit")
end)

t:run()
