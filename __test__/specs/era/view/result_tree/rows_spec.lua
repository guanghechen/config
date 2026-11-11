local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
bootstrap.with_native(t)
bootstrap.with_reporter(t)
local picker = require("__test__.support.picker")
local support = require("__test__.support.treeview")

t:test("bulk row reads retain metadata and page identities without exporting node payloads", function()
  local tree = picker.branch_tree(t)
  local keys = {}
  for index = 1, 2050 do
    local key = "bulk-" .. index
    keys[index] = key
    tree.source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf", text = key })
  end
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = keys }))
  local frame = tree:frame()
  local pages = 0
  local proxy = setmetatable({}, {
    __index = function(_, name)
      return function(_, ...)
        t.assert_false(name == "node" or name == "rows" or name == "flags", "identity reads must omit " .. name)
        if name == "row_keys" then
          pages = pages + 1
        end
        return frame[name](frame, ...)
      end
    end,
  })
  local iterator = tree:iter_rows(proxy, 1, #keys)
  tree.source:update(keys[2], { label = "replacement" })
  tree:insert(keys[2], { nodetype = "leaf", text = "replacement" })
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = keys }))
  local count = 0
  for row, key, data, entry in iterator do
    count = count + 1
    t.assert_eq(count, row)
    t.assert_eq(keys[row], key)
    t.assert_eq(key, data.label)
    t.assert_eq(key, entry.text)
  end
  t.assert_eq(#keys, count)
  t.assert_eq(3, pages)
end)

t:test("row iteration resumes after short byte-limited pages without losing metadata or identities", function()
  local tree = picker.branch_tree(t)
  local keys = {}
  for index = 1, 2500 do
    local key = (index <= 1024 and "short-" or string.rep("界", 600)) .. index
    keys[index] = key
    tree.source:insert("root", key, { label = tostring(index) })
    tree:insert(key, { nodetype = "leaf", text = tostring(index) })
  end
  support.applied(tree:publish({ mode = "list", rootuuid = "root", orders = keys }))
  local frame = tree:frame()
  local pages, count = 0, 0
  local proxy = setmetatable({}, {
    __index = function(_, name)
      return function(_, ...)
        if name == "row_keys" then
          pages = pages + 1
        end
        return frame[name](frame, ...)
      end
    end,
  })
  for row, key, data, entry in tree:iter_rows(proxy) do
    count = count + 1
    t.assert_eq(count, row)
    t.assert_eq(keys[row], key)
    t.assert_eq(tostring(row), data.label)
    t.assert_eq(tostring(row), entry.text)
  end
  t.assert_eq(#keys, count)
  t.assert_eq(4, pages, "short keys retain full pages and long keys consume only the required pages")
end)

t:test("cold key and subtree reads export no full nodes or decorated rows", function()
  local tree = picker.branch_tree(t)
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local frame = tree:frame()
  tree._versions[frame:header().data_revision].keys = {}
  local reads = 0
  local proxy = setmetatable({}, {
    __index = function(_, name)
      return function(_, ...)
        reads = reads + 1
        t.assert_false(name == "node" or name == "rows" or name == "flags", "structural reads must omit " .. name)
        return frame[name](frame, ...)
      end
    end,
  })
  t.assert_eq("dir", tree:retrieve_uuid(1, proxy))
  t.assert_eq(3, tree:retrieve_lastchild_lnum(1, proxy))
  t.assert_nil(tree:retrieve_lastchild_lnum(0, proxy))
  t.assert_nil(tree:retrieve_lastchild_lnum(-1, proxy))
  t.assert_nil(tree:retrieve_lastchild_lnum(5, proxy))
  t.assert_true(reads > 0, "the supplied Frame owns these reads")
end)

t:test("root and source parent reads follow the captured Frame rather than a pending root or producer", function()
  local tree = picker.branch_tree(t)
  support.applied(tree:publish({ mode = "tree", rootuuid = "root" }))
  local original = tree:frame()
  support.applied(tree:publish({ mode = "tree", rootuuid = "dir" }))
  local nested = tree:frame()
  t.assert_eq(original:header().data_revision, nested:header().data_revision)
  t.assert_eq("root", tree:root_key(original))
  t.assert_eq("dir", tree:root_key(nested))
  tree.source:move("one", "root")
  t.assert_eq("dir", tree:parent_key("one", nested))
  t.assert_eq("root", tree:parent_key(tree:root_key(nested), nested))
  t.assert_nil(tree:parent_key("root", nested))
  t.assert_nil(tree:parent_key("missing", nested))
end)

t:run()
