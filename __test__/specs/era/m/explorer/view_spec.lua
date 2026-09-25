---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.explorer.view" ---@type string

local t = require("__test__.support.harness").new("era.m.explorer.view")

t:test("real UI subscribes to diagnostics and Git ignore with independent name and icon colors", function()
  local path = vim.fn.tempname()
  assert(vim.uv.fs_mkdir(path, 448))
  vim.fn.writefile({ "content" }, path .. "/a.lua")
  vim.fn.writefile({ "content" }, path .. "/b.py")
  vim.fn.writefile({ "b.py" }, path .. "/.gitignore")
  local initialized = vim.system({ "git", "-C", path, "init", "-q" }, { text = true }):wait()
  t.assert_eq(0, initialized.code, initialized.stderr)
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
    vim.fn.delete(path, "rf")
  end)
  ui:rpc("nvim_ui_attach", 100, 30, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local root, path = ...
    vim.opt.runtimepath:prepend(root)
    local suffix = vim.uv.os_uname().sysname == "Darwin" and "dylib" or "so"
    yoz = assert(package.loadlib(root .. "/rust/target/debug/libyoz." .. suffix, "luaopen_yoz"))()
    stl, dot, era = require("stl"), require("dot"), require("era")
    dot.path.workspace = function() return path end
    dot.path.is_git_repo = function() return true end
    errors, drawn, colors, icons, glyphs = {}, {}, {}, {}, {}
    stl.reporter.warn = function(value) errors[#errors + 1] = value.message end
    stl.reporter.error = function(value) errors[#errors + 1] = value.message end
    stl.reporter.info = function() end
    local explorer_ns = vim.api.nvim_create_namespace("era.explorer")
    local annotation_ns = vim.api.nvim_create_namespace("ux.filetree.annotations")
    local mark = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(bufnr, ns, row, col, options)
      if ns == explorer_ns then
        if options.hl_group then colors[row + 1] = options.hl_group end
        if options.virt_text then
          icons[row + 1] = options.virt_text[1][2]
          glyphs[row + 1] = options.virt_text[1][1]
        end
      elseif ns == annotation_ns and options.virt_text then
        for _, chunk in ipairs(options.virt_text) do drawn[chunk[1]] = true end
      end
      return mark(bufnr, ns, row, col, options)
    end
    widget = require("era.m.explorer.widget").new({
      name = "attached-test", root = path,
      o_flag_hidden = stl.c.Observable.from_value(false),
    })
    widget:focus()
    assert(vim.wait(10000, function()
      local view = widget._views[vim.api.nvim_get_current_tabpage()]
      return view and view:frame() and view:frame():header().row_count == 2
    end))
    session, view = widget:context()
    namespace = vim.api.nvim_create_namespace("explorer-live-diagnostics")
    buffers = {}
    for _, name in ipairs({ "a.lua", "b.py" }) do
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(bufnr, path .. "/" .. name)
      buffers[#buffers + 1] = bufnr
      vim.diagnostic.set(namespace, bufnr, {
        { lnum = 0, col = 0, severity = 1, message = "error" },
        { lnum = 0, col = 0, severity = 2, message = "warning" },
        { lnum = 0, col = 0, severity = 3, message = "info" },
        { lnum = 0, col = 0, severity = 4, message = "hint" },
      })
    end
  ]=],
    { assert(vim.uv.cwd()), path }
  )
  t.wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:rpc(
      "nvim_exec_lua",
      "return colors[1] == 'DiagnosticError' and colors[2] == 'm_ex_ignored' and drawn[' E:1'] and drawn[' W:1']",
      {}
    )
  end, 10000)
  t.assert_false(ui:rpc("nvim_exec_lua", "return drawn[' I:1'] == true or drawn[' H:1'] == true", {}))
  t.assert_true(ui:rpc("nvim_exec_lua", "return icons[1] ~= nil and icons[1] ~= colors[1]", {}))
  t.assert_eq("m_ex_ignored", ui:rpc("nvim_exec_lua", "return icons[2]", {}))
  t.assert_eq(0, ui:rpc("nvim_exec_lua", "return #errors", {}))
  ui:rpc(
    "nvim_exec_lua",
    [=[
    vim.diagnostic.reset(namespace)
    assert(vim.wait(10000, function()
      return view._filetree_annotations and view._filetree_annotations.rows[1].diagnostics[1] == 0
    end))
    drawn = {}
  ]=],
    {}
  )
  ui:rpc("nvim_command", "redraw")
  t.assert_false(ui:rpc("nvim_exec_lua", "return drawn[' E:1'] == true", {}))
  local source_revision, quiet_since = nil, vim.uv.hrtime()
  t.wait_until(function()
    local current = ui:rpc(
      "nvim_exec_lua",
      "return { session.data:source():revision(), session.data._native:is_busy() or session._subscriptions._running }",
      {}
    )
    if current[1] ~= source_revision or current[2] then
      source_revision, quiet_since = current[1], vim.uv.hrtime()
    end
    return vim.uv.hrtime() - quiet_since > 300000000
  end, 10000)
  for _, options in ipairs({ { git_refresh = true }, {}, { background = true } }) do
    local before = ui:rpc(
      "nvim_exec_lua",
      [=[
      local options = ...
      explorer_tabnr = vim.api.nvim_get_current_tabpage()
      local before = { session.data:source():revision(), vim.api.nvim_buf_get_changedtick(view.bufnr) }
      if options.background then vim.cmd.tabnew() end
      colors = {}
      ignore_revision = session.data._native:annotation_revision()
      require("era.m.git.ignore").clear()
      if options.git_refresh then
        require("era.m.git.state").o_refreshed:next({generation=999,change_scope="unknown"})
      end
      return before
    ]=],
      { options }
    )
    if options.background then
      t.wait_until(function()
        return ui:rpc(
          "nvim_exec_lua",
          "return session.data._native:annotation_revision() ~= ignore_revision and not session._subscriptions._running",
          {}
        )
      end, 10000)
      ui:rpc("nvim_exec_lua", "vim.api.nvim_set_current_tabpage(explorer_tabnr)", {})
    end
    t.wait_until(function()
      ui:rpc("nvim_command", "redraw")
      return ui:rpc(
        "nvim_exec_lua",
        [=[
        local path = ...
        local cache = view._filetree_annotations
        return require("era.m.git.ignore").is_ignored(path .. "/b.py")
          and cache and bit.band(cache.rows[2].git,256) ~= 0 and colors[2] == "m_ex_ignored"
          and not session._subscriptions._running
      ]=],
        { path }
      )
    end, 10000, "clearing ignore cache must requery the viewport without a manual refresh")
    t.assert_eq(before[1], ui:rpc("nvim_exec_lua", "return session.data:source():revision()", {}))
    t.assert_eq(before[2], ui:rpc("nvim_exec_lua", "return vim.api.nvim_buf_get_changedtick(view.bufnr)", {}))
  end
  ui:rpc(
    "nvim_exec_lua",
    [=[
    local path = ...
    assert(vim.uv.fs_mkdir(path .. "/lsp", 448))
    assert(vim.uv.fs_mkdir(path .. "/plain", 448))
    widget:refresh()
    assert(vim.wait(10000, function() return view:frame():header().row_count == 4 end))
    vim.api.nvim_win_set_cursor(view.winnr, {1, 0})
    vim.api.nvim_win_call(view.winnr, function() vim.cmd("normal! zt") end)
    colors, icons = {}, {}
  ]=],
    { path }
  )
  t.wait_until(function()
    ui:rpc("nvim_command", "redraw")
    return ui:rpc(
      "nvim_exec_lua",
      "return icons[1] == 'MiniIconsGreen' and icons[2] == 'm_ft_dirname' and colors[1] == 'm_ft_filename' and colors[2] == 'm_ft_filename'",
      {}
    )
  end, 10000)
  for _, expanded in ipairs({ true, false, true }) do
    ui:rpc("nvim_exec_lua", "widget._action:activate()", {})
    t.wait_until(function()
      ui:rpc("nvim_command", "redraw")
      return ui:rpc(
        "nvim_exec_lua",
        [[
        local expanded = ...
        local expected = expanded and stl.icon.filetype.FolderEmptyOpen or stl.fileicon.get_directory_icon('lsp')
        return view:frame():rows(1,1).expanded[1] == expanded and glyphs[1] == expected
      ]],
        { expanded }
      )
    end, 10000, "an empty directory's icon must follow expansion even when row layout is unchanged")
  end
  ui:rpc("nvim_exec_lua", "widget:dispose()", {})
end)

t:run()
