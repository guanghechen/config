---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ux.filetree.ui" ---@type string

local t = require("__test__.support.harness").new("ux.filetree.ui")

t:test("attached Filetree renders and withdraws ephemeral status decorations", function()
  local path = vim.fn.tempname()
  assert(vim.uv.fs_mkdir(path, 448))
  vim.fn.writefile({ "content" }, path .. "/file")
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  ui:rpc("nvim_ui_attach", 80, 24, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    local extension = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. extension, "luaopen_yoz"))()
    errors, drawn = {}, {}
    stl = { c = { Future = require("stl.c.future") }, nvim = { fn = require("stl.nvim.fn") },
      reporter = { error = function(value) errors[#errors + 1] = value.message end, warn = function() end } }
    function await(future)
      assert(vim.wait(10000, function() return future:is_done() end))
      local value = future:get_result()
      assert(not (type(value) == "table" and value.kind == "Rejected"), vim.inspect(value))
      return value
    end
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
    { assert(vim.uv.cwd()), path }
  )
  t.wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:rpc("nvim_exec_lua", "return drawn[' E:2'] == true", {})
  end, 10000)
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #vim.api.nvim_buf_get_extmarks(view.bufnr, namespace, 0, -1, {})", {}))
  ui:rpc(
    "nvim_exec_lua",
    [=[
    await(data:set_diagnostics(1, 1, 2, nil, {0, 0, 0, 0}))
    assert(vim.wait(10000, function()
      return view._filetree_annotations and view._filetree_annotations.rows[1].diagnostics[1] == 0
    end))
    drawn = {}
  ]=],
    {}
  )
  ui:rpc("nvim_command", "redraw")
  t.assert_eq(false, ui:rpc("nvim_exec_lua", "return drawn[' E:2'] == true", {}))
  t.assert_eq("  file", ui:rpc("nvim_exec_lua", "return vim.api.nvim_buf_get_lines(view.bufnr, 0, 1, true)[1]", {}))
  ui:rpc("nvim_exec_lua", "view:detach()", {})
end)

t:run()
