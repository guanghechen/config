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
---@return string[] warnings
local function stub_close(unsaved_bufnr, tab)
  local warnings = {} ---@type string[]
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
    reporter = {
      warn = function(opts)
        warnings[#warnings + 1] = opts.message
      end,
    },
  })
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
  t.assert_same({ "Kept buffers with unsaved changes: 62.lua" }, warnings, "report")
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
  t.assert_same({ "Kept buffers with unsaved changes: 71.lua" }, warnings, "report")
end)

---Loads Find Buffers with its collaborators stubbed, then presses its close key on the selected buffer.
---@param unsaved                       boolean Whether the selected buffer has unsaved changes.
---@return { selected: integer, candidates: integer[]|nil, deleted: integer[], warnings: string[] }
local function close_in_find_buffers(unsaved)
  local selected_bufnr = 51
  local unrelated_bufnr = 52
  local props = nil ---@type table|nil
  local candidates = nil ---@type integer[]|nil
  local deleted = {} ---@type integer[]
  local warnings = {} ---@type string[]
  local picker = {
    _composer = {
      get_result_lnum = function()
        return 1
      end,
    },
    finder = {
      set_title = function() end,
    },
    retrieve = function()
      return { data = { bufnr = selected_bufnr, filepath = "a.lua" } }
    end,
    reset_data = function() end,
    focus = function() end,
  }
  local observable = {
    snapshot = function()
      return "A"
    end,
    next = function() end,
  }

  t:patch_global("yoz", {
    path = {
      basename = function(path)
        return path
      end,
    },
  })
  t:patch_global("stl", {
    fileicon = {
      get_file_icon = function()
        return "", ""
      end,
    },
    filetype = require("stl.filetype"),
    fn = {
      observe = function() end,
    },
    nvim = {
      buf = {
        has_unsaved_changes = function()
          return unsaved
        end,
        is_valid = function()
          return true
        end,
      },
    },
    reporter = {
      warn = function(opts)
        warnings[#warnings + 1] = opts.message
      end,
    },
    table = {
      find_index = function()
        return 1
      end,
    },
  })
  t:patch_global("dot", {
    context = {
      select = {
        find_buffer_scopes = { "A", "F", "L", "T" },
        find_buffer_scope = observable,
        find_buffer = {
          search_pattern = observable,
          flag_fuzzy = observable,
          flag_regex = observable,
          flag_case_sensitive = observable,
        },
      },
    },
    path = {
      cwd = function()
        return ""
      end,
      relative = function(_, path)
        return path
      end,
    },
    tab = {
      has_buf = function()
        return false
      end,
      on_bufs_close = function() end,
      retrieve_unreferenced_bufnrs = function(bufnrs)
        candidates = bufnrs
        return bufnrs or { selected_bufnr, unrelated_bufnr }
      end,
    },
    var = { nsnr = { picker_result = 1, picker_matches = 2 } },
  })
  t:patch_global("era", {
    m = {
      picker = {
        ListComposer = {
          new = function(value)
            props = value
            return picker
          end,
        },
      },
    },
  })
  t:patch_table(vim.api, "nvim_list_bufs", function()
    return {}
  end)
  t:patch_table(vim.api, "nvim_list_tabpages", function()
    return { 1 }
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_buf_delete", function(bufnr)
    deleted[#deleted + 1] = bufnr
  end)

  assert(loadfile("lua/era/fn/find-buffers.lua"))()
  assert(props).keymaps_result[1].callback()
  return { selected = selected_bufnr, candidates = candidates, deleted = deleted, warnings = warnings }
end

t:test("find-buffers close deletes only the selected buffer", function()
  local result = close_in_find_buffers(false)

  t.assert_eq(1, #assert(result.candidates), "candidate count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(result.selected, result.candidates[1], "candidate buffer")
  t.assert_eq(1, #result.deleted, "deleted buffer count")
  t.assert_eq(result.selected, result.deleted[1], "deleted buffer")
end)

t:test("find-buffers close keeps a buffer with unsaved changes", function()
  local result = close_in_find_buffers(true)

  t.assert_nil(result.candidates, "no tab let the buffer go")
  t.assert_same({}, result.deleted, "deleted buffers")
  t.assert_same({ "Kept a buffer with unsaved changes: a.lua" }, result.warnings, "report")
end)

t:run()
