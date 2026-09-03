---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/partial_unstage.lua

local bootstrap = require("__test__.bootstrap")
local Future = require("stl.c.future")
local harness = require("__test__.harness")
local staging = require("era.m.git.staging")

local t = harness.new("era.m.diffview.partial_unstage")
local errors = {} ---@type string[]

bootstrap.with_global(t, "stl", {
  env = { PATH_SEP = "/" },
  async = require("stl.async"),
  c = { Future = Future },
  git = { info = {} },
  nvim = { buf = {
    locate_bufnr = function()
      return nil
    end,
  } },
  reporter = {
    error = function(report)
      errors[#errors + 1] = report.message
    end,
    warn = function(report)
      errors[#errors + 1] = report.message
    end,
  },
})
bootstrap.with_global(t, "dot", {
  path = {
    join = function(...)
      return table.concat({ ... }, "/")
    end,
    workspace = function()
      return "/repo"
    end,
  },
})
bootstrap.with_global(t, "era", { m = { diffview = {}, git = { staging = staging } } })

local config = {
  BUFOPTS_PANEL = {},
  BUFOPTS_SBS = {},
  FT = { SBS = "diffview-test" },
  TRACKED_WINOPTS = {},
  WINOPTS_SBS = { foldlevel = 0 },
}
bootstrap.with_global(t, "yoz", {})
t:patch_table(package.loaded, "era.m.diffview.config", config)
t:patch_table(package.loaded, "era.m.diffview.util", {
  workspace_path = function(filepath)
    return "/repo/" .. filepath
  end,
})

---@param predicate                     fun(): boolean
local function wait(predicate)
  t.wait_until(predicate, 5000, "async operation")
end

t:test("pane loader binds index bytes to the captured object hash", function()
  local blob_object = nil ---@type string|nil
  local index_path = nil ---@type string|nil
  stl.git.info.get_file_info = function(_, relpath)
    index_path = relpath
    return Future.resolve({
      ok = true,
      missing = false,
      info = {
        has_conflicts = false,
        mode_bits = "100644",
        object_name = "abc123",
        relpath = "f.txt",
      },
    })
  end
  stl.git.info.get_show_blob = function(_, object)
    blob_object = object
    return Future.resolve({ ok = true, missing = false, bytes = "index\n" })
  end

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = pane.load_git_content(":./f.txt", bufnr)
  end)
  wait(function()
    return outcome ~= nil
  end)

  t.assert_true(outcome, "loaded")
  t.assert_eq("./f.txt", index_path, "explicit stage-zero path")
  t.assert_eq("abc123", blob_object, "blob read by captured hash")
  t.assert_eq("abc123", vim.b[bufnr].git_object_name, "buffer snapshot")
  t.assert_eq("abc123", vim.b[bufnr].git_content_object_name, "content identity")
  t.assert_eq("index\n", staging.from_buffer(bufnr).text, "buffer document")
  t.assert_eq(0, #errors, "no errors")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("pane loader consumes status snapshot identities without resolving them again", function()
  local resolution_calls = 0 ---@type integer
  local blob_objects = {} ---@type string[]
  t:patch_table(stl.git.info, "get_file_info", function()
    resolution_calls = resolution_calls + 1
    return Future.resolve({ ok = false, missing = false, err = "unexpected index resolution" })
  end)
  t:patch_table(stl.git.info, "get_object_name", function()
    resolution_calls = resolution_calls + 1
    return Future.resolve({ ok = false, missing = false, err = "unexpected revision resolution" })
  end)
  t:patch_table(stl.git.info, "get_show_blob", function(_, object)
    blob_objects[#blob_objects + 1] = object
    return Future.resolve({ ok = true, missing = false, bytes = object })
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local index_bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local head_bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local function load(object, bufnr, object_name)
    local outcome = nil ---@type boolean|nil
    local content_changed = nil ---@type boolean|nil
    stl.async.run(function()
      outcome, content_changed = pane.load_git_content(object, bufnr, nil, nil, nil, object_name)
    end)
    wait(function()
      return outcome ~= nil
    end)
    return outcome, content_changed
  end

  local index_ok, index_changed = load(":./f.txt", index_bufnr, "index-snapshot")
  local head_ok, head_changed = load("HEAD:f.txt", head_bufnr, "head-snapshot")
  t.assert_true(index_ok and index_changed, "captured index loaded")
  t.assert_true(head_ok and head_changed, "captured revision loaded")
  t.assert_eq(0, resolution_calls, "captured identities skip resolution queries")
  t.assert_eq("index-snapshot", blob_objects[1], "index blob read by captured identity")
  t.assert_eq("head-snapshot", blob_objects[2], "revision blob read by captured identity")
  t.assert_eq("index-snapshot", vim.b[index_bufnr].git_object_name, "partial unstage snapshot retained")
  t.assert_nil(vim.b[head_bufnr].git_object_name, "revision is not an index snapshot")

  local cached_ok, cached_changed = load(":./f.txt", index_bufnr, "index-snapshot")
  t.assert_true(cached_ok, "captured index cache hit")
  t.assert_false(cached_changed, "captured index cache reports unchanged")
  t.assert_eq(2, #blob_objects, "cache hit skips blob query")

  vim.api.nvim_buf_delete(index_bufnr, { force = true })
  vim.api.nvim_buf_delete(head_bufnr, { force = true })
end)

t:test("workspace action forwards the right-buffer index snapshot", function()
  local captured = nil ---@type table|nil
  local opened = false ---@type boolean
  local refreshed = false ---@type boolean
  local workspace_view = {
    open_entry = function()
      opened = true
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.data", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", workspace_view)

  ---@diagnostic disable-next-line: missing-fields
  era.m.diffview = {
    util = {
      gen_index_bufname = function(filepath)
        return "diffview://index/" .. filepath
      end,
    },
  }
  era.m.git.buffer = {
    unstage_range = function(opts)
      captured = opts
      return Future.resolve({ ok = true })
    end,
  }

  local action = assert(loadfile("lua/era/m/diffview/view/workspace/action.lua"))()

  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  vim.api.nvim_buf_set_name(bufnr, "diffview://index/f.txt")
  staging.replace_buffer_text(bufnr, "INDEX\n")
  vim.b[bufnr].git_object_name = "abc123"
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  local entry = { filepath = "f.txt", stage_type = "staged", status = "M" }
  local ctx = {
    layout = { sbs_right_winnr = winnr },
    state = {
      request_refresh = function()
        refreshed = true
      end,
      get_current_entry = function()
        return entry
      end,
    },
  }

  local future = action.unstage_hunk(ctx, { 2, 3 })

  t.assert_true(future ~= nil, "unstage future")
  t.assert_true(captured ~= nil, "unstage called")
  local unstage_opts = assert(captured)
  t.assert_eq("abc123", unstage_opts.expected_index.object_name, "object snapshot")
  t.assert_eq("INDEX\n", unstage_opts.expected_index.document.text, "document snapshot")
  t.assert_eq(2, unstage_opts.range[1], "range start")
  t.assert_eq(3, unstage_opts.range[2], "range end")
  t.assert_true(refreshed, "view refreshed")
  t.assert_false(opened, "refresh owns reopening")
  t.assert_eq(0, #errors, "no errors")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("pane loader reuses only an identical index object and source format", function()
  local object_name = "abc123" ---@type string
  local blob_calls = 0 ---@type integer
  local write_calls = 0 ---@type integer
  local before_write_calls = 0 ---@type integer
  t:patch_table(stl.git.info, "get_file_info", function()
    return Future.resolve({
      ok = true,
      info = {
        has_conflicts = false,
        object_name = object_name,
      },
    })
  end)
  t:patch_table(stl.git.info, "get_show_blob", function(_, object)
    blob_calls = blob_calls + 1
    t.assert_eq(object_name, object, "blob read by resolved object")
    return Future.resolve({ ok = true, missing = false, bytes = "index" })
  end)

  local source_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local target_bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:patch_table(stl.nvim.buf, "locate_bufnr", function()
    return source_bufnr
  end)
  local replace_buffer_text = staging.replace_buffer_text
  t:patch_table(staging, "replace_buffer_text", function(...)
    write_calls = write_calls + 1
    return replace_buffer_text(...)
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local function load()
    local outcome = nil ---@type boolean|nil
    local content_changed = nil ---@type boolean|nil
    stl.async.run(function()
      outcome, content_changed = pane.load_git_content(":./f.txt", target_bufnr, nil, nil, function()
        before_write_calls = before_write_calls + 1
      end)
    end)
    wait(function()
      return outcome ~= nil
    end)
    return outcome, content_changed
  end

  local initial_ok, initial_changed = load()
  t.assert_true(initial_ok, "initial load")
  t.assert_true(initial_changed, "initial load reports rewritten content")
  t.assert_eq(1, blob_calls, "initial blob read")
  t.assert_eq(1, write_calls, "initial buffer write")
  t.assert_eq(1, before_write_calls, "initial before-write hook")
  t.assert_eq("abc123", vim.b[target_bufnr].git_object_name, "object identity")
  t.assert_eq("abc123", vim.b[target_bufnr].git_content_object_name, "content identity")
  t.assert_eq("utf-8", vim.b[target_bufnr].git_source_encoding, "encoding identity")
  t.assert_eq("\n", vim.b[target_bufnr].git_source_default_eol, "EOL identity")

  local cached_ok, cached_changed = load()
  t.assert_true(cached_ok, "identical snapshot")
  t.assert_false(cached_changed, "identical snapshot reports unchanged content")
  t.assert_eq(1, blob_calls, "identical snapshot skips blob read")
  t.assert_eq(1, write_calls, "identical snapshot skips buffer write")
  t.assert_eq(1, before_write_calls, "identical snapshot skips before-write hook")

  object_name = "def456"
  local object_ok, object_changed = load()
  t.assert_true(object_ok, "changed object")
  t.assert_true(object_changed, "changed object reports rewritten content")
  t.assert_eq(2, blob_calls, "changed object reloads blob")
  t.assert_eq(2, write_calls, "changed object rewrites buffer")

  vim.api.nvim_set_option_value("fileencoding", "latin1", { buf = source_bufnr })
  t.assert_true(load(), "changed encoding")
  t.assert_eq(3, blob_calls, "changed encoding reloads blob")
  t.assert_eq(3, write_calls, "changed encoding rewrites buffer")

  vim.api.nvim_set_option_value("fileformat", "dos", { buf = source_bufnr })
  t.assert_true(load(), "changed default EOL")
  t.assert_eq(4, blob_calls, "changed EOL reloads blob")
  t.assert_eq(4, write_calls, "changed EOL rewrites buffer")

  vim.api.nvim_buf_delete(source_bufnr, { force = true })
  vim.api.nvim_buf_delete(target_bufnr, { force = true })
end)

t:test("pane loader caches HEAD and explicit commit content by resolved object", function()
  ---@type table<string, string>
  local object_names = {
    ["HEAD:f.txt"] = "head-a",
    ["commit:f.txt"] = "commit-a",
  }
  local resolve_calls = 0 ---@type integer
  local blob_calls = 0 ---@type integer
  local write_calls = 0 ---@type integer
  t:patch_table(stl.git.info, "get_object_name", function(_, object)
    resolve_calls = resolve_calls + 1
    return Future.resolve({ ok = true, missing = false, object_name = object_names[object] })
  end)
  t:patch_table(stl.git.info, "get_show_blob", function(_, object)
    blob_calls = blob_calls + 1
    return Future.resolve({ ok = true, missing = false, bytes = object })
  end)

  local source_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local head_bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local commit_bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:patch_table(stl.nvim.buf, "locate_bufnr", function()
    return source_bufnr
  end)
  local replace_buffer_text = staging.replace_buffer_text
  t:patch_table(staging, "replace_buffer_text", function(...)
    write_calls = write_calls + 1
    return replace_buffer_text(...)
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local function load(object, bufnr)
    local outcome = nil ---@type boolean|nil
    stl.async.run(function()
      outcome = pane.load_git_content(object, bufnr)
    end)
    wait(function()
      return outcome ~= nil
    end)
    return outcome
  end

  t.assert_true(load("HEAD:f.txt", head_bufnr), "initial HEAD load")
  t.assert_true(load("HEAD:f.txt", head_bufnr), "identical HEAD load")
  t.assert_eq(2, resolve_calls, "dynamic HEAD identity is resampled")
  t.assert_eq(1, blob_calls, "identical HEAD skips blob read")
  t.assert_eq(1, write_calls, "identical HEAD skips buffer write")
  t.assert_eq("head-a", vim.b[head_bufnr].git_content_object_name, "HEAD content identity")
  t.assert_nil(vim.b[head_bufnr].git_object_name, "HEAD is not an index snapshot")

  vim.api.nvim_set_option_value("fileencoding", "latin1", { buf = source_bufnr })
  t.assert_true(load("HEAD:f.txt", head_bufnr), "changed HEAD source format")
  t.assert_eq(2, blob_calls, "changed HEAD format reads blob")
  t.assert_eq(2, write_calls, "changed HEAD format rewrites buffer")

  object_names["HEAD:f.txt"] = "head-b"
  t.assert_true(load("HEAD:f.txt", head_bufnr), "changed HEAD load")
  t.assert_eq(3, blob_calls, "changed HEAD reads blob")
  t.assert_eq(3, write_calls, "changed HEAD rewrites buffer")
  t.assert_eq("head-b", staging.from_buffer(head_bufnr).text, "changed HEAD content")

  t.assert_true(load("commit:f.txt", commit_bufnr), "initial commit load")
  t.assert_true(load("commit:f.txt", commit_bufnr), "identical commit load")
  t.assert_eq(6, resolve_calls, "each revision load resolves an identity")
  t.assert_eq(4, blob_calls, "identical commit skips blob read")
  t.assert_eq(4, write_calls, "identical commit skips buffer write")
  t.assert_eq("commit-a", vim.b[commit_bufnr].git_content_object_name, "commit content identity")
  t.assert_nil(vim.b[commit_bufnr].git_object_name, "commit is not an index snapshot")

  vim.api.nvim_buf_delete(source_bufnr, { force = true })
  vim.api.nvim_buf_delete(head_bufnr, { force = true })
  vim.api.nvim_buf_delete(commit_bufnr, { force = true })
end)

t:test("pane revision loader binds fetch to the resolved snapshot", function()
  local name_future, resolve_name = Future.new_with_resolver()
  local name_requested = false ---@type boolean
  local blob_object = nil ---@type string|nil
  t:patch_table(stl.git.info, "get_object_name", function()
    name_requested = true
    return name_future
  end)
  t:patch_table(stl.git.info, "get_show_blob", function(_, object)
    blob_object = object
    return Future.resolve({ ok = true, missing = false, bytes = "snapshot-a" })
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = pane.load_git_content("HEAD:f.txt", bufnr)
  end)
  wait(function()
    return name_requested
  end)

  resolve_name({ ok = true, missing = false, object_name = "snapshot-a-oid" })
  wait(function()
    return outcome ~= nil
  end)

  t.assert_true(outcome, "loaded")
  t.assert_eq("snapshot-a-oid", blob_object, "blob fetch uses the resolved OID")
  t.assert_eq("snapshot-a-oid", vim.b[bufnr].git_content_object_name, "resolved identity committed")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("pane revision cache never bypasses resolution failure or request ownership", function()
  local name_future, resolve_name = Future.new_with_resolver()
  local name_requested = false ---@type boolean
  local blob_calls = 0 ---@type integer
  t:patch_table(stl.git.info, "get_object_name", function()
    name_requested = true
    return name_future
  end)
  t:patch_table(stl.git.info, "get_show_blob", function()
    blob_calls = blob_calls + 1
    return Future.resolve({ ok = true, missing = false, bytes = "unexpected" })
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local current = true ---@type boolean
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = pane.load_git_content("HEAD:f.txt", bufnr, nil, function()
      return current
    end)
  end)
  wait(function()
    return name_requested
  end)

  current = false
  resolve_name({ ok = true, missing = false, object_name = "head-a" })
  wait(function()
    return outcome ~= nil
  end)
  t.assert_false(outcome, "stale resolution rejected")
  t.assert_eq(0, blob_calls, "stale request does not read blob")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "stale request does not commit identity")

  t:patch_table(stl.git.info, "get_object_name", function()
    return Future.resolve({ ok = false, missing = false, err = "resolution failed" })
  end)
  current = true
  outcome = nil
  stl.async.run(function()
    outcome = pane.load_git_content("HEAD:f.txt", bufnr)
  end)
  wait(function()
    return outcome ~= nil
  end)
  t.assert_false(outcome, "resolution failure rejected")
  t.assert_eq(0, blob_calls, "failed resolution does not read blob")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "failure does not commit identity")

  t:patch_table(stl.git.info, "get_object_name", function()
    return Future.resolve({ ok = false, missing = true, err = "object missing" })
  end)
  outcome = nil
  stl.async.run(function()
    outcome = pane.load_git_content("HEAD:missing.txt", bufnr)
  end)
  wait(function()
    return outcome ~= nil
  end)
  t.assert_true(outcome, "missing revision path becomes empty content")
  t.assert_eq(0, blob_calls, "missing revision path skips blob read")
  t.assert_eq("", staging.from_buffer(bufnr).text, "missing revision content")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "absence is not cached as an object")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("pane loader resamples source format after an asynchronous blob read", function()
  t:patch_table(stl.git.info, "get_file_info", function()
    return Future.resolve({
      ok = true,
      info = {
        has_conflicts = false,
        object_name = "abc123",
      },
    })
  end)
  local blob_future, resolve_blob = Future.new_with_resolver()
  local blob_requested = false ---@type boolean
  t:patch_table(stl.git.info, "get_show_blob", function()
    blob_requested = true
    return blob_future
  end)

  local source_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local target_bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:patch_table(stl.nvim.buf, "locate_bufnr", function()
    return source_bufnr
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = pane.load_git_content(":./f.txt", target_bufnr)
  end)
  wait(function()
    return blob_requested
  end)

  vim.api.nvim_set_option_value("fileencoding", "latin1", { buf = source_bufnr })
  vim.api.nvim_set_option_value("fileformat", "dos", { buf = source_bufnr })
  resolve_blob({ ok = true, missing = false, bytes = "index" })
  wait(function()
    return outcome ~= nil
  end)

  t.assert_true(outcome, "loaded")
  t.assert_eq("latin1", vim.b[target_bufnr].git_source_encoding, "latest encoding identity")
  t.assert_eq("\r\n", vim.b[target_bufnr].git_source_default_eol, "latest EOL identity")
  t.assert_eq("latin1", vim.api.nvim_get_option_value("fileencoding", { buf = target_bufnr }), "decoded encoding")
  t.assert_eq("dos", vim.api.nvim_get_option_value("fileformat", { buf = target_bufnr }), "decoded EOL")

  vim.api.nvim_buf_delete(source_bufnr, { force = true })
  vim.api.nvim_buf_delete(target_bufnr, { force = true })
end)

t:test("pane loader invalidates identity before a fallible buffer rewrite", function()
  local object_name = "object-a" ---@type string
  local blob_calls = 0 ---@type integer
  t:patch_table(stl.git.info, "get_file_info", function()
    return Future.resolve({
      ok = true,
      info = {
        has_conflicts = false,
        object_name = object_name,
      },
    })
  end)
  t:patch_table(stl.git.info, "get_show_blob", function(_, object)
    blob_calls = blob_calls + 1
    return Future.resolve({ ok = true, missing = false, bytes = object })
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local function load()
    local outcome = nil ---@type boolean|nil
    stl.async.run(function()
      outcome = pane.load_git_content(":./f.txt", bufnr)
    end)
    wait(function()
      return outcome ~= nil
    end)
    return outcome
  end

  t.assert_true(load(), "initial object")
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
    write_ok = pcall(pane.load_git_content, ":./f.txt", bufnr)
    completed = true
  end)
  wait(function()
    return completed
  end)

  t.assert_false(write_ok, "write failure propagated")
  t.assert_nil(vim.b[bufnr].git_object_name, "failed write invalidates object identity")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "failed write invalidates content identity")
  t.assert_nil(vim.b[bufnr].git_source_encoding, "failed write invalidates format identity")
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = bufnr }), "failed write reseals buffer")

  restore_replace()
  object_name = "object-a"
  t.assert_true(load(), "original key reloads after failed write")
  t.assert_eq(3, blob_calls, "invalid identity prevents false cache hit")
  t.assert_eq("object-a", staging.from_buffer(bufnr).text, "authoritative content restored")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("pane index cache never bypasses failure or request ownership", function()
  local object_name = "abc123" ---@type string
  local blob_calls = 0 ---@type integer
  local fail_blob = true ---@type boolean
  local info_result = {
    ok = true,
    info = {
      has_conflicts = false,
      object_name = object_name,
    },
  }
  t:patch_table(stl.git.info, "get_file_info", function()
    return Future.resolve(info_result)
  end)
  t:patch_table(stl.git.info, "get_show_blob", function()
    blob_calls = blob_calls + 1
    if fail_blob then
      return Future.resolve({ ok = false, missing = false, err = "read failed" })
    end
    return Future.resolve({ ok = true, missing = false, bytes = "index" })
  end)

  local pane = assert(loadfile("lua/era/m/diffview/pane/sbs.lua"))()
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  local function load(token, is_current)
    local outcome = nil ---@type boolean|nil
    stl.async.run(function()
      outcome = pane.load_git_content(":./f.txt", bufnr, token, is_current)
    end)
    wait(function()
      return outcome ~= nil
    end)
    return outcome
  end

  t.assert_false(load(), "failed blob read")
  t.assert_nil(vim.b[bufnr].git_object_name, "failure does not commit object identity")
  t.assert_nil(vim.b[bufnr].git_content_object_name, "failure does not commit content identity")
  t.assert_nil(vim.b[bufnr].git_source_encoding, "failure does not commit format identity")
  fail_blob = false
  t.assert_true(load(), "retry after failure")
  t.assert_eq(2, blob_calls, "retry reads blob again")

  info_result = {
    ok = true,
    info = {
      has_conflicts = true,
      object_name = object_name,
    },
  }
  t.assert_false(load(), "conflict rejects cached stage-zero object")
  t.assert_eq(2, blob_calls, "conflict does not read blob")

  local cancelled_token = {
    is_cancelled = function()
      return true
    end,
  }
  t.assert_false(load(cancelled_token), "cancelled request rejects cache")
  t.assert_eq(2, blob_calls, "cancelled request does not read blob")

  local pending_info, resolve_info = Future.new_with_resolver()
  t:patch_table(stl.git.info, "get_file_info", function()
    return pending_info
  end)
  local current = true ---@type boolean
  local outcome = nil ---@type boolean|nil
  stl.async.run(function()
    outcome = pane.load_git_content(":./f.txt", bufnr, nil, function()
      return current
    end)
  end)
  current = false
  resolve_info({
    ok = true,
    info = {
      has_conflicts = false,
      object_name = object_name,
    },
  })
  wait(function()
    return outcome ~= nil
  end)
  t.assert_false(outcome, "request made stale while awaiting index info")
  t.assert_eq(2, blob_calls, "stale request does not read blob")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("workspace keymaps route normal and visual ghu", function()
  local calls = {} ---@type table[]
  local action = {
    unstage_hunk = function(_, range)
      calls[#calls + 1] = range or {}
      return Future.resolve({ ok = true })
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", action)
  stl.nvim.buf.retrieve_visual_lnum_range = function()
    return 4, 6
  end

  local keymap = assert(loadfile("lua/era/m/diffview/view/workspace/keymap.lua"))()
  local normal = nil ---@type table|nil
  local visual = nil ---@type table|nil
  for _, mapping in ipairs(keymap.gen_sbs({})) do
    if mapping.key == "ghu" and mapping.modes[1] == "n" then
      normal = mapping
    elseif mapping.key == "ghu" and mapping.modes[1] == "x" then
      visual = mapping
    end
  end

  t.assert_true(normal ~= nil, "normal mapping")
  t.assert_true(visual ~= nil, "visual mapping")
  assert(normal).callback()
  assert(visual).callback()
  t.assert_eq(0, #calls[1], "normal cursor range")
  t.assert_eq(4, calls[2][1], "visual start")
  t.assert_eq(6, calls[2][2], "visual end")
end)

t:test("visual ghu exits only after a successful unstage", function()
  local resolve_unstage = nil ---@type (fun(result: table): nil)|nil
  local action = {
    unstage_hunk = function()
      local future, resolve = Future.new_with_resolver()
      resolve_unstage = resolve
      return future
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", action)
  stl.nvim.buf.retrieve_visual_lnum_range = function()
    return 1, 1
  end

  local keymap = assert(loadfile("lua/era/m/diffview/view/workspace/keymap.lua"))()
  local visual = nil ---@type table|nil
  for _, mapping in ipairs(keymap.gen_sbs({})) do
    if mapping.key == "ghu" and mapping.modes[1] == "x" then
      visual = mapping
      break
    end
  end
  t.assert_true(visual ~= nil, "visual mapping")

  local test_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, { "one", "two" })
  vim.api.nvim_win_set_buf(0, test_bufnr)

  vim.cmd("normal! V")
  assert(visual).callback()
  t.assert_eq("V", vim.fn.mode(), "selection while pending")
  assert(resolve_unstage)({ ok = true })
  t.assert_eq("n", vim.fn.mode(), "selection cleared after success")

  vim.cmd("normal! V")
  assert(visual).callback()
  assert(resolve_unstage)({ ok = false, err = "failed" })
  t.assert_eq("V", vim.fn.mode(), "selection retained after failure")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

  vim.cmd("normal! ggV")
  assert(visual).callback()
  vim.cmd("normal! j")
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = test_bufnr })
  vim.cmd("normal! k")
  assert(resolve_unstage)({ ok = true })
  t.assert_eq("V", vim.fn.mode(), "changed then restored selection retained after success")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

  vim.cmd("normal! V")
  assert(visual).callback()
  local resolve_older_unstage = assert(resolve_unstage)
  assert(visual).callback()
  local resolve_newer_unstage = assert(resolve_unstage)
  resolve_older_unstage({ ok = true })
  t.assert_eq("V", vim.fn.mode(), "older unstage keeps newer selection")
  resolve_newer_unstage({ ok = true })
  t.assert_eq("n", vim.fn.mode(), "newer unstage clears unchanged selection")
  vim.api.nvim_buf_delete(test_bufnr, { force = true })
end)

t:test("workspace view binds keymaps after replacing null buffers", function()
  local mapped = {} ---@type integer[]
  local pane = {
    open_diff_entry = function(opts)
      local left_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      local right_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      vim.api.nvim_win_set_buf(opts.left_winnr, left_bufnr)
      vim.api.nvim_win_set_buf(opts.right_winnr, right_bufnr)
    end,
  }
  local keymap = {
    setup_sbs = function(_, bufnr)
      mapped[#mapped + 1] = bufnr
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.config", {})
  t:patch_table(package.loaded, "era.m.diffview.layout", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.commits", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", pane)
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.keymap", keymap)

  vim.cmd("vnew")
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vnew")
  local right_winnr = vim.api.nvim_get_current_win() ---@type integer
  local view = assert(loadfile("lua/era/m/diffview/view/workspace/view.lua"))()
  view.open_entry({
    layout = { sbs_left_winnr = left_winnr, sbs_right_winnr = right_winnr },
    state = {
      get_fold_unchanged = function()
        return true
      end,
      is_disposed = function()
        return false
      end,
    },
  }, {})

  t.assert_eq(2, #mapped, "mapped buffers")
  t.assert_eq(vim.api.nvim_win_get_buf(left_winnr), mapped[1], "left replacement")
  t.assert_eq(vim.api.nvim_win_get_buf(right_winnr), mapped[2], "right replacement")
  vim.api.nvim_win_close(right_winnr, true)
  vim.api.nvim_win_close(left_winnr, true)
end)

t:run()
