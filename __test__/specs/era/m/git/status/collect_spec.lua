local bootstrap = require("__test__.support.bootstrap")
local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")
local t = harness.new()
bootstrap.with_runtime(t, { yoz = require("yoz") })
local status = require("era.m.git.status")

---A snapshot whose lookup records each query and answers `info`.
---@param info                          table|nil
---@return table snapshot
---@return { path: string, directory: boolean }[] calls
local function snapshot_of(info)
  local calls = {} ---@type { path: string, directory: boolean }[]
  return {
    lookup = function(_, path, directory)
      calls[#calls + 1] = { path = path, directory = directory }
      return info
    end,
  },
    calls
end

t:test("file and directory lookups preserve the literal path at the native boundary", function()
  local snapshot, calls =
    snapshot_of({ codes = 4, display = "M", staged_display = "", stage = "unstaged", summary = "M" })
  local text, highlight = status.calc_info(snapshot, "/repo/back\\slash", "file", 0, {})
  t.assert_eq(" M", text, "display")
  t.assert_eq("m_ft_git_unstaged", highlight, "unstaged highlight")
  t.assert_eq("/repo/back\\slash", calls[1].path, "literal POSIX path")
  status.calc_info(snapshot, [[C:\repo\dir\]], "directory", 0, {})
  t.assert_true(calls[2].directory, "directory query")
end)

t:test("mixed untracked and tracked directory codes keep their highlights", function()
  local snapshot, calls =
    snapshot_of({ codes = 6, display = "UM", staged_display = "", stage = "unstaged", summary = "?" })
  local highlights = {}
  local text = status.calc_info(snapshot, "/repo", "directory", 3, highlights)
  t.assert_eq(" UM", text, "formatted status")
  t.assert_eq(1, #calls, "one native lookup per row")
  t.assert_eq(4, highlights[2].coll, "byte offset")
  t.assert_eq("m_ft_git_untracked", highlights[2].hlname, "untracked U")
  t.assert_eq("m_ft_git_change", highlights[3].hlname, "modified M")
end)

t:test("staged segments and conflicts retain UI priority", function()
  local highlights = {}
  local mixed = snapshot_of({ codes = 4, display = "MM", staged_display = "M", stage = "mixed", summary = "M" })
  status.calc_info(mixed, "/repo/file", "file", 0, highlights)
  t.assert_eq("m_ft_git_staged", highlights[2].hlname, "staged segment")
  t.assert_eq("m_ft_git_change", highlights[3].hlname, "unstaged segment")
  local conflict = snapshot_of({ codes = 5, display = "UM", staged_display = "", stage = "mixed", summary = "U" })
  local _, highlight = status.calc_info(conflict, "/repo/file", "file", 0, {})
  t.assert_eq("m_ft_git_unmerged", highlight, "conflict priority")
end)

t:test("missing status leaves the row unchanged", function()
  local highlights = {}
  t.assert_eq("", status.calc_info(snapshot_of(nil), "/repo/missing", "file", 0, highlights), "empty status")
  t.assert_eq(0, #highlights, "no status highlights")
  local snapshot, calls = snapshot_of({ codes = 4, display = "M", staged_display = "", stage = "unstaged" })
  t.assert_eq("", status.calc_info(snapshot, "", "file", 0, {}), "empty path")
  t.assert_eq(0, #calls, "an empty path is not looked up")
end)

---A native status job, running until the case sets its `state`, that `status.collect` starts in the workspace /repo
---for the rest of the case.
---@return table
local function status_job()
  git_buffer.with_futures(t)
  local job = { state = "running", cancelled = 0, disposed = 0, snapshot = {} }
  ---@return string
  ---@return table
  function job:poll()
    return self.state, self.snapshot
  end
  ---@return nil
  function job:cancel()
    self.cancelled = self.cancelled + 1
    self.state = "cancelled"
  end
  ---@return nil
  function job:dispose()
    self.disposed = self.disposed + 1
  end
  bootstrap.with_runtime(t, {
    dot = {
      path = {
        workspace = function()
          return "/repo"
        end,
        is_git_repo = function()
          return true
        end,
      },
    },
    yoz = {
      git = {
        start_status = function(options)
          job.options = options
          return job
        end,
      },
    },
  })
  return job
end

t:test("native snapshot is published without materializing its entries", function()
  local job = status_job()
  local future = status.collect({ base = "HEAD", include_numstat = true, include_untracked = false })
  t.assert_false(future:is_done(), "running job")
  t.assert_eq("/repo", job.options.cwd, "workspace captured")
  t.assert_false(job.options.include_untracked, "untracked exclusion")
  t.assert_true(job.options.include_numstat, "numstat request")
  t.assert_eq("HEAD", job.options.base, "base")
  job.state = "completed"
  t.settle(future)
  t.assert_true(future:get_result() == job.snapshot, "native handle passed through")
  t.assert_eq(1, job.disposed, "completed job disposed")
end)

t:test("a collection's cancellation token reaches its native job", function()
  local job = status_job()
  local token = stl.c.CancellationToken.new()
  local future = status.collect(nil, token)
  token:cancel()
  job.state = "completed"
  t.settle(future)
  t.assert_eq(1, job.cancelled, "native cancel requested")
  t.assert_true(future:is_failed(), "stale completion rejected")
  t.assert_eq(1, job.disposed, "cancelled job disposed")
end)

t:run()
