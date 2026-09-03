---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/data_log_page.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.data_log_page")
local calls = {} ---@type string[][]
local results = {} ---@type stl.git.exec.IResult[]

bootstrap.with_global(t, "stl", {
  git = {
    exec = {
      exec = function(args)
        calls[#calls + 1] = args
        local result = table.remove(results, 1)
        return {
          await = function()
            return result
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
t:patch_table(package.loaded, "era.m.diffview.commit_graph", assert(loadfile("lua/era/m/diffview/commit_graph.lua"))())

local data = assert(loadfile("lua/era/m/diffview/data.lua"))()

local function log_line(hash, abbrev, parents, author, message)
  return table.concat({ hash, abbrev, parents, author, "2026-09-03 12:00:00 +0800", message }, "\0")
end

t:test("page metadata keeps graph continuity from earlier commits", function()
  calls = {}
  results = {
    {
      code = 0,
      lines = {
        log_line("1", "1111", "2 3", "Jesse Duffield", ":sparkles: merge"),
        log_line("2", "2222", "3", "Alice", "side"),
        log_line("3", "3333", "4", "Bob", "join"),
        log_line("4", "4444", "", "Carol", "root"),
      },
      stderr = "",
    },
    { code = 0, lines = {}, stderr = "" },
  }

  local commits = data.fetch_log_page(2, 2, nil)

  t.assert_eq(2, #commits, "page size")
  t.assert_eq("3", commits[1].hash, "first page commit")
  t.assert_eq("○─╯", commits[1].graph, "graph retains prior merge lane")
  t.assert_eq("○", commits[2].graph, "linear graph tail")
  t.assert_eq("4", commits[1].parents[1], "parent metadata")
  t.assert_eq(
    "log --topo-order --pretty=format:%H%x00%h%x00%P%x00%an%x00%ai%x00%s -n 4",
    table.concat(calls[1], " "),
    "cumulative metadata query"
  )
  t.assert_eq(
    "log --topo-order --pretty=format:%H --shortstat --skip=2 -n 2",
    table.concat(calls[2], " "),
    "page-scoped shortstat query"
  )
end)

t:test("path-filtered history keeps commit topology disabled", function()
  calls = {}
  results = {
    {
      code = 0,
      lines = {
        log_line("1", "1111", "", "Alice", ":bug: filtered"),
        "M\tlua/a.lua",
        "",
      },
      stderr = "",
    },
    { code = 0, lines = {}, stderr = "" },
    { code = 0, lines = {}, stderr = "" },
  }

  local commits = data.fetch_log_page(1, 100, "lua/a.lua")

  t.assert_eq(1, #commits, "filtered page size")
  t.assert_nil(commits[1].graph, "filtered commits have no graph")
  t.assert_eq("lua/a.lua", commits[1].filepath, "filtered filepath")
  t.assert_eq(
    "log --topo-order --pretty=format:%H%x00%h%x00%P%x00%an%x00%ai%x00%s --name-status --follow --skip=0 -n 100 -- lua/a.lua",
    table.concat(calls[1], " "),
    "filtered metadata query"
  )
end)

t:run()
