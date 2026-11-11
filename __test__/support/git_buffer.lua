---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.git_buffer" ---@type string

-- Specs of the Git modules run them over the globals they describe. The modules create and await the real `stl.c`
-- futures, and `era.m.git.buffer` creates a Ticker when it loads.

local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local harness = require("__test__.support.harness")

local M = {}

---Exposes the real Future and CancellationToken in `stl.c` until the case or suite of `t` ends.
---@param t                             __test__.support.Harness
---@return nil
function M.with_futures(t)
  bootstrap.with_global(t, "stl", {
    c = { CancellationToken = require("stl.c.cancellation_token"), Future = require("stl.c.future") },
  })
end

---Loads a fresh `era.m.git.buffer`. Until the case or suite of `t` ends, `stl.c` holds the real futures and a Ticker
---stub, and the globals in `runtime` are merged in as `bootstrap.with_runtime` merges them.
---@param t                             __test__.support.Harness
---@param runtime                       table<string, table>
---@return era.m.git.buffer
function M.load(t, runtime)
  M.with_futures(t)
  bootstrap.with_global(t, "stl", {
    c = {
      Ticker = {
        new = function()
          return { tick = function() end }
        end,
      },
    },
  })
  bootstrap.with_runtime(t, runtime)
  return assert(loadfile("lua/era/m/git/buffer.lua"))()
end

---The cache entries that `buffer`, a loaded `era.m.git.buffer`, keeps by buffer number.
---@param buffer                        era.m.git.buffer
---@return table<integer, era.m.git.buffer.ICache>
function M.cache(buffer)
  for index = 1, 50 do
    local name, value = debug.getupvalue(buffer.reset_hunk, index)
    if not name then
      break
    end
    if name == "cache" then
      return value
    end
  end
  error("missing upvalue: cache")
end

---A `stl.timer` debounce or throttle stand-in: calling it calls `callback`, and it can be disposed.
---@param callback                      function
---@return table
function M.callable(callback)
  return setmetatable({ dispose = function() end }, {
    __call = function(_, ...)
      return callback(...)
    end,
  })
end

---Waits for a staging write of `era.m.git.buffer` and returns its outcome, a rejection as a failed one.
---@param future                        stl.c.Future
---@return { ok: boolean, err: string|nil }
function M.outcome(future)
  local resolved, result = harness.settle(future)
  return resolved and result or { ok = false, err = tostring(result) }
end

---Loads `era.m.git.buffer` over the real Git act/info, diff, index and staging modules for the suite or case of `t`,
---and returns it as `buffer` with `staging` and helpers that stage and unstage ranges of f.txt in temporary
---repositories.
---@param t                             __test__.support.Harness
---@return table
function M.index_writes(t)
  local buffer = M.load(t, {
    stl = {
      git = { act = require("stl.git.act"), info = require("stl.git.info") },
      reporter = { warn = function() end },
    },
    yoz = {
      canonical_path = {
        to_os_path = function(filepath)
          return filepath
        end,
      },
    },
    era = {
      m = {
        git = {
          diff = require("era.m.git.diff"),
          index = require("era.m.git.index"),
          staging = require("era.m.git.staging"),
        },
      },
    },
  })
  local staging = era.m.git.staging
  local writes = { buffer = buffer, staging = staging }

  ---A repository whose line endings stay as written unless `autocrlf` is given.
  ---@param autocrlf                    string|nil
  ---@return string
  function writes.make_repo(autocrlf)
    local repo = git.repo(t)
    git.run(repo, { "config", "core.autocrlf", autocrlf or "false" })
    git.run(repo, { "config", "core.safecrlf", "false" })
    return repo
  end

  ---A repository whose first commit holds `bytes` as f.txt.
  ---@param bytes                       string
  ---@param autocrlf                    string|nil
  ---@return string
  function writes.committed_repo(bytes, autocrlf)
    local repo = writes.make_repo(autocrlf)
    fs.write(repo .. "/f.txt", bytes)
    git.commit(repo, "base")
    return repo
  end

  ---@param repo                        string
  ---@param relpath                     string
  ---@return string
  function writes.index_bytes(repo, relpath)
    return git.run(repo, { "cat-file", "-p", ":" .. relpath })
  end

  ---@param repo                        string
  ---@param relpath                     string
  ---@return string|nil
  function writes.index_object(repo, relpath)
    local output = git.run(repo, { "ls-files", "--stage", "--", relpath }) ---@type string
    return output:match("^%d+%s+(%x+)%s+0%s+")
  end

  ---@param repo                        string
  ---@param relpath                     string
  ---@param encoding                    string|nil
  ---@return era.m.git.buffer.IIndexSnapshot
  function writes.index_snapshot(repo, relpath, encoding)
    return {
      document = assert(staging.from_blob(writes.index_bytes(repo, relpath), encoding or "utf-8", "\n")),
      object_name = writes.index_object(repo, relpath),
    }
  end

  ---Stages `range` of `document` as f.txt, expecting the index to hold `expected`, by default its current entry.
  ---@param repo                        string
  ---@param document                    era.m.git.Document
  ---@param range                       { [1]: integer, [2]: integer }
  ---@param expected                    era.m.git.buffer.IIndexSnapshot|nil
  ---@return { ok: boolean, err: string|nil }
  function writes.stage(repo, document, range, expected)
    expected = expected or writes.index_snapshot(repo, "f.txt", document.encoding)
    return M.outcome(buffer.stage_range({
      buffer_document = document,
      expected_index = expected,
      partial = true,
      range = range,
      relpath = "f.txt",
      toplevel = repo,
    }))
  end

  ---Unstages `range` of f.txt, expecting the index to hold `expected`, by default its current entry.
  ---@param repo                        string
  ---@param range                       { [1]: integer, [2]: integer }
  ---@param expected                    era.m.git.buffer.IIndexSnapshot|nil
  ---@return { ok: boolean, err: string|nil }
  function writes.unstage(repo, range, expected)
    expected = expected or writes.index_snapshot(repo, "f.txt")
    return M.outcome(buffer.unstage_range({
      expected_index = expected,
      range = range,
      relpath = "f.txt",
      toplevel = repo,
    }))
  end

  return writes
end

return M
