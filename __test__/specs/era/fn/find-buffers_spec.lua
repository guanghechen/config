local bootstrap = require("__test__.support.bootstrap")
require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()

---@return table
local function facade()
  local state = { contents = {} }
  t:patch_table(era.m.picker.ListComposer, "new", function(props)
    state.props = props
    return {
      finder = {
        set_title = function() end,
        set_content = function(_, content)
          state.contents[#state.contents + 1] = content
        end,
      },
      reset_data = function() end,
      focus = function() end,
    }
  end)
  return state
end

t:test("Find Buffers reads a path in a query as the list shows it, relative to the working directory", function()
  local picker = facade()
  local cwd, outside = t:tempdir(), t:tempdir()
  t:patch_table(dot.path, "cwd", function()
    return cwd
  end)
  local find = assert(loadfile("lua/era/fn/find-buffers.lua"))()
  local rewrite = picker.props.rewrite_query
  t.assert_eq("lua/a.lua", rewrite(cwd .. "/lua/a.lua"))
  t.assert_eq(dot.path.relative(cwd, outside .. "/b.lua", "/"), rewrite(outside .. "/b.lua"))
  t.assert_eq("'lua !spec", rewrite("'" .. cwd .. "/lua !" .. cwd .. "/spec"), "each term keeps its marks")
  t.assert_eq("/init.lua lua", rewrite("/init.lua lua"), "a term that names no path stays")
  t.assert_eq(dot.path.relative(cwd, vim.uv.os_homedir() .. "/x", "/"), rewrite("~/x"))
  find(nil, outside .. "/b.lua")
  t.assert_eq(outside .. "/b.lua", picker.contents[#picker.contents], "the query it starts with")
end)

---Loads Find Buffers with its collaborators stubbed, then presses its close key on the selected buffer.
---@param unsaved                       boolean Whether the selected buffer has unsaved changes.
---@return { selected: integer, candidates: integer[]|nil, deleted: integer[], warnings: table[] }
local function close_in_find_buffers(unsaved)
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
    table = {
      find_index = function()
        return 1
      end,
    },
  })
  local warnings = bootstrap.with_reporter(t).warn
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
  t.assert_same({ "Kept a buffer with unsaved changes: a.lua" }, bootstrap.messages(result.warnings), "report")
end)

t:run()
