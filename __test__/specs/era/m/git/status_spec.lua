local bootstrap = require("__test__.support.bootstrap")
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

t:run()
