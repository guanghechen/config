---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/commit_graph.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.commit_graph")
local graph = assert(loadfile("lua/era/m/diffview/commit_graph.lua"))()

---@param hash string
---@param parents string[]
---@return era.m.diffview.commit_graph.INode
local function commit(hash, parents)
  return { hash = hash, parents = parents }
end

t:test("renders lazygit's compact merge topology", function()
  local lines = graph.render({
    commit("1", { "2", "3" }),
    commit("2", { "3" }),
    commit("3", { "4" }),
    commit("4", { "5" }),
    commit("5", { "7" }),
  })

  t.assert_eq("◎─╮", lines[1], "merge starts a side lane")
  t.assert_eq("○ │", lines[2], "side lane continues")
  t.assert_eq("○─╯", lines[3], "side lane rejoins")
  t.assert_eq("○", lines[4], "linear commit")
  t.assert_eq("○", lines[5], "linear tail")
end)

t:test("keeps unrelated roots in distinct lanes", function()
  local lines = graph.render({
    commit("a", { "b" }),
    commit("x", { "y" }),
    commit("b", {}),
  })

  t.assert_eq("○", lines[1], "first root")
  t.assert_eq("│ ○", lines[2], "unrelated root")
  t.assert_eq("○ │", lines[3], "first root resumes")
end)

t:test("compacts merge lanes when space opens on the left", function()
  local lines = graph.render({
    commit("1", { "2" }),
    commit("2", { "3", "4" }),
    commit("4", { "3", "5" }),
    commit("3", { "5" }),
    commit("5", { "6" }),
    commit("6", { "7" }),
  })

  t.assert_eq("○", lines[1], "linear head")
  t.assert_eq("◎─╮", lines[2], "first merge")
  t.assert_eq("│ ◎─╮", lines[3], "nested merge")
  t.assert_eq("○─╯ │", lines[4], "first lane closes")
  t.assert_eq("○───╯", lines[5], "remaining lane compacts")
  t.assert_eq("○", lines[6], "linear tail")
end)

t:run()
