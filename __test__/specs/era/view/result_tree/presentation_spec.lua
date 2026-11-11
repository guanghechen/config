local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
bootstrap.with_native(t)
bootstrap.with_reporter(t)
local picker = require("__test__.support.picker")
local support = require("__test__.support.treeview")
local Source = require("era.view.result_source")

t:test("sparse presentation columns preserve defaults across import chunks and later updates", function()
  local source = Source.new("root", { label = "root" })
  local special = { ["1"] = true, ["513"] = true }
  local tree = picker.result_tree(t, "sparse presentation", source, function(key, data)
    return {
      label = data.label,
      icon = special[key] and "*" or nil,
      score = special[key] and 5 or nil,
      fields = special[key] and { value = key } or nil,
    }
  end)
  for index = 1, 600 do
    local key = tostring(index)
    source:insert("root", key, { label = key })
    tree:insert(key, { nodetype = "leaf" })
  end
  support.applied(tree:publish({ mode = "list", rootuuid = "root", all_rows = true }))
  local before = tree:frame()
  for _, key in ipairs({ "1", "2", "256", "257", "512", "513", "514", "600" }) do
    local node = before:node(before:source():id(key))
    t.assert_eq(special[key] and "*" or nil, node.icon)
    t.assert_eq(special[key] and key or nil, node.fields.value)
  end
  special = { ["2"] = true }
  tree:invalidate()
  support.applied(tree:publish({ mode = "list", rootuuid = "root", all_rows = true }))
  for _, key in ipairs({ "1", "2", "513" }) do
    local frame = tree:frame()
    local node = frame:node(frame:source():id(key))
    t.assert_eq(special[key] and "*" or nil, node.icon)
    t.assert_eq(special[key] and key or nil, node.fields.value)
  end
  t.assert_eq("*", before:node(before:source():id("513")).icon)
end)

t:test("foldempty compacts filtered directory chains and restores their full topology", function()
  local records = {
    { "rust", "root", "container", "rust" },
    { "yoz", "rust", "container", "yoz" },
    { "readme", "rust", "leaf", "README.md" },
    { "src", "yoz", "container", "src" },
    { "manifest", "yoz", "leaf", "Cargo.toml" },
    { "macos", "src", "leaf", "macos.rs" },
    { "linux", "src", "leaf", "linux.rs" },
    { "cargo", "root", "container", ".cargo" },
    { "config", "cargo", "leaf", "config.macos.toml" },
  }
  local source = Source.new("root", { label = "root" })
  for _, record in ipairs(records) do
    source:insert(record[2], record[1], { label = record[4] })
  end
  local tree = picker.result_tree(t, "filtered directory compression", source)
  tree:insert("root", { nodetype = "container" })
  for _, record in ipairs(records) do
    tree:insert(record[1], { nodetype = record[3] })
  end
  local request = {
    mode = "tree",
    rootuuid = "root",
    foldempty = true,
    only_matched = true,
    orders = { "config", "macos" },
  }
  support.applied(tree:publish(request))
  local compact = tree:frame()
  t.assert_eq(4, tree:linecount(), "unmatched siblings must not split the directory chain")
  t.assert_eq("rust/yoz/src", compact:rows(1, 1).labels[1])
  t.assert_eq("src", tree:retrieve_uuid(1), "the deepest directory represents the compact row")
  t.assert_eq("macos", tree:retrieve_uuid(2), "files keep their own row")
  t.assert_eq(2, compact:subtree_end(1), "compressed rows keep their displayed subtree boundary")
  t.assert_eq(4, compact:subtree_end(3))

  request.foldempty = false
  support.applied(tree:publish(request))
  t.assert_eq(6, tree:linecount(), "disabling foldempty restores every matching ancestor")
  request.foldempty = true
  support.applied(tree:publish(request))
  t.assert_eq(4, tree:linecount())
  request.only_matched = false
  support.applied(tree:publish(request))
  t.assert_eq(9, tree:linecount(), "clearing the filter restores the original branching topology")
  t.assert_eq(4, compact:header().row_count, "old frames retain their compressed mapping")
end)

t:run()
