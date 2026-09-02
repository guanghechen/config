---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/buffer_close.lua

local harness = require("__test__.harness")

local t = harness.new("era.buffer_close")

t:test("tab-local close deletes only requested unreferenced buffers", function()
  local requested_bufnr = 41
  local unrelated_bufnr = 42
  local candidates = nil ---@type integer[]|nil
  local deleted = {} ---@type integer[]

  t:patch_global("stl", {
    nvim = {
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

t:test("find-buffers close deletes only the selected buffer", function()
  local selected_bufnr = 51
  local unrelated_bufnr = 52
  local props = nil ---@type table|nil
  local candidates = nil ---@type integer[]|nil
  local deleted = {} ---@type integer[]
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
      return { data = { bufnr = selected_bufnr } }
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
        is_valid = function()
          return true
        end,
      },
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

  t.assert_eq(1, #assert(candidates), "candidate count")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(selected_bufnr, candidates[1], "candidate buffer")
  t.assert_eq(1, #deleted, "deleted buffer count")
  t.assert_eq(selected_bufnr, deleted[1], "deleted buffer")
end)

t:run()
