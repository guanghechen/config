require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local git = require("__test__.support.git")
local staging = require("era.m.git.staging")
local Loader = require("era.m.diffview.content").Loader
local Future = stl.c.Future

---A temporary workspace for the case.
---@return string root
local function workspace()
  return diffview.workspace(t, t:tempdir())
end

---A buffer the case deletes; `listed = false` and `scratch = false` match side-by-side buffers.
---@return integer
local function create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr
end

---The open buffer of `path` in the workspace, whose encoding and EOL loaded content follows.
---@param root                          string
---@param path                          string
---@return integer
local function source_buffer(root, path)
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, root .. "/" .. path)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  return bufnr
end

---Loads `object` into `bufnr` and waits for the outcome.
---@param loader                        era.m.diffview.content.Loader
---@param object                        string
---@param bufnr                         integer
---@param opts                          ?era.m.diffview.content.ILoadOpts
---@return boolean ok
---@return boolean content_changed
local function load(loader, object, bufnr, opts)
  local outcome = nil ---@type { [1]: boolean, [2]: boolean }|nil
  stl.async.run(function()
    outcome = { loader:load(object, bufnr, opts) }
  end)
  t.wait_until(function()
    return outcome ~= nil
  end, 5000, "load")
  return assert(outcome)[1], assert(outcome)[2]
end

---Captures the errors reported for the rest of the case.
---@return string[]
local function capture_errors()
  local errors = {} ---@type string[]
  t:patch_table(stl.reporter, "error", function(report)
    errors[#errors + 1] = report.message
  end)
  return errors
end

---Counts buffer rewrites for the rest of the case.
---@return { count: integer }
local function count_writes()
  local writes = { count = 0 }
  local replace_buffer_text = staging.replace_buffer_text
  t:patch_table(staging, "replace_buffer_text", function(...)
    writes.count = writes.count + 1
    return replace_buffer_text(...)
  end)
  return writes
end

t:test("index content is read by the object hash the index holds", function()
  workspace()
  local errors = capture_errors()
  local blob_object, index_path = nil, nil ---@type string|nil, string|nil
  local loader = Loader.new({
    get_file_info = function(_, relpath)
      index_path = relpath
      return Future.resolve({
        ok = true,
        missing = false,
        info = { has_conflicts = false, mode_bits = "100644", object_name = "abc123", relpath = "f.txt" },
      })
    end,
    get_show_blob = function(_, object)
      blob_object = object
      return Future.resolve({ ok = true, missing = false, bytes = "index\n" })
    end,
  })
  local bufnr = create_buffer()

  t.assert_true(load(loader, ":./f.txt", bufnr), "loaded")
  t.assert_eq("./f.txt", index_path, "explicit stage-zero path")
  t.assert_eq("abc123", blob_object, "blob read by captured hash")
  t.assert_eq("abc123", vim.b[bufnr].git_object_name, "buffer snapshot")
  t.assert_eq("abc123", vim.b[bufnr].git_content_object_name, "content identity")
  t.assert_eq("index\n", staging.from_buffer(bufnr).text, "buffer document")
  t.assert_eq(0, #errors, "no errors")
end)

t:test("objects the status snapshot captured are read without resolving them again", function()
  workspace()
  local resolution_calls = 0 ---@type integer
  local blob_objects = {} ---@type string[]
  local loader = Loader.new({
    get_file_info = function()
      resolution_calls = resolution_calls + 1
      return Future.resolve({ ok = false, missing = false, err = "unexpected index resolution" })
    end,
    get_object_name = function()
      resolution_calls = resolution_calls + 1
      return Future.resolve({ ok = false, missing = false, err = "unexpected revision resolution" })
    end,
    get_show_blob = function(_, object)
      blob_objects[#blob_objects + 1] = object
      return Future.resolve({ ok = true, missing = false, bytes = object })
    end,
  })
  local index_bufnr, head_bufnr = create_buffer(), create_buffer()

  local index_ok, index_changed = load(loader, ":./f.txt", index_bufnr, { object_name = "index-snapshot" })
  local head_ok, head_changed = load(loader, "HEAD:f.txt", head_bufnr, { object_name = "head-snapshot" })
  t.assert_true(index_ok and index_changed, "captured index loaded")
  t.assert_true(head_ok and head_changed, "captured revision loaded")
  t.assert_eq(0, resolution_calls, "captured identities skip resolution queries")
  t.assert_eq("index-snapshot", blob_objects[1], "index blob read by captured identity")
  t.assert_eq("head-snapshot", blob_objects[2], "revision blob read by captured identity")
  t.assert_eq("index-snapshot", vim.b[index_bufnr].git_object_name, "partial unstage snapshot retained")
  t.assert_nil(vim.b[head_bufnr].git_object_name, "revision is not an index snapshot")

  local cached_ok, cached_changed = load(loader, ":./f.txt", index_bufnr, { object_name = "index-snapshot" })
  t.assert_true(cached_ok, "captured index cache hit")
  t.assert_false(cached_changed, "captured index cache reports unchanged")
  t.assert_eq(2, #blob_objects, "cache hit skips blob query")
end)

t:test("a buffer is reused only for an identical index object and source format", function()
  local root = workspace()
  local object_name = "abc123" ---@type string
  local blob_calls, before_write_calls = 0, 0 ---@type integer, integer
  local loader = Loader.new({
    get_file_info = function()
      return Future.resolve({ ok = true, info = { has_conflicts = false, object_name = object_name } })
    end,
    get_show_blob = function(_, object)
      blob_calls = blob_calls + 1
      t.assert_eq(object_name, object, "blob read by resolved object")
      return Future.resolve({ ok = true, missing = false, bytes = "index" })
    end,
  })
  local source_bufnr = source_buffer(root, "f.txt")
  local target_bufnr = create_buffer()
  local writes = count_writes()
  local function load_target()
    return load(loader, ":./f.txt", target_bufnr, {
      before_write = function()
        before_write_calls = before_write_calls + 1
      end,
    })
  end

  local initial_ok, initial_changed = load_target()
  t.assert_true(initial_ok, "initial load")
  t.assert_true(initial_changed, "initial load reports rewritten content")
  t.assert_eq(1, blob_calls, "initial blob read")
  t.assert_eq(1, writes.count, "initial buffer write")
  t.assert_eq(1, before_write_calls, "initial before-write hook")
  t.assert_eq("abc123", vim.b[target_bufnr].git_object_name, "object identity")
  t.assert_eq("abc123", vim.b[target_bufnr].git_content_object_name, "content identity")
  t.assert_eq("utf-8", vim.b[target_bufnr].git_source_encoding, "encoding identity")
  t.assert_eq("\n", vim.b[target_bufnr].git_source_default_eol, "EOL identity")

  local cached_ok, cached_changed = load_target()
  t.assert_true(cached_ok, "identical snapshot")
  t.assert_false(cached_changed, "identical snapshot reports unchanged content")
  t.assert_eq(1, blob_calls, "identical snapshot skips blob read")
  t.assert_eq(1, writes.count, "identical snapshot skips buffer write")
  t.assert_eq(1, before_write_calls, "identical snapshot skips before-write hook")

  object_name = "def456"
  local object_ok, object_changed = load_target()
  t.assert_true(object_ok, "changed object")
  t.assert_true(object_changed, "changed object reports rewritten content")
  t.assert_eq(2, blob_calls, "changed object reloads blob")
  t.assert_eq(2, writes.count, "changed object rewrites buffer")

  vim.api.nvim_set_option_value("fileencoding", "latin1", { buf = source_bufnr })
  t.assert_true(load_target(), "changed encoding")
  t.assert_eq(3, blob_calls, "changed encoding reloads blob")
  t.assert_eq(3, writes.count, "changed encoding rewrites buffer")

  vim.api.nvim_set_option_value("fileformat", "dos", { buf = source_bufnr })
  t.assert_true(load_target(), "changed default EOL")
  t.assert_eq(4, blob_calls, "changed EOL reloads blob")
  t.assert_eq(4, writes.count, "changed EOL rewrites buffer")
end)

t:test("HEAD and explicit commit content is cached by the resolved object", function()
  local root = workspace()
  ---@type table<string, string>
  local object_names = { ["HEAD:f.txt"] = "head-a", ["commit:f.txt"] = "commit-a" }
  local resolve_calls, blob_calls = 0, 0 ---@type integer, integer
  local loader = Loader.new({
    get_object_name = function(_, object)
      resolve_calls = resolve_calls + 1
      return Future.resolve({ ok = true, missing = false, object_name = object_names[object] })
    end,
    get_show_blob = function(_, object)
      blob_calls = blob_calls + 1
      return Future.resolve({ ok = true, missing = false, bytes = object })
    end,
  })
  local source_bufnr = source_buffer(root, "f.txt")
  local head_bufnr, commit_bufnr = create_buffer(), create_buffer()
  local writes = count_writes()

  t.assert_true(load(loader, "HEAD:f.txt", head_bufnr), "initial HEAD load")
  t.assert_true(load(loader, "HEAD:f.txt", head_bufnr), "identical HEAD load")
  t.assert_eq(2, resolve_calls, "dynamic HEAD identity is resampled")
  t.assert_eq(1, blob_calls, "identical HEAD skips blob read")
  t.assert_eq(1, writes.count, "identical HEAD skips buffer write")
  t.assert_eq("head-a", vim.b[head_bufnr].git_content_object_name, "HEAD content identity")
  t.assert_nil(vim.b[head_bufnr].git_object_name, "HEAD is not an index snapshot")

  vim.api.nvim_set_option_value("fileencoding", "latin1", { buf = source_bufnr })
  t.assert_true(load(loader, "HEAD:f.txt", head_bufnr), "changed HEAD source format")
  t.assert_eq(2, blob_calls, "changed HEAD format reads blob")
  t.assert_eq(2, writes.count, "changed HEAD format rewrites buffer")

  object_names["HEAD:f.txt"] = "head-b"
  t.assert_true(load(loader, "HEAD:f.txt", head_bufnr), "changed HEAD load")
  t.assert_eq(3, blob_calls, "changed HEAD reads blob")
  t.assert_eq(3, writes.count, "changed HEAD rewrites buffer")
  t.assert_eq("head-b", staging.from_buffer(head_bufnr).text, "changed HEAD content")

  t.assert_true(load(loader, "commit:f.txt", commit_bufnr), "initial commit load")
  t.assert_true(load(loader, "commit:f.txt", commit_bufnr), "identical commit load")
  t.assert_eq(6, resolve_calls, "each revision load resolves an identity")
  t.assert_eq(4, blob_calls, "identical commit skips blob read")
  t.assert_eq(4, writes.count, "identical commit skips buffer write")
  t.assert_eq("commit-a", vim.b[commit_bufnr].git_content_object_name, "commit content identity")
  t.assert_nil(vim.b[commit_bufnr].git_object_name, "commit is not an index snapshot")
end)

t:test("a revision is read by the object it resolved to", function()
  workspace()
  local name_future, resolve_name = Future.new_with_resolver()
  local name_requested = false ---@type boolean
  local blob_object = nil ---@type string|nil
  local loader = Loader.new({
    get_object_name = function()
      name_requested = true
      return name_future
    end,
    get_show_blob = function(_, object)
      blob_object = object
      return Future.resolve({ ok = true, missing = false, bytes = "snapshot-a" })
    end,
  })
  local bufnr = create_buffer()
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = loader:load("HEAD:f.txt", bufnr)
  end)
  t.wait_until(function()
    return name_requested
  end, 5000, "resolution requested")

  resolve_name({ ok = true, missing = false, object_name = "snapshot-a-oid" })
  t.wait_until(function()
    return outcome ~= nil
  end, 5000, "load")

  t.assert_true(outcome, "loaded")
  t.assert_eq("snapshot-a-oid", blob_object, "blob fetch uses the resolved OID")
  t.assert_eq("snapshot-a-oid", vim.b[bufnr].git_content_object_name, "resolved identity committed")
end)

t:test("revision caching never bypasses a failed resolution or request ownership", function()
  workspace()
  local errors = capture_errors()
  local name_future, resolve_name = Future.new_with_resolver()
  local name_requested = false ---@type boolean
  local blob_calls = 0 ---@type integer
  local git = {
    get_object_name = function()
      name_requested = true
      return name_future
    end,
    get_show_blob = function()
      blob_calls = blob_calls + 1
      return Future.resolve({ ok = true, missing = false, bytes = "unexpected" })
    end,
  }
  local loader = Loader.new(git)
  local bufnr = create_buffer()
  local current = true ---@type boolean
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = loader:load("HEAD:f.txt", bufnr, {
      is_current = function()
        return current
      end,
    })
  end)
  t.wait_until(function()
    return name_requested
  end, 5000, "resolution requested")

  current = false
  resolve_name({ ok = true, missing = false, object_name = "head-a" })
  t.wait_until(function()
    return outcome ~= nil
  end, 5000, "load")
  t.assert_false(outcome, "stale resolution rejected")
  t.assert_eq(0, blob_calls, "stale request does not read blob")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "stale request does not commit identity")

  git.get_object_name = function()
    return Future.resolve({ ok = false, missing = false, err = "resolution failed" })
  end
  t.assert_false(load(loader, "HEAD:f.txt", bufnr), "resolution failure rejected")
  t.assert_eq(0, blob_calls, "failed resolution does not read blob")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "failure does not commit identity")
  t.assert_same({ "resolution failed" }, errors, "the failure is reported")

  git.get_object_name = function()
    return Future.resolve({ ok = false, missing = true, err = "object missing" })
  end
  t.assert_true(load(loader, "HEAD:missing.txt", bufnr), "missing revision path becomes empty content")
  t.assert_eq(0, blob_calls, "missing revision path skips blob read")
  t.assert_eq("", staging.from_buffer(bufnr).text, "missing revision content")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "absence is not cached as an object")
end)

t:test("the source format is sampled again after an asynchronous blob read", function()
  local root = workspace()
  local blob_future, resolve_blob = Future.new_with_resolver()
  local blob_requested = false ---@type boolean
  local loader = Loader.new({
    get_file_info = function()
      return Future.resolve({ ok = true, info = { has_conflicts = false, object_name = "abc123" } })
    end,
    get_show_blob = function()
      blob_requested = true
      return blob_future
    end,
  })
  local source_bufnr = source_buffer(root, "f.txt")
  local target_bufnr = create_buffer()
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = loader:load(":./f.txt", target_bufnr)
  end)
  t.wait_until(function()
    return blob_requested
  end, 5000, "blob requested")

  vim.api.nvim_set_option_value("fileencoding", "latin1", { buf = source_bufnr })
  vim.api.nvim_set_option_value("fileformat", "dos", { buf = source_bufnr })
  resolve_blob({ ok = true, missing = false, bytes = "index" })
  t.wait_until(function()
    return outcome ~= nil
  end, 5000, "load")

  t.assert_true(outcome, "loaded")
  t.assert_eq("latin1", vim.b[target_bufnr].git_source_encoding, "latest encoding identity")
  t.assert_eq("\r\n", vim.b[target_bufnr].git_source_default_eol, "latest EOL identity")
  t.assert_eq("latin1", vim.api.nvim_get_option_value("fileencoding", { buf = target_bufnr }), "decoded encoding")
  t.assert_eq("dos", vim.api.nvim_get_option_value("fileformat", { buf = target_bufnr }), "decoded EOL")
end)

t:test("the content identity is cleared before a fallible buffer rewrite", function()
  workspace()
  local object_name = "object-a" ---@type string
  local blob_calls = 0 ---@type integer
  local loader = Loader.new({
    get_file_info = function()
      return Future.resolve({ ok = true, info = { has_conflicts = false, object_name = object_name } })
    end,
    get_show_blob = function(_, object)
      blob_calls = blob_calls + 1
      return Future.resolve({ ok = true, missing = false, bytes = object })
    end,
  })
  local bufnr = create_buffer()

  t.assert_true(load(loader, ":./f.txt", bufnr), "initial object")
  t.assert_eq("object-a", vim.b[bufnr].git_object_name, "initial identity")

  local replace_buffer_text = staging.replace_buffer_text
  local restore_replace = t:patch_table(staging, "replace_buffer_text", function(target_bufnr)
    replace_buffer_text(target_bufnr, "partial")
    error("injected write failure")
  end)
  object_name = "object-b"
  local completed = false ---@type boolean
  local write_ok = nil ---@type boolean|nil
  stl.async.run(function()
    write_ok = pcall(loader.load, loader, ":./f.txt", bufnr)
    completed = true
  end)
  t.wait_until(function()
    return completed
  end, 5000, "failed load")

  t.assert_false(write_ok, "write failure propagated")
  t.assert_nil(vim.b[bufnr].git_object_name, "failed write invalidates object identity")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "failed write invalidates content identity")
  t.assert_nil(vim.b[bufnr].git_source_encoding, "failed write invalidates format identity")
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "failed write reseals buffer")

  restore_replace()
  object_name = "object-a"
  t.assert_true(load(loader, ":./f.txt", bufnr), "original key reloads after failed write")
  t.assert_eq(3, blob_calls, "invalid identity prevents false cache hit")
  t.assert_eq("object-a", staging.from_buffer(bufnr).text, "authoritative content restored")
end)

t:test("index caching never bypasses a failure or request ownership", function()
  workspace()
  local errors = capture_errors()
  local object_name = "abc123" ---@type string
  local blob_calls = 0 ---@type integer
  local fail_blob = true ---@type boolean
  local info_result = { ok = true, info = { has_conflicts = false, object_name = object_name } }
  local git = {
    get_file_info = function()
      return Future.resolve(info_result)
    end,
    get_show_blob = function()
      blob_calls = blob_calls + 1
      if fail_blob then
        return Future.resolve({ ok = false, missing = false, err = "read failed" })
      end
      return Future.resolve({ ok = true, missing = false, bytes = "index" })
    end,
  }
  local loader = Loader.new(git)
  local bufnr = create_buffer()

  t.assert_false(load(loader, ":./f.txt", bufnr), "failed blob read")
  t.assert_nil(vim.b[bufnr].git_object_name, "failure does not commit object identity")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "failure does not commit content identity")
  t.assert_nil(vim.b[bufnr].git_source_encoding, "failure does not commit format identity")
  fail_blob = false
  t.assert_true(load(loader, ":./f.txt", bufnr), "retry after failure")
  t.assert_eq(2, blob_calls, "retry reads blob again")

  info_result = { ok = true, info = { has_conflicts = true, object_name = object_name } }
  t.assert_false(load(loader, ":./f.txt", bufnr), "conflict rejects cached stage-zero object")
  t.assert_eq(2, blob_calls, "conflict does not read blob")
  t.assert_same({ "read failed", "Unable to inspect index object" }, errors, "failures are reported")

  local cancelled_token = {
    is_cancelled = function()
      return true
    end,
  }
  ---@diagnostic disable-next-line: assign-type-mismatch
  t.assert_false(load(loader, ":./f.txt", bufnr, { token = cancelled_token }), "cancelled request rejects cache")
  t.assert_eq(2, blob_calls, "cancelled request does not read blob")

  local pending_info, resolve_info = Future.new_with_resolver()
  git.get_file_info = function()
    return pending_info
  end
  local current = true ---@type boolean
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = loader:load(":./f.txt", bufnr, {
      is_current = function()
        return current
      end,
    })
  end)
  current = false
  resolve_info({ ok = true, info = { has_conflicts = false, object_name = object_name } })
  t.wait_until(function()
    return outcome ~= nil
  end, 5000, "load")
  t.assert_false(outcome, "request made stale while awaiting index info")
  t.assert_eq(2, blob_calls, "stale request does not read blob")
end)

t:test("a stale load cannot overwrite a shared preview buffer", function()
  workspace()
  local loader = Loader.new({
    get_object_name = function()
      return Future.resolve({ ok = true, missing = false, object_name = "head-object" })
    end,
    get_show_blob = function()
      return Future.resolve({ ok = true, bytes = "NEW\n" })
    end,
  })
  local bufnr = create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "OLD" })
  local current = true
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = loader:load("HEAD:f.txt", bufnr, {
      is_current = function()
        return current
      end,
    })
  end)
  current = false
  t.wait_until(function()
    return outcome ~= nil
  end, 5000, "load")

  t.assert_false(outcome, "stale load aborted")
  t.assert_eq("OLD", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "buffer unchanged")
end)

t:test("index content tells a digit-colon filename from an unmerged stage", function()
  local root = diffview.workspace(t, git.repo(t))
  vim.fn.writefile({ "digit-colon" }, root .. "/2:foo")
  vim.fn.writefile({ "plain" }, root .. "/foo")
  git.run(root, { "add", "--all" })
  local loader = Loader.new(require("stl.git.info"))
  local bufnr = create_buffer()
  local selector = require("era.m.diffview.util").staged_object("2:foo") ---@type string

  local outcome = load(loader, selector, bufnr)
  local expected_object = vim.trim(git.run(root, { "rev-parse", ":./2:foo" })) ---@type string
  t.assert_eq(":./2:foo", selector, "explicit stage-zero selector")
  t.assert_true(outcome, "index preview loaded")
  t.assert_eq("digit-colon", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "exact index content")
  t.assert_eq(expected_object, vim.b[bufnr].git_object_name, "authoritative index object")
end)

t:test("revision content caches real blobs and follows HEAD", function()
  local root = diffview.workspace(t, git.repo(t))
  vim.fn.writefile({ "base" }, root .. "/f.txt")
  git.run(root, { "add", "--", "f.txt" })
  git.run(root, { "commit", "-qm", "base" })
  local base_hash = vim.trim(git.run(root, { "rev-parse", "HEAD" })) ---@type string
  local info = require("stl.git.info")
  local blob_calls = 0 ---@type integer
  local loader = Loader.new(setmetatable({
    get_show_blob = function(...)
      blob_calls = blob_calls + 1
      return info.get_show_blob(...)
    end,
  }, { __index = info }))
  local writes = count_writes()
  local head_bufnr, commit_bufnr = create_buffer(), create_buffer()

  t.assert_true(load(loader, "HEAD:f.txt", head_bufnr), "initial HEAD load")
  t.assert_true(load(loader, "HEAD:f.txt", head_bufnr), "cached HEAD load")
  t.assert_eq(1, blob_calls, "cached HEAD skips blob read")
  t.assert_eq(1, writes.count, "cached HEAD skips buffer write")

  vim.fn.writefile({ "next" }, root .. "/f.txt")
  git.run(root, { "commit", "-qam", "next" })
  t.assert_true(load(loader, "HEAD:f.txt", head_bufnr), "changed HEAD load")
  t.assert_eq(2, blob_calls, "changed HEAD reads blob")
  t.assert_eq(2, writes.count, "changed HEAD rewrites buffer")
  t.assert_eq("next\n", staging.from_buffer(head_bufnr).text, "latest HEAD content")

  local commit_object = base_hash .. ":f.txt" ---@type string
  t.assert_true(load(loader, commit_object, commit_bufnr), "initial commit load")
  t.assert_true(load(loader, commit_object, commit_bufnr), "cached commit load")
  t.assert_eq(3, blob_calls, "cached commit skips blob read")
  t.assert_eq(3, writes.count, "cached commit skips buffer write")
  t.assert_eq("base\n", staging.from_buffer(commit_bufnr).text, "commit content")
  t.assert_eq(
    vim.trim(git.run(root, { "rev-parse", commit_object })),
    vim.b[commit_bufnr].git_content_object_name,
    "commit blob identity"
  )
end)

t:run()
