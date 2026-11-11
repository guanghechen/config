local t = require("__test__.support.harness").new()
t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
t:patch_global("dot", require("dot"))
local Fileinfo = require("era.view.fileinfo")

t:test("File Info displays supplied metadata and wraps long escaped paths within the screen", function()
  local path = t:tempdir()
  t:patch_table(dot.path, "workspace", function()
    return path
  end)
  local filepath = path .. "-sibling/" .. string.rep("中", 100) .. "\nfile"
  local panel = Fileinfo.new({
    filepath = filepath,
    kind = "file",
    details = { size = 1048576, permissions = "rw-r--r--", mode = "0644" },
  })
  t:defer(function()
    panel:dispose()
  end)
  panel:open()
  t.assert_true(panel:isvisible(), "opening supplied metadata must not stat the path")
  local body = table.concat(vim.api.nvim_buf_get_lines(panel._bufnr, 0, -1, false), "\n")
  t.assert_true(body:find(vim.fn.strtrans(filepath), 1, true) ~= nil, "workspace prefixes must match a path boundary")
  t.assert_true(body:find("1.0 MiB (1048576 bytes)", 1, true) ~= nil)
  t.assert_true(vim.api.nvim_win_get_width(panel._winnr) <= vim.o.columns - 4)
  t.assert_true(vim.api.nvim_win_get_height(panel._winnr) <= vim.o.lines - 4)
  t.assert_true(vim.api.nvim_get_option_value("wrap", { win = panel._winnr }))
  t.assert_false(vim.api.nvim_get_option_value("modifiable", { buf = panel._bufnr }))
end)

t:run()
