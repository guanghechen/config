local t = require("__test__.support.harness").new()

t:test("attached Filetree renders and withdraws ephemeral status decorations", function()
  local path = t:tempdir()
  vim.fn.writefile({ "content" }, path .. "/file")
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:start({ width = 80, height = 24, runtime = "native" })
  ui:lua(
    [=[
    local path = ...
    drawn = {}
    await = require("__test__.support.treeview").await
    local mark = vim.api.nvim_buf_set_extmark
    namespace = vim.api.nvim_create_namespace("ux.filetree.annotations")
    vim.api.nvim_buf_set_extmark = function(bufnr, ns, row, col, options)
      if ns == namespace and options.virt_text then
        for _, chunk in ipairs(options.virt_text) do drawn[chunk[1]] = true end
      end
      return mark(bufnr, ns, row, col, options)
    end
    local filetree = require("ux.filetree")
    data = await(filetree.open(path))
    state = await(data:create_state(nil, { mode = "list" }))
    view = filetree.attach(state, { keymaps = false })
    assert(vim.wait(10000, function() return view:frame() and view:frame():header().row_count == 1 end))
    await(data:set_diagnostics(1, 1, 1, path .. "/file", { 2, 0, 0, 0 }))
  ]=],
    path
  )
  ui:wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:lua("return drawn[' E:2'] == true")
  end, 10000)
  t.assert_eq(0, ui:lua("return #reports.error"))
  t.assert_eq(0, ui:lua("return #vim.api.nvim_buf_get_extmarks(view.bufnr, namespace, 0, -1, {})"))
  ui:lua([=[
    await(data:set_diagnostics(1, 1, 2, nil, {0, 0, 0, 0}))
    assert(vim.wait(10000, function()
      return view._filetree_annotations and view._filetree_annotations.rows[1].diagnostics[1] == 0
    end))
    drawn = {}
  ]=])
  ui:rpc("nvim_command", "redraw")
  t.assert_eq(false, ui:lua("return drawn[' E:2'] == true"))
  t.assert_eq("  file", ui:lua("return vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1]"))
  ui:lua("view:detach()")
end)

t:run()
