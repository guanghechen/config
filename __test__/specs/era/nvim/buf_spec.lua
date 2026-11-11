local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

t:test("tab-local close deletes only requested unreferenced buffers", function()
  local requested_bufnr = 41
  local unrelated_bufnr = 42
  local candidates = nil ---@type integer[]|nil
  local deleted = {} ---@type integer[]

  t:patch_global("stl", {
    nvim = {
      buf = {
        has_unsaved_changes = function()
          return false
        end,
      },
      tab = {
        list_visible_bufnrs = function()
          return {}
        end,
      },
    },
  })
  t:patch_global("dot", {
    tab = {
      resolve = function()
        return {
          bufs = {
            { bufnr = requested_bufnr, pinned = false },
          },
        }
      end,
      on_bufs_close = function() end,
      retrieve_unreferenced_bufnrs = function(bufnrs)
        candidates = bufnrs
        return bufnrs or { requested_bufnr, unrelated_bufnr }
      end,
    },
  })
  t:patch_table(vim.api, "nvim_buf_delete", function(bufnr)
    deleted[#deleted + 1] = bufnr
  end)

  local Buf = assert(loadfile("lua/era/nvim/buf.lua"))()
  Buf.close_others()

  t.assert_eq(1, #assert(candidates), "candidate count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(requested_bufnr, candidates[1], "candidate buffer")
  t.assert_eq(1, #deleted, "deleted buffer count")
  t.assert_eq(requested_bufnr, deleted[1], "deleted buffer")
end)

---Stubs the tab, path and reporter collaborators of `era.nvim.buf` around buffers named "/work/<bufnr>.lua".
---@param unsaved_bufnr                 integer
---@param tab                           table
---@return table[] warnings
local function stub_close(unsaved_bufnr, tab)
  t:patch_global("stl", {
    nvim = {
      buf = {
        has_unsaved_changes = function(bufnr)
          return bufnr == unsaved_bufnr
        end,
      },
      tab = {
        list_visible_bufnrs = function()
          return {}
        end,
      },
    },
  })
  local warnings = bootstrap.with_reporter(t).warn
  t:patch_global("dot", {
    path = {
      cwd = function()
        return "/work"
      end,
      relative = function(_, filepath)
        return (filepath:gsub("^/work/", ""))
      end,
    },
    tab = tab,
    win = {
      resolve = function()
        return { history = {} }
      end,
    },
  })
  t:patch_table(vim.api, "nvim_buf_get_name", function(bufnr)
    return "/work/" .. bufnr .. ".lua"
  end)
  return warnings
end

t:test("tab-local close keeps buffers with unsaved changes in the tab and reports them", function()
  local saved_bufnr, unsaved_bufnr = 61, 62
  local closed = nil ---@type integer[]|nil
  local deleted = {} ---@type integer[]
  local warnings = stub_close(unsaved_bufnr, {
    resolve = function()
      return { bufs = { { bufnr = saved_bufnr, pinned = false }, { bufnr = unsaved_bufnr, pinned = false } } }
    end,
    on_bufs_close = function(_, bufnrs)
      closed = bufnrs
    end,
    retrieve_unreferenced_bufnrs = function(bufnrs)
      return bufnrs
    end,
  })
  t:patch_table(vim.api, "nvim_buf_delete", function(bufnr)
    deleted[#deleted + 1] = bufnr
  end)

  local Buf = assert(loadfile("lua/era/nvim/buf.lua"))()
  Buf.close_others()

  t.assert_same({ saved_bufnr }, closed, "buffers taken off the tab")
  t.assert_same({ saved_bufnr }, deleted, "deleted buffers")
  t.assert_same({ "Kept buffers with unsaved changes: 62.lua" }, bootstrap.messages(warnings), "report")
end)

t:test("close stays on a source buffer with unsaved changes", function()
  local unsaved_bufnr = 71
  local switched = false ---@type boolean
  local deleted = {} ---@type integer[]
  local warnings = stub_close(unsaved_bufnr, {
    retrieve_winnr_sourcefile = function()
      return 1000
    end,
  })
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return unsaved_bufnr
  end)
  t:patch_table(vim.api, "nvim_win_set_buf", function()
    switched = true
  end)
  t:patch_table(vim.api, "nvim_buf_delete", function(bufnr)
    deleted[#deleted + 1] = bufnr
  end)

  local Buf = assert(loadfile("lua/era/nvim/buf.lua"))()
  Buf.close()

  t.assert_false(switched, "the window keeps the buffer")
  t.assert_same({}, deleted, "deleted buffers")
  t.assert_same({ "Kept buffers with unsaved changes: 71.lua" }, bootstrap.messages(warnings), "report")
end)

t:run()
