local Future = require("stl.c.future")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")

local t = harness.new()

t:test("attach keeps authoritative index documents across edits, failures, and missing entries", function()
  local repo_path = git.repo(t)
  local filepath = repo_path .. "/f.txt" ---@type string
  fs.write(filepath, "a\nb\n")
  git.commit(repo_path, "base")

  local repo = {
    abbrev_head = "main",
    commondir = nil,
    gitdir = repo_path .. "/.git",
    toplevel = repo_path,
    get_relpath = function()
      return "f.txt"
    end,
  }

  local buffer = git_buffer.load(t, {
    stl = {
      git = { act = require("stl.git.act"), info = require("stl.git.info") },
      reporter = { warn = function() end },
      timer = { throttle = git_buffer.callable },
    },
    dot = {
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
    },
    yoz = {
      canonical_path = {
        to_os_path = function(filepath)
          return filepath
        end,
      },
      path = {
        is_descendant = function(from, to)
          return to == from or vim.startswith(to, from .. "/")
        end,
      },
    },
    era = {
      m = {
        git = {
          diff = require("era.m.git.diff"),
          hunk = require("era.m.git.hunk"),
          index = require("era.m.git.index"),
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
    },
  })

  vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
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
  local refreshed = t.settle(buffer.refresh(bufnr))
  restore()

  local failed = assert(buffer.get_cache(bufnr))
  t.assert_false(refreshed, "refresh rejected")
  t.assert_true(failed.dirty, "cache remains dirty")
  t.assert_nil(failed.head_document, "HEAD is not replaced with an empty document")
  t.assert_nil(failed.index_document, "index is not replaced with an empty document")
  t.assert_false(buffer.reset_buffer(bufnr), "reset is unavailable without authoritative index content")

  git.run(repo_path, { "rm", "-q", "--cached", "f.txt" })
  local recovered = t.settle(buffer.refresh(bufnr, true))

  local missing = assert(buffer.get_cache(bufnr))
  t.assert_true(recovered, "refresh resolved")
  t.assert_eq("a\nb\n", missing.head_document.text, "HEAD remains independent")
  t.assert_eq("", missing.index_document.text, "missing index is empty")
  t.assert_eq(1, #(missing.hunks or {}), "working file is an index addition")

  local staged = git_buffer.outcome(buffer.stage_hunk(bufnr, { 1, 1 }))
  t.assert_true(staged.ok, "real stage_hunk path: " .. tostring(staged.err))
  t.assert_eq("A\n", git.run(repo_path, { "cat-file", "-p", ":f.txt" }), "selected line staged")

  local restore_info = t:patch_table(stl.git.info, "get_file_info", function()
    return Future.resolve({ ok = false, missing = false, err = "injected metadata failure" })
  end)
  local metadata_refreshed = t.settle(buffer.refresh(bufnr, true))
  restore_info()

  local unavailable = assert(buffer.get_cache(bufnr))
  t.assert_false(metadata_refreshed, "metadata refresh rejected")
  t.assert_true(unavailable.dirty, "metadata failure remains dirty")
  t.assert_nil(unavailable.index_document, "stale index document discarded")
  t.assert_false(buffer.reset_buffer(bufnr), "reset refuses stale index baseline")
end)

t:run()
