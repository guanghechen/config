require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Jobs = require("era.m.filetree.jobs")
local Future = require("stl.c.future")
local await = require("__test__.support.treeview").await

---@return table
---@return string
local function fixture()
  local directory = t:tempdir()
  vim.fn.mkdir(directory .. "/parent/root", "p")
  return await(Jobs.capture(directory .. "/parent/root")), directory
end

t:test("create uses its captured directory for nested paths and parent inputs", function()
  local captured, directory = fixture()
  local nested = await(Jobs.create(captured.data, captured.resource, "nested/deeper/file.lua", false))
  t.assert_true(nested.success, nested.error)
  t.assert_eq("file", vim.uv.fs_stat(directory .. "/parent/root/nested/deeper/file.lua").type)
  local sibling = await(Jobs.create(captured.data, captured.resource, "../sibling/empty", true))
  t.assert_true(sibling.success, sibling.error)
  t.assert_eq("directory", vim.uv.fs_stat(directory .. "/parent/sibling/empty").type)
  t.assert_false(Jobs.pending())
end)

t:test("parent inputs cannot rebind an ancestor replaced after capture", function()
  local captured, directory = fixture()
  assert(vim.uv.fs_rename(directory .. "/parent", directory .. "/original"))
  vim.fn.mkdir(directory .. "/parent/root", "p")
  local result = await(Jobs.create(captured.data, captured.resource, "../created.txt", false))
  t.assert_false(result.success)
  t.assert_true(result.error ~= nil, "stale ancestor must be reported")
  t.assert_nil(vim.uv.fs_stat(directory .. "/parent/created.txt"))
  t.assert_nil(vim.uv.fs_stat(directory .. "/original/created.txt"))
  t.assert_false(Jobs.pending())
end)

t:test("an explicit target on another volume resolves the new directory", function()
  local destination = newproxy(false)
  local requested, plan
  local data = {
    resolve = function(_, path)
      requested = path
      return Future.resolve(destination)
    end,
  }
  t:patch_table(Jobs, "run", function(_, value)
    plan = value
    return Future.resolve({ success = true })
  end)
  local result = await(Jobs.create(data, {}, "D:/archive/created.txt", false))
  t.assert_true(result.success)
  t.assert_eq("D:/archive", requested)
  t.assert_true(plan.target == destination)
  t.assert_eq("created.txt", plan.path)
  t.assert_false(plan.directory)
end)

t:run()
