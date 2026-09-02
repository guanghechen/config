---@diagnostic disable: undefined-global
--- Test for era.m.image module
--- Run with: nvim -l lua/__test__/era/m/image/init.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.image")

t:test("dressing attaches existing and future supported buffers", function()
  local buffers = {
    [11] = { valid = true, loaded = true, filetype = "markdown" },
    [12] = { valid = true, loaded = true, filetype = "lua" },
    [13] = { valid = false, loaded = true, filetype = "markdown" },
    [14] = { valid = true, loaded = false, filetype = "markdown" },
    [15] = { valid = true, loaded = true, filetype = "markdown" },
    [16] = { valid = true, loaded = true, filetype = "markdown" },
  }
  local attached = {} ---@type table<integer, integer>
  local filetype_callback = nil ---@type fun(event: { buf: integer })|nil
  local scheduled = {} ---@type fun()[]
  local state = {
    data = {
      doc = { enabled = true },
      extnames = { ".png" },
    },
    did_setup = false,
    is_support_file = function()
      return true
    end,
    is_support_terminal = function()
      return true
    end,
  }

  t:patch_global("stl", {
    env = { IS_OSX = true },
    nvim = {
      fn = {
        augroup = function()
          return 1
        end,
      },
    },
  })
  t:patch_global("dot", {})
  t:patch_table(package.loaded, "era.m.image.state", state)
  t:patch_table(package.loaded, "era.m.image.doc", {
    attach = function(bufnr)
      attached[bufnr] = (attached[bufnr] or 0) + 1
    end,
  })
  t:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    if events == "FileType" then
      filetype_callback = opts.callback
    end
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_runtime_file", function()
    return { "/runtime/queries/markdown/images.scm" }
  end)
  t:patch_table(vim.api, "nvim_list_bufs", function()
    return { 11, 12, 13, 14, 15, 16 }
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function(bufnr)
    return buffers[bufnr].valid
  end)
  t:patch_table(vim.api, "nvim_buf_is_loaded", function(bufnr)
    return buffers[bufnr].loaded
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name, opts)
    t.assert_eq("filetype", name, "buffer option")
    return buffers[opts.buf].filetype
  end)
  t:patch_table(vim.treesitter.language, "get_lang", function(filetype)
    return filetype
  end)
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)

  local Image = assert(loadfile("lua/era/m/image/init.lua"))()
  Image.dressing()

  t.assert_true(state.did_setup, "image setup")
  t.assert_eq(3, #scheduled, "existing supported schedules")

  buffers[15].filetype = "lua"
  buffers[16].loaded = false
  while #scheduled > 0 do
    table.remove(scheduled, 1)()
  end

  t.assert_eq(1, attached[11], "existing supported buffer")
  t.assert_nil(attached[12], "existing unsupported buffer")
  t.assert_nil(attached[13], "invalid buffer")
  t.assert_nil(attached[14], "unloaded buffer")
  t.assert_nil(attached[15], "buffer with stale filetype")
  t.assert_nil(attached[16], "buffer unloaded before attach")
  t.assert_true(filetype_callback ~= nil, "future FileType callback")

  buffers[12].filetype = "markdown"
  ---@diagnostic disable-next-line: need-check-nil
  filetype_callback({ buf = 12 })
  t.assert_eq(1, #scheduled, "future supported schedule")
  table.remove(scheduled, 1)()
  t.assert_eq(1, attached[12], "future supported buffer")
end)

t:run()
