---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.filetree.git" ---@type string

local fixture = require("__test__.support.filetree").new("ux.filetree.git")
local t, filetree = fixture.t, fixture.filetree
local await, write, directory = fixture.await, fixture.write, fixture.directory
local native = fixture.native

t:test("Git and ignored native snapshots are consumed without exporting their entries", function()
  local path = directory()
  write(path .. "/a")
  write(path .. "/ignored")
  vim.fn.writefile({ "ignored" }, path .. "/.gitignore")
  for _, args in ipairs({ { "git", "-C", path, "init", "-q" }, { "git", "-C", path, "add", "a" } }) do
    local result = vim.system(args, { text = true }):wait()
    t.assert_eq(0, result.code, result.stderr)
  end
  local job = native.git.start_status({ cwd = path })
  t:defer(function()
    job:dispose()
  end)
  local snapshot
  t.wait_until(function()
    local status, value, error = job:poll()
    t.assert_false(status == "failed", error)
    snapshot = value
    return status == "completed"
  end, 10000)
  local cache = native.git.ignore_cache(path)
  local ignoring = cache:start({ path .. "/ignored" })
  t:defer(function()
    ignoring:dispose()
  end)
  t.wait_until(function()
    local status, _, error = ignoring:poll()
    t.assert_false(status == "failed", error)
    return status == "completed"
  end, 10000)
  local data = await(filetree.open(path))
  await(data:resolve(path .. "/a"))
  await(data:resolve(path .. "/ignored"))
  local state = await(data:create_state(nil, { show_hidden = false }))
  local frame = state:snapshot()
  await(data:set_git(path, 1, snapshot, cache))
  local rows = await(data:annotations(frame, 1, 2))
  t.assert_true(bit.band(rows.rows[1].git, native.git.codes.A) ~= 0)
  t.assert_true(bit.band(rows.rows[2].git, native.git.codes["!"]) ~= 0)
  t.assert_eq(1, await(data:next_annotation(frame, 1, "git", true)))
  cache:clear()
  t.assert_true(bit.band(await(data:annotations(frame, 2, 2)).rows[1].git, native.git.codes["!"]) ~= 0)
  await(data:set_git(path, 2, snapshot, cache))
  t.assert_eq(0, bit.band(await(data:annotations(frame, 2, 2)).rows[1].git, native.git.codes["!"]))
  await(data:set_git(path, 3))
  t.assert_eq(0, await(data:next_annotation(frame, 0, "git", true)))
  t.assert_eq(frame:id(), state:snapshot():id())
end)

t:run()
