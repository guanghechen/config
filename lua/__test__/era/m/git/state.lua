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

function Observable.from_value(initial)
  local value = initial ---@type any
  return {
    next = function(_, next_value)
      value = next_value
    end,
    snapshot = function()
      return value
    end,
  }
end

local Future = {}
Future.__index = Future

function Future.new(executor)
  local self = setmetatable({ _done = false, _listeners = {} }, Future)
  executor(function(result)
    self._done = true
    self._result = result
    for _, listener in ipairs(self._listeners) do
      listener(true, result)
    end
  end)
  return self
end

function Future:is_done()
  return self._done
end

function Future:finally(callback)
  if self._done then
    callback(true, self._result)
  else
    self._listeners[#self._listeners + 1] = callback
  end
  return self
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
      Future = Future,
      Observable = Observable,
    },
    env = {
      PATH_SEP = "/",
    },
    fn = {
      noop = function() end,
    },
    reporter = {
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

t:run()
