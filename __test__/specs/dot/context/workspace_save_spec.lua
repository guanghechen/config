require("ark.bootstrap").setup()
local bootstrap = require("__test__.support.bootstrap")
local t = require("__test__.support.harness").new()

---A workspace state file in a new directory, set as the storage of this instance.
---@return string
local function storage()
  local filepath = vim.fs.joinpath(t:tempdir(), "workspace.json")
  dot.context.set_storage({ workspace = filepath })
  return filepath
end

---@param filepath                      string
---@return string
local function identity(filepath)
  local stat = assert(vim.uv.fs_stat(filepath))
  return string.format("%d:%d.%09d", stat.ino, stat.mtime.sec, stat.mtime.nsec)
end

t:test("saving keeps the fields that an instance saving since changed", function()
  local filepath = storage()
  dot.context.load({ workspace = filepath })
  local expandtab = not dot.context.option.expandtab:snapshot()
  dot.context.option.expandtab:next(expandtab)
  stl.fs.write_json(filepath, { bookmark = { pinned = { "/other/README.md" } } }, true)

  dot.context.save({ workspace = filepath })

  local saved = assert(stl.fs.read_json({ filepath = filepath }))
  t.assert_eq("/other/README.md", saved.bookmark.pinned[1], "the other instance's bookmark")
  t.assert_eq(expandtab, saved.option.expandtab, "this instance's option")
end)

t:test("instances that change different settings of one picker keep both", function()
  local filepath = storage()
  dot.context.load({ workspace = filepath })
  local gitignore = not dot.context.select.find_file.flag_gitignore:snapshot()
  dot.context.select.find_file.flag_gitignore:next(gitignore)
  stl.fs.write_json(filepath, { select = { find_file = { search_pattern = "other" } } }, true)

  dot.context.save({ workspace = filepath })

  local saved = assert(stl.fs.read_json({ filepath = filepath }))
  t.assert_eq("other", saved.select.find_file.search_pattern, "the other instance's search")
  t.assert_eq(gitignore, saved.select.find_file.flag_gitignore, "this instance's filter")
  t.assert_eq(nil, saved["select.find_file"], "the picker is written back in place")
end)

t:test("an instance that changed nothing leaves the file alone", function()
  local filepath = storage()
  stl.fs.write_json(filepath, { bookmark = { pinned = { "/kept.md" } } }, true)
  dot.context.load({ workspace = filepath })
  local written = identity(filepath)

  dot.context.save({ workspace = filepath })

  t.assert_eq(written, identity(filepath))
end)

t:test("a value that is not UTF-8 loads and saves byte for byte", function()
  local filepath = storage()
  stl.fs.write_json(filepath, { bookmark = { pinned = { "/srv/caf\xe9.txt" } } }, true)
  dot.context.load({ workspace = filepath })
  dot.context.option.relativenumber:next(not dot.context.option.relativenumber:snapshot())

  dot.context.save({ workspace = filepath })

  t.assert_eq("/srv/caf\xe9.txt", assert(stl.fs.read_json({ filepath = filepath })).bookmark.pinned[1])
end)

t:test("the first save of a workspace takes the lock in the directory it creates", function()
  local filepath = vim.fs.joinpath(t:tempdir(), "workspaces", "repo", "workspace.json")
  dot.context.set_storage({ workspace = filepath })
  dot.context.load({ workspace = filepath })
  dot.context.bookmark.pinned:next({ "/first.md" })
  local reports = bootstrap.with_reporter(t)

  dot.context.save({ workspace = filepath })

  t.assert_eq(0, #reports.warn, "saved under the lock")
  t.assert_eq("/first.md", assert(stl.fs.read_json({ filepath = filepath })).bookmark.pinned[1])
end)

t:test("a held lock delays the save until it times out, and the save still lands", function()
  local filepath = storage()
  dot.context.load({ workspace = filepath })
  dot.context.bookmark.pinned:next({ "/mine.md" })
  local held = assert(yoz.fs.lock(filepath .. ".lock", 0))
  local reports = bootstrap.with_reporter(t)

  local started = vim.uv.hrtime()
  dot.context.save({ workspace = filepath })
  held:unlock()

  t.assert_true((vim.uv.hrtime() - started) / 1e6 >= 2000, "waited for the holder")
  t.assert_eq(1, #reports.warn, "saving without the lock is reported")
  t.assert_eq("/mine.md", assert(stl.fs.read_json({ filepath = filepath })).bookmark.pinned[1])
  local free = assert(yoz.fs.lock(filepath .. ".lock", 0), "the save released its hold")
  free:unlock()
end)

t:run()
