---@diagnostic disable: undefined-global
--- Test for stl.c.filetree module
--- Run with: nvim -l lua/__test__/stl/c/filetree.lua

local harness = require("__test__.harness")

local t = harness.new("stl.c.filetree")

t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))

local Filetree = require("stl.c.filetree")

---@param name                          string
---@param callback                      fun(tree: stl.c.Filetree)
local function with_tree(name, callback)
  local tree = Filetree.new({ name = name })
  local ok, err = pcall(callback, tree)
  tree:dispose()
  if not ok then
    error(err, 0)
  end
end

t:test("UUID and node identity canonicalize Windows separator ingress", function()
  local canonical = "C:/workspace/project/src/main.lua"
  local os_path = [[C:\workspace\project\src\main.lua]]
  local canonical_dir = "C:/workspace/project/src"
  local os_dir = [[C:\workspace\project\src\]]
  local calls = 0 ---@type integer
  local original = yoz.canonical_path.from_os_path

  t:patch_table(yoz.canonical_path, "from_os_path", function(filepath, keep_trailing_slash)
    calls = calls + 1
    return original(filepath, keep_trailing_slash)
  end)

  local canonical_uuid = Filetree.uuid(canonical)
  t.assert_eq(0, calls, "canonical UUID fast path")
  t.assert_eq(canonical_uuid, Filetree.uuid(os_path), "OS and canonical UUID")
  t.assert_eq(1, calls, "OS UUID conversion count")
  t.assert_eq(Filetree.uuid(canonical_dir), Filetree.uuid(os_dir), "trailing directory UUID")
  t.assert_eq(2, calls, "OS directory conversion count")

  local data, nodeuuid = Filetree.resolve(os_path, "file", true)
  t.assert_eq(canonical_uuid, nodeuuid, "resolved UUID")
  t.assert_eq(canonical, data.filepath, "resolved canonical filepath")
  t.assert_eq(3, calls, "OS resolve conversion count")
end)

t:test("reset stores slash-only relative and location identities", function()
  local cwd = stl.env.IS_WIN and [[C:\workspace\project\]] or "/workspace/project/"
  local canonical_cwd = stl.env.IS_WIN and "C:/workspace/project" or "/workspace/project"

  local expected = {
    canonical_cwd .. "/src/main.lua",
    canonical_cwd .. "/src/lib/util.lua",
    canonical_cwd .. "/test/spec.lua",
    canonical_cwd .. "/space dir/项目/#notes.lua",
  } ---@type string[]

  with_tree("canonical-reset", function(tree)
    tree:reset(cwd, {
      "src/main.lua:12:3:7",
      [[src\lib\util.lua]],
      "src/../test/spec.lua",
      "space dir/项目/#notes.lua",
    }, true)

    local cwdnode = tree:retrieve(Filetree.uuid(canonical_cwd))
    t.assert_true(cwdnode ~= nil and cwdnode.data.filetype == "directory", "canonical cwd node")

    for _, filepath in ipairs(expected) do
      local node = tree:retrieve(Filetree.uuid(filepath))
      t.assert_true(node ~= nil, "node exists: " .. filepath)
      t.assert_eq(filepath, node.data.filepath, "stored filepath")
    end

    tree:unsafe_traverse(nil, function(ctx)
      for _, node in pairs(ctx.nodemap) do
        t.assert_false(node.data.filepath:find("\\", 1, true) ~= nil, "slash-only node filepath")
      end
    end)
  end)
end)

t:test("reset stores slash-only drive and UNC-style identities", function()
  local cwd = stl.env.IS_WIN and [[C:\workspace\project\]] or "/workspace/project/"
  local absolute = stl.env.IS_WIN and [[C:\workspace\project\absolute.lua]] or "/workspace/project/absolute.lua"
  local outside = stl.env.IS_WIN and [[D:\archive\outside.lua]] or "/archive/outside.lua"
  local unc = stl.env.IS_WIN and [[\\server\share\remote.lua]] or "//server/share/remote.lua"
  local expected = {
    stl.env.IS_WIN and "C:/workspace/project/absolute.lua" or "/workspace/project/absolute.lua",
    stl.env.IS_WIN and "D:/archive/outside.lua" or "/archive/outside.lua",
    "/server/share/remote.lua",
  } ---@type string[]

  with_tree("canonical-absolute-reset", function(tree)
    tree:reset(cwd, { absolute, outside, unc }, false)

    for _, filepath in ipairs(expected) do
      local node = tree:retrieve(Filetree.uuid(filepath))
      t.assert_true(node ~= nil, "node exists: " .. filepath)
      t.assert_eq(filepath, node.data.filepath, "stored filepath")
    end
  end)
end)

t:run()
