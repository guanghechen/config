--- Run with: nvim -l lua/__test__/era/find_diagnostics.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.fn.find_diagnostics")

t:test("preview resolves the selected file through the data contract", function()
  local filepath = "/workspace/main.lua"
  local props = nil ---@type era.m.picker.composer.filetree.IProps|nil
  local picker = {}

  t:patch_table(era.m.picker.FiletreeComposer, "new", function(actual_props)
    props = actual_props
    return picker
  end)
  t:patch_table(stl.fn, "observe", function() end)

  local loaded_filepath = nil ---@type string|nil
  t:patch_table(dot.buf, "loadfile", function(actual_filepath)
    loaded_filepath = actual_filepath
    return 42
  end)

  local diagnostic_source = nil ---@type integer|nil
  t:patch_table(vim.diagnostic, "get", function(bufnr)
    diagnostic_source = bufnr
    return {}
  end)

  local diagnostic_target = nil ---@type integer|nil
  t:patch_table(vim.diagnostic, "set", function(_, bufnr)
    diagnostic_target = bufnr
  end)

  local find_diagnostics = assert(loadfile("lua/era/fn/find-diagnostics.lua"))()
  t.assert_eq("function", type(find_diagnostics), "module contract")
  assert(props ~= nil, "picker props should be captured")

  props.on_preview_rendered(picker, 84, {
    filepath = filepath,
    filetype = "file",
  })

  t.assert_eq(filepath, loaded_filepath, "preview filepath")
  t.assert_eq(42, diagnostic_source, "diagnostic source buffer")
  t.assert_eq(84, diagnostic_target, "diagnostic preview buffer")
end)

t:run()
