---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/data_log.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.data_log")
local git_args = {} ---@type string[]
local git_cwd = nil ---@type string|nil
local git_result = { code = 0, lines = {}, stderr = "" } ---@type stl.git.exec.IResult

bootstrap.with_global(t, "stl", {
  git = {
    exec = {
      exec = function(args, opts)
        git_args = args
        git_cwd = opts.cwd
        return {
          await = function()
            return git_result
          end,
        }
      end,
    },
  },
})
bootstrap.with_global(t, "dot", {
  path = {
    workspace = function()
      return "/repo"
    end,
  },
})
bootstrap.with_global(t, "era", {})

local data = assert(loadfile("lua/era/m/diffview/data.lua"))()

t:test("log search: hash prefix takes precedence over an earlier message match", function()
  git_result = {
    code = 0,
    lines = {
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\0mention b268 in docs",
      "b26839d69ead84834128d8490e7c2d65447de712\0preserve split layouts",
    },
    stderr = "",
  }

  local match, err = data.find_log_commit("B26839D", nil)

  t.assert_nil(err, "search error")
  t.assert_eq("b26839d69ead84834128d8490e7c2d65447de712", match.hash, "matched hash")
  t.assert_eq(2, match.position, "log position")
  t.assert_eq(2, match.total, "log total")
  t.assert_eq("log --pretty=format:%H%x00%s", table.concat(git_args, " "), "git arguments")
  t.assert_eq("/repo", git_cwd, "git cwd")
end)

t:test("log search: message matching is case insensitive and respects path history", function()
  git_result = {
    code = 0,
    lines = {
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\0unrelated",
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\0Preserve Split Layouts",
    },
    stderr = "",
  }

  local match, err = data.find_log_commit("split layouts", "lua/ark/autocmd.lua")

  t.assert_nil(err, "search error")
  t.assert_eq("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", match.hash, "matched message")
  t.assert_eq(2, match.position, "log position")
  t.assert_eq(2, match.total, "log total")
  t.assert_eq(
    "log --pretty=format:%H%x00%s --follow -- lua/ark/autocmd.lua",
    table.concat(git_args, " "),
    "path-filtered arguments"
  )
end)

t:test("log search: failures preserve actionable Git context", function()
  git_result = { code = 128, lines = {}, stderr = "fatal: bad revision" }

  local match, err = data.find_log_commit("missing", nil)

  t.assert_nil(match, "failed match")
  t.assert_eq("fatal: bad revision", err, "git error")
end)

t:test("log search: ambiguous hash prefixes are rejected", function()
  git_result = {
    code = 0,
    lines = {
      "dead111111111111111111111111111111111111\0newer",
      "dead222222222222222222222222222222222222\0older",
    },
    stderr = "",
  }

  local match, err = data.find_log_commit("dead", nil)

  t.assert_nil(match, "ambiguous match")
  t.assert_eq("Ambiguous commit hash prefix: dead", err, "ambiguity error")
end)

t:run()
