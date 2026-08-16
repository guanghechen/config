---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/stl/c/tree_retriever.lua

local harness = require("__test__.harness")
local TreeRetriever = require("stl.c.tree_retriever")
local treeview = require("stl.view.treeview")

local t = harness.new("stl.c.tree_retriever")

t:test("attach: switches between flat maps and TreeLayout", function()
  local retriever = TreeRetriever.new({ name = "test" })
  retriever:attach(1, { "a", "b" }, { a = 1, b = 2 }, { 2, 2 })
  t.assert_eq(2, retriever:linecount(), "flat line count")
  t.assert_eq("a", retriever:retrieve_uuid(1), "flat ID")
  t.assert_eq(2, retriever:retrieve_lnum("b"), "flat line")
  t.assert_eq(2, retriever:retrieve_lastchild_lnum(1), "flat range")

  local layout = treeview.layout({
    roots = { "root" },
    children = function(uuid)
      return ({ root = { "branch" }, branch = { "leaf" }, leaf = {} })[uuid]
    end,
    can_fold = function(parentuuid)
      return parentuuid == "root"
    end,
  })
  retriever:attach_layout(2, layout, { [1] = 2 })
  t.assert_eq(2, retriever:linecount(), "layout line count")
  t.assert_eq("branch", retriever:retrieve_uuid(1), "layout representative")
  t.assert_eq(1, retriever:retrieve_lnum("root"), "folded layout ID")
  t.assert_eq(1, retriever:retrieve_lnum("branch"), "layout representative line")
  t.assert_eq(2, retriever:retrieve_lastchild_lnum(1), "layout range metadata")

  retriever:attach(3, { "x" }, { x = 1 }, nil)
  t.assert_eq("x", retriever:retrieve_uuid(1), "flat reattach ID")
  t.assert_nil(retriever:retrieve_lnum("root"), "flat reattach clears layout")
end)

t:run()
