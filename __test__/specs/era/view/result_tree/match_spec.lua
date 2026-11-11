local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
bootstrap.with_native(t)
local reports = bootstrap.with_reporter(t)
local picker = require("__test__.support.picker")
local Source = require("era.view.result_source")

t:test("regex matching lists entries with a nonempty match in source order and marks each match", function()
  local tree = picker.branch_tree(t)
  ---@param pattern                     string
  ---@param case_sensitive              boolean
  ---@return string[]
  local function keys(pattern, case_sensitive)
    local orders = tree:match({
      rootuuid = "root",
      pattern = pattern,
      fuzzy = false,
      regex = true,
      case_sensitive = case_sensitive,
    })
    return type(orders) == "userdata" and orders:keys() or orders
  end
  t.assert_same({ "two", "three" }, keys("[tw]", true))
  t.assert_same({ { l = 0, r = 2 } }, tree._result:highlight("two"), "adjacent matches mark one run")
  t.assert_same({ { l = 0, r = 1 } }, tree._result:highlight("three"))
  t.assert_same({}, keys("T", true))
  t.assert_same({ "two", "three" }, keys("T", false), "case-insensitive unless asked")
  t.assert_same({}, keys("x*", true), "a match of nothing does not count")
  t.assert_same({ "one", "two", "three" }, keys("", true), "an empty regex lists every entry")
  t.assert_same({}, reports.error)
  t.assert_same({}, keys("(", true), "an invalid regex matches nothing")
  t.assert_eq(1, #reports.error)
  t.assert_true(reports.error[1].message:find("Invalid regex pattern", 1, true) ~= nil, "and says why")
  table.remove(reports.error)
end)

---A result tree over `lua/a.lua` and `spec/b.md` under `root`.
---@param root                          string
---@return era.view.ResultTree
local function paths(root)
  local source = Source.new("root", { label = "root", filepath = root })
  source:insert("root", "a", { label = "a.lua", filepath = root .. "/lua/a.lua" })
  source:insert("root", "b", { label = "b.md", filepath = root .. "/spec/b.md" })
  local tree = picker.result_tree(t, "paths", source)
  tree:insert("root", { nodetype = "container" })
  tree:insert("a", { nodetype = "leaf" })
  tree:insert("b", { nodetype = "leaf" })
  return tree
end

---@param tree                          era.view.ResultTree
---@param pattern                       string
---@param fuzzy                         boolean
---@param regex                         boolean
---@return string[]
local function matched(tree, pattern, fuzzy, regex)
  local orders =
    tree:match({ rootuuid = "root", pattern = pattern, fuzzy = fuzzy, regex = regex, case_sensitive = true })
  return type(orders) == "userdata" and orders:keys() or orders
end

t:test("regex matching reads file paths relative to the root", function()
  local tree = paths("/w")
  t.assert_same({ "a" }, matched(tree, "^lua/", false, true))
  t.assert_same({ { l = 0, r = 4 } }, tree._result:highlight("a"), "ranges of the relative path")
  t.assert_same({ "a", "b" }, matched(tree, "/", false, true))
  t.assert_same({}, matched(tree, "w/", false, true), "the root's own path is not matched")
end)

t:test("a query naming a path under the root reads it relative to the root", function()
  local root = vim.uv.os_homedir() .. "/.cfg"
  local tree = paths(root)
  t.assert_same({ "a" }, matched(tree, root .. "/lua/a.lua", true, false), "a fuzzy term")
  t.assert_same({ "b" }, matched(tree, "spec !" .. root .. "/lua", false, false), "an exact term with its marks")
  t.assert_same({ "a" }, matched(tree, "^" .. root .. "/lua/", false, true), "an anchored regex")
  t.assert_same({ "a" }, matched(tree, "~/.cfg/lua", false, false), "~ for the home directory")
  t.assert_same({ "a", "b" }, matched(tree, "^" .. root .. "/", false, true), "the root alone matches every entry")
  t.assert_same({ "a", "b" }, matched(tree, root, true, false))
  t.assert_same({}, matched(tree, "/elsewhere" .. root .. "/lua", false, true), "a path outside the root stays")
  local dotted = paths("/w.x")
  t.assert_same({ "b" }, matched(dotted, [[^/w\.x/spec/b\.md$]], false, true), "a regex with the root escaped")
  t.assert_same({ "b" }, matched(dotted, "/w.x/spec", false, true), "or as is")
end)

t:run()
