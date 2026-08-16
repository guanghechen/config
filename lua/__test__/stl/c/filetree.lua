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

    local stack = { tree.root }
    local stack_size = 1
    while stack_size > 0 do
      local uuid = stack[stack_size]
      stack[stack_size] = nil
      stack_size = stack_size - 1
      local data = tree:get(uuid)
      t.assert_false(data.filepath:find("\\", 1, true) ~= nil, "slash-only node filepath")
      for _, childuuid in ipairs(tree:children(uuid) or {}) do
        stack_size = stack_size + 1
        stack[stack_size] = childuuid
      end
    end
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

t:test("strict topology keeps filesystem ordering feature-owned", function()
  local tree = Filetree.new({ name = "order" })
  local root = tree:children(tree.root)[1]
  local zfile = tree:insert_file_absolute("/z.lua")
  local bdir = tree:insert_directory_absolute("/b")
  local afile = tree:insert_file_absolute("/a.lua")
  local adir = tree:insert_directory_absolute("/a")

  local children = tree:children(root)
  t.assert_eq(adir.uuid, children[1], "alphabetical first directory")
  t.assert_eq(bdir.uuid, children[2], "alphabetical second directory")
  t.assert_eq(afile.uuid, children[3], "alphabetical first file")
  t.assert_eq(zfile.uuid, children[4], "alphabetical second file")
end)

t:test("empty reset preserves the actual filesystem root", function()
  local tree = Filetree.new({ name = "empty-reset" })
  tree:reset("/workspace", {}, false)
  local root = tree:children(tree.root)[1]
  t.assert_true(root ~= nil, "actual root remains after empty reset")
  local file = tree:insert_file_absolute("/after.lua")
  t.assert_true(file ~= nil and tree:contains(file.uuid), "insert works after empty reset")
end)

t:test("clear preserves the actual filesystem root", function()
  local tree = Filetree.new({ name = "clear" })
  tree:insert_file_absolute("/before.lua")
  tree:clear()
  local root = tree:children(tree.root)[1]
  t.assert_true(root ~= nil, "actual root remains after clear")
  local file = tree:insert_file_absolute("/after.lua")
  t.assert_true(file ~= nil and tree:contains(file.uuid), "insert works after clear")
end)

t:run()
