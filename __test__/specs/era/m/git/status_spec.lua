--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/status_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.m.git.status UI")
local info
local calls = {}
bootstrap.with_runtime(t, {
  yoz = require("yoz"),
  era = {
    m = {
      git = {
        state = {
          snapshot = function()
            return {
              lookup = function(_, path, directory)
                calls[#calls + 1] = { path = path, directory = directory }
                return info
              end,
            }
          end,
        },
      },
    },
  },
})
local status = require("era.m.git.status")

t:test("file and directory lookups preserve the literal path at the native boundary", function()
  calls = {}
  info = { codes = 4, display = "M", staged_display = "", stage = "unstaged", summary = "M" }
  local display, highlight = status.resolve("/repo/back\\slash")
  t.assert_eq("M", display, "display")
  t.assert_eq("m_ft_git_unstaged", highlight, "unstaged highlight")
  t.assert_eq("/repo/back\\slash", calls[1].path, "literal POSIX path")
  status.resolve([[C:\repo\dir\]], "directory")
  t.assert_true(calls[2].directory, "directory query")
end)

t:test("mixed untracked and tracked directory codes keep their highlights", function()
  calls = {}
  info = { codes = 6, display = "UM", staged_display = "", stage = "unstaged", summary = "?" }
  local highlights = {}
  local text = status.calc_info("/repo", "directory", 3, highlights)
  t.assert_eq(" UM", text, "formatted status")
  t.assert_eq(1, #calls, "one native lookup per row")
  t.assert_eq(4, highlights[2].coll, "byte offset")
  t.assert_eq("m_ft_git_untracked", highlights[2].hlname, "untracked U")
  t.assert_eq("m_ft_git_change", highlights[3].hlname, "modified M")
end)

t:test("staged segments and conflicts retain UI priority", function()
  info = { codes = 4, display = "MM", staged_display = "M", stage = "mixed", summary = "M" }
  local highlights = {}
  status.calc_info("/repo/file", "file", 0, highlights)
  t.assert_eq("m_ft_git_staged", highlights[2].hlname, "staged segment")
  t.assert_eq("m_ft_git_change", highlights[3].hlname, "unstaged segment")
  info = { codes = 5, display = "UM", staged_display = "", stage = "mixed", summary = "U" }
  local _, highlight = status.resolve("/repo/file")
  t.assert_eq("m_ft_git_unmerged", highlight, "conflict priority")
end)

t:test("missing status leaves the row unchanged", function()
  info = nil
  local highlights = {}
  t.assert_eq("", status.calc_info("/repo/missing", "file", 0, highlights), "empty status")
  t.assert_eq(0, #highlights, "no status highlights")
  t.assert_nil(status.resolve(""), "empty path")
end)

t:run()
