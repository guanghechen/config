---@diagnostic disable: undefined-global
--- Test for era.m.git.state module
--- Run with: nvim -l lua/__test__/era/m/git/state.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.git.state")
local workspace = "/project" ---@type string

local function normalize(filepath, keep_trailing_slash)
  local had_trailing_slash = filepath:sub(-1) == "/" or filepath:sub(-1) == "\\" ---@type boolean
  local normalized = filepath:gsub("\\", "/"):gsub("/+", "/") ---@type string
  if keep_trailing_slash == false and normalized ~= "/" then
    normalized = normalized:gsub("/+$", "")
  elseif keep_trailing_slash ~= false and had_trailing_slash and normalized:sub(-1) ~= "/" then
    normalized = normalized .. "/"
  end
  return normalized
end

local Observable = {}
local observable_next_counts = setmetatable({}, { __mode = "k" }) ---@type table<table, integer>

function Observable.from_value(initial)
  local value = initial ---@type any
  local observable ---@type table
  observable = {
    next = function(_, next_value)
      value = next_value
      observable_next_counts[observable] = observable_next_counts[observable] + 1
    end,
    snapshot = function()
      return value
    end,
  }
  observable_next_counts[observable] = 0
  return observable
end

local Future = {}
Future.__index = Future

function Future.new(executor)
  local self = setmetatable({ _done = false, _failed = false, _listeners = {} }, Future)
  executor(function(result)
    self._done = true
    self._result = result
    for _, listener in ipairs(self._listeners) do
      listener(true, result)
    end
  end, function(err)
    self._done = true
    self._failed = true
    self._error = err
    for _, listener in ipairs(self._listeners) do
      listener(false, err)
    end
  end)
  return self
end

function Future.resolve(result)
  return Future.new(function(resolve)
    resolve(result)
  end)
end

function Future.reject(err)
  return Future.new(function(_, reject)
    reject(err)
  end)
end

function Future:is_done()
  return self._done
end

function Future:is_failed()
  return self._failed
end

function Future:get_error()
  return self._error
end

function Future:finally(callback)
  if self._done then
    callback(not self._failed, self._failed and self._error or self._result)
  else
    self._listeners[#self._listeners + 1] = callback
  end
  return self
end

function Future:map(callback)
  return Future.new(function(resolve, reject)
    self:finally(function(ok, result)
      if not ok then
        reject(result)
        return
      end
      local callback_ok, value = pcall(callback, result)
      if callback_ok then
        resolve(value)
      else
        reject(value)
      end
    end)
  end)
end

bootstrap.with_runtime(t, {
  dot = {
    path = {
      dirname = function(filepath)
        local normalized = normalize(filepath, false)
        return normalized:match("^(.*)/[^/]+$") or normalized
      end,
      is_git_repo = function()
        return true
      end,
      join = function(from, to)
        return normalize(from .. "/" .. to, false)
      end,
      normalize = normalize,
      workspace = function()
        return workspace
      end,
    },
  },
  era = {
    m = {
      git = {
        status = {},
      },
    },
  },
  stl = {
    c = {
      CancellationToken = {
        new = function()
          local cancelled = false
          return {
            cancel = function()
              cancelled = true
            end,
            is_cancelled = function()
              return cancelled
            end,
          }
        end,
      },
      Future = Future,
      Observable = Observable,
    },
    env = {
      PATH_SEP = "/",
    },
    fn = {
      equals_deep = vim.deep_equal,
      noop = function() end,
    },
    reporter = {
      error = function() end,
      warn = function() end,
    },
    timer = {
      throttle = function(callback)
        return callback
      end,
    },
  },
})

local state = require("era.m.git.state")

---@param future table
local function wait_future(future)
  t.assert_true(
    vim.wait(3000, function()
      return future:is_done()
    end),
    "future should resolve"
  )
end

---@param observable table
---@return integer
local function next_count(observable)
  return observable_next_counts[observable]
end

---@param gitignore string
---@return string
local function create_git_fixture(gitignore)
  local root = vim.fn.tempname() ---@type string
  vim.fn.mkdir(root .. "/target", "p")
  vim.fn.writefile({ gitignore }, root .. "/.gitignore")
  vim.fn.writefile({ "child" }, root .. "/target/child")
  vim.fn.writefile({}, root .. "/ignored-before")
  vim.fn.writefile({}, root .. "/ignored-after")
  local init = vim.system({ "git", "-C", root, "init", "-q" }, { text = true }):wait()
  t.assert_eq(0, init.code, "git init")
  local ok, err = vim.uv.fs_symlink("target", root .. "/link")
  if not ok then
    error("failed to create symlink fixture: " .. tostring(err))
  end
  workspace = root
  state.clear_ignored_cache()
  return root
end

t:test("preload_ignored: symlink descendant does not poison later paths", function()
  local root = create_git_fixture("ignored-*")

  wait_future(state.preload_ignored({ root .. "/ignored-before", root .. "/link/child", root .. "/ignored-after" }))

  t.assert_true(state.is_ignored(root .. "/ignored-before"), "first ignored path")
  t.assert_false(state.is_ignored(root .. "/link/child"), "non-ignored symlink descendant")
  t.assert_true(state.is_ignored(root .. "/ignored-after"), "path after symlink descendant")
  vim.fn.delete(root, "rf")
end)

t:test("preload_ignored: symlink descendants inherit the link ignore status", function()
  local root = create_git_fixture("link")

  wait_future(state.preload_ignored({ root .. "/link/", root .. "/link/child" }))

  t.assert_true(state.is_ignored(root .. "/link/"), "ignored symlink")
  t.assert_true(state.is_ignored(root .. "/link/child"), "ignored symlink descendant")
  vim.fn.delete(root, "rf")
end)

t:test("preload_ignored: failed batches do not cache missing output as false", function()
  workspace = "/project"
  state.clear_ignored_cache()
  local calls = 0 ---@type integer

  t:patch_table(vim, "system", function(_, _, callback)
    calls = calls + 1
    vim.schedule(function()
      callback({ code = 128, stdout = "/project/ignored\n", stderr = "fatal" })
    end)
    return { kill = function() end }
  end)

  wait_future(state.preload_ignored({ "/project/ignored", "/project/unknown" }))
  t.assert_true(state.is_ignored("/project/ignored"), "positive output should be cached")

  wait_future(state.preload_ignored({ "/project/unknown" }))
  t.assert_eq(2, calls, "unknown path should be queried again")
end)

t:test("preload_ignored: reports only ignored states that changed", function()
  workspace = "/project"
  state.clear_ignored_cache()
  local callbacks = {} ---@type (fun(obj: table): nil)[]

  t:patch_table(vim, "system", function(_, _, callback)
    callbacks[#callbacks + 1] = callback
    return { kill = function() end }
  end)

  local first = state.preload_ignored({ "/project/ignored" })
  local duplicate = state.preload_ignored({ "/project/ignored" })
  t.assert_eq(2, #callbacks, "both in-flight queries should start")

  callbacks[1]({ code = 0, stdout = "/project/ignored\n", stderr = "" })
  wait_future(first)
  local changed = state.o_ignored_refreshed:snapshot()
  t.assert_eq(1, #changed, "changed path count")
  t.assert_eq("/project/ignored", changed[1], "changed path")

  callbacks[2]({ code = 0, stdout = "/project/ignored\n", stderr = "" })
  wait_future(duplicate)
  t.assert_true(changed == state.o_ignored_refreshed:snapshot(), "duplicate completion should not report again")

  wait_future(state.preload_ignored({ "/project/ignored" }))
  t.assert_true(changed == state.o_ignored_refreshed:snapshot(), "cache hit should not report again")

  local nonignored = state.preload_ignored({ "/project/tracked" })
  callbacks[3]({ code = 1, stdout = "", stderr = "" })
  wait_future(nonignored)
  t.assert_true(changed == state.o_ignored_refreshed:snapshot(), "non-ignored result should not report")

  state.clear_ignored_cache()
  local repeated = state.preload_ignored({ "/project/ignored" })
  callbacks[4]({ code = 0, stdout = "/project/ignored\n", stderr = "" })
  wait_future(repeated)
  t.assert_true(changed ~= state.o_ignored_refreshed:snapshot(), "same path should report again after cache reset")
end)

t:test("preload_ignored: memoizes shared ancestor resolution within a batch", function()
  workspace = "/project"
  state.clear_ignored_cache()
  local lstat_calls = 0 ---@type integer

  t:patch_table(vim.uv, "fs_lstat", function()
    lstat_calls = lstat_calls + 1
    return nil
  end)
  t:patch_table(vim, "system", function(_, _, callback)
    vim.schedule(function()
      callback({ code = 1, stdout = "", stderr = "" })
    end)
    return { kill = function() end }
  end)

  local paths = {} ---@type string[]
  for index = 1, 100 do
    paths[index] = string.format("/project/shared/file-%03d", index)
  end
  wait_future(state.preload_ignored(paths))

  t.assert_eq(102, lstat_calls, "each file and shared ancestor should be checked once")
end)

t:test("preload_ignored: capacity reset rebuilds the complete current batch", function()
  workspace = "/project"
  state.clear_ignored_cache()
  local calls = 0 ---@type integer

  t:patch_table(vim, "system", function(_, _, callback)
    calls = calls + 1
    vim.schedule(function()
      callback({ code = 1, stdout = "", stderr = "" })
    end)
    return { kill = function() end }
  end)

  local paths = {} ---@type string[]
  for index = 1, 1999 do
    paths[index] = string.format("/project/file-%04d", index)
  end
  wait_future(state.preload_ignored(paths))

  paths[#paths + 1] = "/project/new-a"
  paths[#paths + 1] = "/project/new-b"
  wait_future(state.preload_ignored(paths))
  wait_future(state.preload_ignored(paths))

  t.assert_eq(2, calls, "cache-hit batch should not be queried after rebuild")
end)

t:test("refresh: successful collections publish without rebuilding unchanged status", function()
  local status_maps = {
    { ["/project/file"] = { display = "M" } },
    { ["/project/file"] = { display = "M" } },
    { ["/project/file"] = { display = "D" } },
  } ---@type table<string, table>[]
  local collect_index = 0 ---@type integer
  local collect_base = "unset" ---@type string|false

  t:patch_table(era.m.git.status, "collect", function(opts)
    collect_base = opts and opts.base or false
    collect_index = collect_index + 1
    return Future.new(function(resolve)
      resolve({ status_map = status_maps[collect_index] })
    end)
  end)
  t:patch_table(era.m.git.status, "aggregate", function(status_map)
    local filepath, entry = next(status_map)
    return {
      dir_cache = {},
      file_display = { [filepath] = entry.display },
      file_stage = {},
      file_summary = {},
      staged_files = {},
      status_table = status_map,
      unstaged_files = { filepath },
    }
  end)

  local now = 0 ---@type integer
  t:patch_table(vim.uv, "now", function()
    now = now + 1
    return now
  end)

  local refreshed_before = next_count(state.o_refreshed)
  local staged_before = next_count(state.o_staged_files)
  local unstaged_before = next_count(state.o_unstaged_files)

  wait_future(state.refresh(false))
  t.assert_false(collect_base, "global refresh must support unborn HEAD")
  t.assert_eq(refreshed_before + 1, next_count(state.o_refreshed), "initial changed status notification")
  t.assert_eq(staged_before + 1, next_count(state.o_staged_files), "initial staged files notification")
  t.assert_eq(unstaged_before + 1, next_count(state.o_unstaged_files), "initial unstaged files notification")

  local aggregated = state.aggregated()
  local dir_status = { display = "M" }
  aggregated.dir_cache["/project"] = dir_status

  wait_future(state.refresh(false))
  t.assert_eq(refreshed_before + 2, next_count(state.o_refreshed), "unchanged status notification")
  t.assert_eq(staged_before + 1, next_count(state.o_staged_files), "unchanged staged files notification")
  t.assert_eq(unstaged_before + 1, next_count(state.o_unstaged_files), "unchanged unstaged files notification")
  t.assert_true(aggregated.dir_cache["/project"] == dir_status, "unchanged status should preserve directory cache")
  t.assert_eq(2, state.last_refreshed_at(), "unchanged refresh should still update completion timestamp")

  wait_future(state.refresh(false))
  t.assert_eq(refreshed_before + 3, next_count(state.o_refreshed), "changed status notification")
  t.assert_eq(staged_before + 2, next_count(state.o_staged_files), "changed staged files notification")
  t.assert_eq(unstaged_before + 2, next_count(state.o_unstaged_files), "changed unstaged files notification")
  t.assert_nil(aggregated.dir_cache["/project"], "changed status should invalidate directory cache")
  t.assert_eq("D", aggregated.file_display["/project/file"], "changed status should replace aggregated cache")
end)

t:test("refresh: failed collect reports once, preserves status, and permits recovery", function()
  local aggregated = state.aggregated()
  local status_table = aggregated.status_table
  local refreshed_before = next_count(state.o_refreshed)
  local reports = {} ---@type table[]
  local attempts = 0 ---@type integer

  t:patch_table(era.m.git.status, "collect", function()
    attempts = attempts + 1
    if attempts == 1 then
      return Future.reject("fatal: status unavailable")
    end
    return Future.resolve({ status_map = status_table })
  end)
  t:patch_table(stl.reporter, "error", function(opts)
    reports[#reports + 1] = opts
  end)

  wait_future(state.refresh(false))
  t.assert_true(aggregated.status_table == status_table, "failed collect should preserve status cache")
  t.assert_eq(refreshed_before, next_count(state.o_refreshed), "failed collect notification")
  t.assert_eq(1, #reports, "failure reported once")
  t.assert_true(reports[1].message:find("fatal: status unavailable", 1, true) ~= nil, "failure reason preserved")

  wait_future(state.refresh(false))
  t.assert_eq(2, attempts, "later refresh retried")
  t.assert_eq(refreshed_before + 1, next_count(state.o_refreshed), "successful retry published")
  t.assert_eq(1, #reports, "successful retry emits no additional error")
end)

t:test("status: propagates collection failures", function()
  t:patch_table(era.m.git.status, "collect", function()
    return Future.reject("fatal: status unavailable")
  end)

  local future = state.status("HEAD")

  t.assert_true(future:is_done(), "status future settled")
  t.assert_true(future:is_failed(), "status future rejected")
  t.assert_eq("fatal: status unavailable", future:get_error(), "collection error preserved")
end)

t:run()
