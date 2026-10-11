---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.view.picker.native" ---@type string

require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new("era.view.picker.native")
local native = require("__test__.support.result_tree")
local Source = require("era.view.result_source")
local Tree = require("era.view.result_tree")

---@return era.view.ResultTree
local function fixture()
  local source = Source.new("root", { label = "root" })
  source:insert("root", "dir", { label = "directory" })
  source:insert("dir", "file", { label = "file.lua" })
  local tree = Tree.new({
    name = "native picker",
    tree = source,
    present = function(_, data)
      return { label = data.label }
    end,
  })
  tree:insert("root", { nodetype = "container" })
  tree:insert("dir", { nodetype = "container" })
  tree:insert("file", { nodetype = "leaf" })
  t:defer(function()
    tree:dispose()
  end)
  return tree
end

t:test("Result publishes native counts and preserves state through hide and reopen", function()
  local tree = fixture()
  local result = era.view.PickerResult.new({
    uuid = "native result",
    name = "native result",
    diagnostic_scope = "native result",
    augroup_prefix = "native result",
    winline_hl = "Normal",
    tree = tree,
    keymaps = {},
    flags = {},
    draw = function()
      return tree:publish({ mode = "tree", rootuuid = "root" })
    end,
  })
  t:defer(function()
    result:dispose()
  end)
  result:create_win({ border = "none", number = true, winhighlight = "" }, { row = 0, col = 0, width = 40, height = 6 })
  native.await(tree:ready())
  t.assert_eq(2, result.lnum_total:snapshot())
  local state = tree.state
  tree:toggle_select("file", true, false)
  native.await(tree:ready())
  local old_bufnr = result:get_bufnr()
  result:hide()
  t.assert_false(vim.api.nvim_buf_is_valid(old_bufnr))
  result:create_win({ border = "none", number = true, winhighlight = "" }, { row = 0, col = 0, width = 40, height = 6 })
  native.await(tree:ready())
  t.assert_true(tree.state == state)
  t.assert_true(tree:isselected("file"))
  t.assert_eq(2, result.lnum_total:snapshot())
  t.assert_true(result:get_bufnr() ~= old_bufnr)
end)

t:test("Preview switches between a native subtree and a file without closing its window", function()
  local tree = fixture()
  native.publish(tree)
  local target = { owner = tree, key = "dir", foldempty = true, title = "directory" }
  local draws = 0
  local preview = era.view.PickerPreview.new({
    name = "native preview",
    diagnostic_scope = "native preview",
    relative_number = false,
    keymaps = {},
    tree = function()
      return target
    end,
    draw = function(bufnr, force)
      t.assert_true(force, "a new file buffer must force its first draw")
      draws = draws + 1
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "source content" })
      return { title = "file", cursorline = true, number = true, wrap = false }
    end,
  })
  t:defer(function()
    preview:dispose()
  end)
  local winnr = preview:create_win({ border = "none", winhighlight = "" }, { row = 0, col = 0, width = 40, height = 6 })
  preview:mark_content_dirty()
  t.wait_until(function()
    return preview._tree_view and preview._tree_view:frame() ~= nil
  end, 5000)
  t.assert_eq(0, draws)
  t.assert_true(vim.api.nvim_buf_get_lines(preview:get_bufnr(), 0, 1, true)[1]:find("file.lua", 1, true) ~= nil)
  target = nil
  preview:mark_content_dirty()
  t.wait_until(function()
    return draws == 1
  end, 5000)
  t.assert_true(vim.api.nvim_win_is_valid(winnr))
  t.assert_eq("source content", vim.api.nvim_buf_get_lines(preview:get_bufnr(), 0, 1, true)[1])
  target = { owner = tree, key = "dir", foldempty = true, title = "directory" }
  preview:mark_content_dirty()
  t.wait_until(function()
    return preview._tree_view and preview._tree_view:frame() ~= nil
  end, 5000)
  t.assert_eq(winnr, preview:get_winnr())
  t.assert_eq(1, draws)
end)

t:test("opening and reopening a file picker never writes a readonly native surface", function()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory .. "/src", "p")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  vim.fn.writefile({ "local first = true" }, directory .. "/src/one.lua")
  vim.fn.writefile({ "local second = true" }, directory .. "/src/two.lua")
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  local warnings = {}
  ui.on_redraw = function(events)
    for _, event in ipairs(events) do
      if event[1] == "msg_show" then
        for index = 2, #event do
          for _, chunk in ipairs(event[index][2]) do
            if chunk[2]:find("W10:", 1, true) then
              warnings[#warnings + 1] = chunk[2]
            end
          end
        end
      end
    end
  end
  ui:rpc("nvim_ui_attach", 160, 40, { rgb = true, ext_linegrid = true, ext_messages = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, directory = ...
    vim.opt.runtimepath:prepend(root)
    package.cpath = root .. "/lua/?.so;" .. package.cpath
    require("ark.bootstrap").setup()
    readonly_changes, picker_errors = {}, {}
    stl.reporter.error = function(value) picker_errors[#picker_errors+1] = value.message end
    vim.api.nvim_create_autocmd("FileChangedRO", {
      callback = function(event) readonly_changes[#readonly_changes+1] = event.buf end,
    })
    local function observable(value) return stl.c.Observable.from_value(value) end
    picker = era.m.picker.FiletreeComposer.new({
      name="readonly picker", permanent=true, preview=true, title="readonly picker",
      search_pattern=observable(""), flag_foldempty=observable(false), flag_fuzzy=observable(false),
      flag_regex=observable(false), flag_case_sensitive=observable(true), flag_selected=observable(false),
      flag_viewtype=observable("tree"),
    })
    picker:reset_filepaths(directory, {"src/one.lua", "src/two.lua"}, false)
    vim.keymap.set("n", "gp", function() picker:focus() end)
  ]],
    { assert(vim.uv.cwd()), directory }
  )
  for _ = 1, 2 do
    ui:rpc("nvim_input", "gp")
    t.wait_until(function()
      return ui:rpc(
        "nvim_exec_lua",
        [[
        local preview = picker._composer.preview
        return picker._treeview.view and picker._treeview:linecount() == 3
          and preview._tree_view and preview._tree_view:frame()
          and preview._tree_view:frame():header().row_count == 2 or false
      ]],
        {}
      )
    end, 5000, "Picker result and directory preview did not publish")
    local status = ui:rpc(
      "nvim_exec_lua",
      [[
      local result, preview = picker.result:get_bufnr(), picker._composer.preview:get_bufnr()
      return {
        result_readonly=vim.api.nvim_get_option_value("readonly", {buf=result}),
        preview_readonly=vim.api.nvim_get_option_value("readonly", {buf=preview}),
        result_modifiable=vim.api.nvim_get_option_value("modifiable", {buf=result}),
        preview_modifiable=vim.api.nvim_get_option_value("modifiable", {buf=preview}),
        readonly_changes=#readonly_changes, errors=picker_errors,
      }
    ]],
      {}
    )
    t.assert_eq(0, #warnings, vim.inspect(warnings))
    t.assert_eq(0, status.readonly_changes, "native publication must not trigger FileChangedRO")
    t.assert_eq(0, #status.errors, vim.inspect(status.errors))
    t.assert_false(status.result_readonly)
    t.assert_false(status.preview_readonly)
    t.assert_false(status.result_modifiable, "the result remains protected from user edits")
    t.assert_false(status.preview_modifiable, "the preview remains protected from user edits")
    ui:rpc("nvim_exec_lua", "picker:hide()", {})
  end
end)

t:test("Visual Tab selects a mixed range uniformly and clears a fully selected range", function()
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 100, 40, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root = ...
    vim.opt.runtimepath:prepend(root)
    package.cpath = root .. "/lua/?.so;" .. package.cpath
    require("ark.bootstrap").setup()
    selection_errors = {}
    stl.reporter.error = function(value) selection_errors[#selection_errors+1] = value.message end
    local function observable(value) return stl.c.Observable.from_value(value) end
    picker = era.m.picker.FiletreeComposer.new({
      name="Visual selection", permanent=true, preview=false, title="Visual selection",
      search_pattern=observable(""), flag_foldempty=observable(false), flag_fuzzy=observable(false),
      flag_regex=observable(false), flag_case_sensitive=observable(true), flag_selected=observable(false),
      flag_viewtype=observable("list"),
    })
    picker:reset_filepaths("/workspace", {"one.lua", "two.lua"}, false)
    picker.result:create_win({border="none",number=false,winhighlight=""}, {row=0,col=0,width=60,height=8})
    picker.result:focus()
    one, two = yoz.fn.md5("/workspace/one.lua"), yoz.fn.md5("/workspace/two.lua")
  ]],
    { assert(vim.uv.cwd()) }
  )
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      "return picker.result.lnum_total:snapshot() == 2 and picker._treeview.view and picker._treeview.view:frame() ~= nil",
      {}
    )
  end, 5000)
  ui:rpc("nvim_exec_lua", "picker._treeview:toggle_select(one, true, true)", {})
  t.wait_until(function()
    return ui:rpc(
      "nvim_exec_lua",
      "assert(#selection_errors == 0, vim.inspect(selection_errors)); return picker._treeview:isselected(one)",
      {}
    )
  end, 5000)
  for _, expected in ipairs({ true, false }) do
    ui:rpc("nvim_input", "ggVj")
    t.wait_until(function()
      return ui:rpc(
        "nvim_exec_lua",
        [[
        return vim.api.nvim_get_mode().mode == "V"
          and vim.api.nvim_win_get_cursor(picker.result:get_winnr())[1] == 2
      ]],
        {}
      )
    end, 5000)
    ui:rpc("nvim_exec_lua", "picker._treeview:toggle_selection()", {})
    t.wait_until(function()
      return ui:rpc(
        "nvim_exec_lua",
        [[
        local expected = ...
        return not picker._treeview:selection_pending()
          and picker._treeview:isselected(one) == expected
          and picker._treeview:isselected(two) == expected
          and vim.api.nvim_get_mode().mode == "n"
      ]],
        { expected }
      )
    end, 5000, "Visual range must use one selection value")
  end
  local errors = ui:rpc("nvim_exec_lua", "return selection_errors", {})
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:run()
