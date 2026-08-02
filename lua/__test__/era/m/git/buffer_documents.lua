---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/git/buffer_documents.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")
local Future = require("stl.c.future")

local t = harness.new("era.m.git.buffer_documents")

---@param callback                      function
---@return table
local function callable(callback)
  return setmetatable({ dispose = function() end }, {
    __call = function(_, ...)
      return callback(...)
    end,
  })
end

t:test("attach keeps authoritative index documents across edits, failures, and missing entries", function()
  local repo_path = vim.fn.tempname() ---@type string
  vim.fn.mkdir(repo_path, "p")
  local function git(...)
    return vim.system({ "git", "-C", repo_path, ... }, { text = false }):wait()
  end
  git("init", "-q")
  git("config", "user.email", "test@test")
  git("config", "user.name", "test")
  local filepath = repo_path .. "/f.txt" ---@type string
  local file = assert(io.open(filepath, "wb"))
  file:write("a\nb\n")
  file:close()
  git("add", "f.txt")
  git("commit", "-qm", "base")

  local repo = {
    abbrev_head = "main",
    commondir = nil,
    gitdir = repo_path .. "/.git",
    toplevel = repo_path,
    get_relpath = function()
      return "f.txt"
    end,
  }
  local hunk = require("era.m.git.hunk")

  bootstrap.with_global(t, "stl", {
    c = {
      Future = Future,
      Ticker = {
        new = function()
          return { tick = function() end }
        end,
      },
    },
    git = { act = require("stl.git.act"), info = require("stl.git.info") },
    reporter = { warn = function() end },
    timer = {
      throttle = function(callback)
        return callable(callback)
      end,
    },
  })
  bootstrap.with_global(t, "dot", {
    path = {
      is_git_repo = function()
        return true
      end,
      normalize = function(path)
        return path
      end,
      workspace = function()
        return repo_path
      end,
    },
  })
  bootstrap.with_global(
    t,
    "yoz",
    { path = {
      is_exist = function(path)
        return vim.uv.fs_stat(path) ~= nil
      end,
    } }
  )
  bootstrap.with_global(t, "era", {
    m = {
      git = {
        diff = require("era.m.git.diff"),
        hunk = hunk,
        repo = {
          create = function()
            return Future.resolve(repo)
          end,
        },
        sign = {
          clear = function() end,
          contains_range = function()
            return false
          end,
          on_lines = function() end,
          update = function() end,
        },
        staging = require("era.m.git.staging"),
        state = { o_branch = { next = function() end } },
        watcher = { update = function() end },
      },
    },
  })

  vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buffer = assert(loadfile("lua/era/m/git/buffer.lua"))() ---@type era.m.git.buffer
  t.assert_true(buffer.attach(bufnr), "attached")
  t.wait_until(function()
    local current = buffer.get_cache(bufnr)
    return current ~= nil and current.dirty == false and current.head_document ~= nil and current.index_document ~= nil
  end, 5000, "initial documents")

  local initial = assert(buffer.get_cache(bufnr))
  t.assert_eq("a\nb\n", initial.head_document.text, "HEAD document")
  t.assert_eq("a\nb\n", initial.index_document.text, "index document")

  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "A" })
  t.wait_until(function()
    local current = buffer.get_cache(bufnr)
    return current ~= nil and current.dirty == false and current.hunks ~= nil and #current.hunks == 1
  end, 5000, "edited hunks")

  local edited = assert(buffer.get_cache(bufnr))
  t.assert_eq(1, edited.hunks[1].added.start, "changed line")

  edited.head_document = nil
  edited.index_document = nil
  edited.dirty = false
  local restore = t:patch_table(stl.git.info, "get_show_blob", function()
    return Future.resolve({ ok = false, missing = false, err = "injected blob read failure" })
  end)
  local refresh_outcome = nil ---@type { resolved: boolean, result: any }|nil
  buffer.refresh(bufnr):finally(function(resolved, result)
    refresh_outcome = { resolved = resolved, result = result }
  end)
  t.wait_until(function()
    return refresh_outcome ~= nil
  end, 5000, "failed refresh")
  restore()

  local failed = assert(buffer.get_cache(bufnr))
  t.assert_false(refresh_outcome.resolved, "refresh rejected")
  t.assert_true(failed.dirty, "cache remains dirty")
  t.assert_nil(failed.head_document, "HEAD is not replaced with an empty document")
  t.assert_nil(failed.index_document, "index is not replaced with an empty document")
  t.assert_false(buffer.reset_buffer(bufnr), "reset is unavailable without authoritative index content")

  git("rm", "-q", "--cached", "f.txt")
  local recovery = nil ---@type { resolved: boolean, result: any }|nil
  buffer.refresh(bufnr, true):finally(function(resolved, result)
    recovery = { resolved = resolved, result = result }
  end)
  t.wait_until(function()
    return recovery ~= nil
  end, 5000, "missing-index refresh")

  local missing = assert(buffer.get_cache(bufnr))
  t.assert_true(recovery.resolved, "refresh resolved")
  t.assert_eq("a\nb\n", missing.head_document.text, "HEAD remains independent")
  t.assert_eq("", missing.index_document.text, "missing index is empty")
  t.assert_eq(1, #(missing.hunks or {}), "working file is an index addition")

  local staged = nil ---@type table|nil
  buffer.stage_hunk(bufnr, { 1, 1 }):finally(function(resolved, result)
    staged = resolved and result or { ok = false, err = result }
  end)
  t.wait_until(function()
    return staged ~= nil
  end, 5000, "stage from missing index")
  t.assert_true(staged.ok, "real stage_hunk path: " .. tostring(staged.err))
  t.assert_eq("A\n", git("cat-file", "-p", ":f.txt").stdout or "", "selected line staged")

  local restore_info = t:patch_table(stl.git.info, "get_file_info", function()
    return Future.resolve({ ok = false, missing = false, err = "injected metadata failure" })
  end)
  local metadata_failure = nil ---@type { resolved: boolean, result: any }|nil
  buffer.refresh(bufnr, true):finally(function(resolved, result)
    metadata_failure = { resolved = resolved, result = result }
  end)
  t.wait_until(function()
    return metadata_failure ~= nil
  end, 5000, "metadata failure")
  restore_info()

  local unavailable = assert(buffer.get_cache(bufnr))
  t.assert_false(metadata_failure.resolved, "metadata refresh rejected")
  t.assert_true(unavailable.dirty, "metadata failure remains dirty")
  t.assert_nil(unavailable.index_document, "stale index document discarded")
  t.assert_false(buffer.reset_buffer(bufnr), "reset refuses stale index baseline")

  vim.cmd("bdelete!")
  vim.fn.delete(repo_path, "rf")
end)

t:run()
