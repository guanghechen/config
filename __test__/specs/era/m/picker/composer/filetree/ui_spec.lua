local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local UI = require("__test__.support.ui")

---@return __test__.support.UI
---@return string
local function new_picker_ui()
  local directory = require("ux.filetree.path").from_os(t:tempdir())
  vim.fn.mkdir(directory .. "/root", "p")
  vim.fn.writefile({ "a" }, directory .. "/root/a.lua")
  vim.fn.writefile({ "b" }, directory .. "/root/b.lua")
  local ui = UI.open(t, { width = 100, height = 32, runtime = "ark" }, { cwd = directory .. "/root" })
  ui:lua(
    [[
    local path = ...
    errors = {}
    stl.reporter.error = function(value) errors[#errors + 1] = value.message end
    picker = era.m.picker.FiletreeComposer.new(require("__test__.support.picker").tree_props({
      name = "file operation", permanent = false, preview = false, title = "file operation",
    }))
    test_directory = path
    picker:reset_filepaths(path, { path .. "/a.lua", path .. "/b.lua" }, false)
    picker:focus()
  ]],
    directory .. "/root"
  )
  ui:wait_lua(
    "return picker._treeview.view and picker._treeview.view:frame() and picker.result.lnum_total:snapshot() == 2",
    5000,
    "two rows"
  )
  return ui, directory
end

t:test("create rejects a directory replaced while its prompt is open", function()
  local ui, directory = new_picker_ui()
  ui:lua([[
    vim.ui.input = function(_, callback) pending = callback end
    picker:__file_operation__("create")
  ]])
  ui:wait_lua("return pending ~= nil", 5000, "prompt open")
  assert(vim.uv.fs_rename(directory .. "/root", directory .. "/original"))
  assert(vim.uv.fs_mkdir(directory .. "/root", 493))
  ui:lua([[pending("created.txt")]])
  ui:wait_lua("return not picker._file_operation_busy", 5000, "operation settled")
  t.assert_nil(vim.uv.fs_stat(directory .. "/root/created.txt"), "replacement directory must remain untouched")
  t.assert_nil(vim.uv.fs_stat(directory .. "/original/created.txt"), "moved directory must remain untouched")
  t.assert_true(ui:lua("return #errors > 0"), "stale target must be reported")
end)

for _, phase in ipairs({ "before action", "during prompt" }) do
  t:test("an old Frame rename preserves a producer replaced " .. phase, function()
    local ui = new_picker_ui()
    ui:lua([[
      vim.cmd.stopinsert()
      vim.api.nvim_set_current_win(picker.result:get_winnr())
      picker.result:set_lnum_current(1)
      vim.cmd.normal({args={"V"}, bang=true})
      vim.ui.input = function(_, callback) pending = callback end
    ]])
    if phase == "during prompt" then
      ui:lua([[picker:__file_operation__("rename")]])
      ui:wait_lua("return pending ~= nil", 5000, "prompt open")
    end
    ui:lua([[picker:reset_filepaths(test_directory, {test_directory .. "/b.lua"}, false)]])
    ui:wait_lua(
      [[
      return picker._treeview.state:snapshot():source():id(require("era.view.result_paths").key(test_directory .. "/a.lua")) == nil
    ]],
      5000,
      "the replacement producer prepared"
    )
    t.assert_eq(
      "a.lua",
      ui:lua([[
      local _, item = picker:__retrieve_file__()
      return item and item.basename
    ]]),
      "the visible Frame still owns the original action target"
    )
    if phase == "before action" then
      ui:lua([[picker:__file_operation__("rename")]])
      ui:wait_lua("return pending ~= nil", 5000, "prompt open")
    end
    ui:lua([[pending("renamed.lua")]])
    ui:wait_lua(
      [[return vim.uv.fs_stat(test_directory .. "/renamed.lua") ~= nil and not require("era.m.filetree.jobs").pending()]],
      5000,
      "renamed"
    )
    ui:lua([[vim.cmd.normal({args={vim.keycode("<Esc>")}, bang=true})]])
    ui:wait_lua("return not picker._file_operation_busy", 5000, "operation settled")
    local files = ui:lua([[
      local files = {}
      for _, uuid in ipairs(picker._uuids_order:keys()) do
        files[#files + 1] = picker._filetree:get(uuid).basename
      end
      return files
    ]])
    t.assert_eq(1, #files, "the replacement producer must keep its own membership")
    t.assert_eq("b.lua", files[1])
    t.assert_eq(0, ui:lua("return #errors"))
  end)
end

---Open a permanent picker over alpha.txt, beta.txt and gamma.txt in a child UI, showing all three rows matched.
---@param names                         ?string[] Other files to list.
---@return __test__.support.UI ui
---@return string root
local function open_typed_ahead(names)
  names = names or { "alpha.txt", "beta.txt", "gamma.txt" }
  local root = t:tempdir()
  for _, name in ipairs(names) do
    vim.fn.writefile({ name }, root .. "/" .. name)
  end
  local ui = UI.open(t, { width = 100, height = 32, runtime = "ark" }, { cwd = root })
  ui:lua(
    [[
    confirmed, loading, current = nil, nil, nil
    picker = era.m.picker.FiletreeComposer.new(require("__test__.support.picker").tree_props({
      name = "typed ahead", title = "typed ahead", permanent = true, preview = false,
      flag_fuzzy = true, flag_case_sensitive = false, flag_viewtype = "list",
      on_confirm = function(composer, filepaths)
        confirmed = filepaths and filepaths[1] or false
        loading, current = composer._path_request ~= nil, composer._treeview:is_current()
        composer:close()
      end,
    }))
    local root, names = ...
    picker:reset_filepaths(root, vim.tbl_map(function(name) return root .. "/" .. name end, names), false)
    picker:focus()
  ]],
    root,
    names
  )
  ui:wait_lua(
    "return picker._treeview:linecount() == ... and not picker._scheduler_match:pending()",
    5000,
    "every row",
    #names
  )
  return ui, root
end

---Paths beside the three files, enough that preparing and showing them span many ticks.
local WIDE_PATHS = [[
  local paths = { "alpha.txt", "beta.txt", "gamma.txt" }
  for index = 1, 10000 do
    paths[#paths + 1] = string.format("file%05d.lua", index)
  end
]]

t:test("Tab typed ahead with a query selects a row of that query", function()
  local ui, root = open_typed_ahead({ "alpha.txt", "beta.txt", "gamma.txt", "delta.txt", "theta.txt" })
  -- "del" leaves delta alone, where <C-j> over all five rows reaches beta.
  ui:rpc("nvim_input", "idel<C-j><Tab>")
  ui:wait_lua(
    "return not picker._treeview:selection_pending() and #picker._treeview:selected_keys(true) > 0",
    5000,
    "selected"
  )
  t.assert_same(
    { root .. "/delta.txt" },
    ui:lua([[
      return vim.tbl_map(function(key)
        return picker._treeview:data(key).filepath
      end, picker._treeview:selected_keys(true))
    ]])
  )
end)

t:test("a query typed ahead of <CR> confirms from its own results", function()
  local ui = open_typed_ahead()
  -- One burst, as keys typed faster than the match debounce arrive: <CR> runs before the query is matched.
  ui:rpc("nvim_input", "igamma<CR>")
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("gamma.txt", ui:lua("return confirmed"))
end)

t:test("a query typed ahead of <CR> right after reset_filepaths confirms from its own results", function()
  local ui, root = open_typed_ahead()
  ui:lua(
    [[
    local root = ...
    prepared = picker:prepare_filepaths(root, { "alpha.txt", "beta.txt", "gamma.txt" })
  ]],
    root
  )
  ui:wait_lua(
    "return prepared:is_done() and picker._treeview:is_current() and not picker._scheduler_match:pending()",
    5000,
    "prepared paths shown"
  )
  -- Pickers that reset their paths on open, such as Find Diagnostics, show them while the keys run.
  ui:lua(
    [[
    local root = ...
    picker:reset_filepaths(root, { root .. "/alpha.txt", root .. "/beta.txt", root .. "/gamma.txt" }, false)
    vim.api.nvim_input("igamma<CR>")
  ]],
    root
  )
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("gamma.txt", ui:lua("return confirmed"))
end)

t:test("keys typed after a deferred <CR> leave its query", function()
  local ui, root = open_typed_ahead()
  -- <CR> waits for the selection <Tab> submits; zz reaches the input before it runs.
  ui:rpc("nvim_input", "i<Tab><CR>zz")
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq(root .. "/alpha.txt", ui:lua("return confirmed"), "the selection <Tab> made")
end)

t:test("<CR> while paths load waits for them and confirms from its query", function()
  local ui, root = open_typed_ahead()
  -- Typeahead runs before the next slice of the preparation; zz, typed after <CR>, waits in it.
  local preparing = ui:lua("local root = ... " .. WIDE_PATHS .. [[
    picker:prepare_filepaths(root, paths)
    vim.api.nvim_input("igamma<CR>zz")
    return picker._path_request ~= nil
  ]], root)
  t.assert_true(preparing, "a wide path set loads across ticks")
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("gamma.txt", ui:lua("return confirmed"))
  t.assert_false(ui:lua("return loading"), "confirmed after the paths loaded")
  t.assert_true(ui:lua("return current"), "confirmed on the rows of the loaded paths")
end)

t:test("<CR> while the paths are still being found waits for them", function()
  local ui, root = open_typed_ahead()
  ui:lua("local root = ... " .. WIDE_PATHS .. [[
    local found, resolve = stl.c.Future.new_with_resolver()
    picker:prepare_filepaths(root, found)
    vim.api.nvim_input("igamma<CR>")
    vim.defer_fn(function()
      resolve(paths)
    end, 200)
  ]], root)
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("gamma.txt", ui:lua("return confirmed"))
  t.assert_true(ui:lua("return current"), "confirmed on the rows of the found paths")
end)

t:test("<CR> while loaded paths publish waits for them to show", function()
  local ui, root = open_typed_ahead()
  ui:lua("local root = ... " .. WIDE_PATHS .. [[
    picker:prepare_filepaths(root, paths):finally(function()
      vim.api.nvim_input("igamma<CR>")
    end)
  ]], root)
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("gamma.txt", ui:lua("return confirmed"))
  t.assert_true(ui:lua("return current"), "confirmed on the rows of the loaded paths")
end)

t:test("<CR> after a hide cancels matching the adopted paths waits for them to show", function()
  local ui, root = open_typed_ahead()
  ui:lua("local root = ... " .. WIDE_PATHS .. [[
    local tree = picker._treeview
    local adopt = tree.adopt_filepaths
    tree.adopt_filepaths = function(...)
      adopt(...)
      tree.adopt_filepaths = nil
      picker:hide()
    end
    prepared = picker:prepare_filepaths(root, paths)
  ]], root)
  ui:wait_lua("return prepared:is_done()", 5000, "preparation cancelled")
  ui:lua([[
    picker:focus()
    vim.api.nvim_input("igamma<CR>")
  ]])
  ui:wait_lua("return confirmed ~= nil", 5000, "confirmed")
  t.assert_eq("gamma.txt", ui:lua("return confirmed"))
  t.assert_true(ui:lua("return current"), "confirmed on the rows of the adopted paths")
end)

t:test("opening and reopening a file picker never writes a readonly native surface", function()
  local directory = t:tempdir()
  vim.fn.mkdir(directory .. "/src", "p")
  vim.fn.writefile({ "local first = true" }, directory .. "/src/one.lua")
  vim.fn.writefile({ "local second = true" }, directory .. "/src/two.lua")
  local ui = UI.open(t)
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
  ui:start({ width = 160, height = 40, runtime = "ark", ui = { ext_messages = true } })
  ui:lua(
    [[
    local directory = ...
    readonly_changes, picker_errors = {}, {}
    stl.reporter.error = function(value) picker_errors[#picker_errors+1] = value.message end
    vim.api.nvim_create_autocmd("FileChangedRO", {
      callback = function(event) readonly_changes[#readonly_changes+1] = event.buf end,
    })
    picker = era.m.picker.FiletreeComposer.new(require("__test__.support.picker").tree_props({
      name="readonly picker", permanent=true, preview=true, title="readonly picker",
    }))
    picker:reset_filepaths(directory, {"src/one.lua", "src/two.lua"}, false)
    vim.keymap.set("n", "gp", function() picker:focus() end)
  ]],
    directory
  )
  for _ = 1, 2 do
    ui:rpc("nvim_input", "gp")
    ui:wait_lua(
      [[
        local preview = picker._composer.preview
        return picker._treeview.view and picker._treeview:linecount() == 3
          and preview._tree_view and preview._tree_view:frame()
          and preview._tree_view:frame():header().row_count == 2 or false
      ]],
      5000,
      "Picker result and directory preview did not publish"
    )
    local status = ui:lua([[
      local result, preview = picker.result:get_bufnr(), picker._composer.preview:get_bufnr()
      return {
        result_readonly=vim.api.nvim_get_option_value("readonly", {buf=result}),
        preview_readonly=vim.api.nvim_get_option_value("readonly", {buf=preview}),
        result_modifiable=vim.api.nvim_get_option_value("modifiable", {buf=result}),
        preview_modifiable=vim.api.nvim_get_option_value("modifiable", {buf=preview}),
        readonly_changes=#readonly_changes, errors=picker_errors,
      }
    ]])
    t.assert_eq(0, #warnings, vim.inspect(warnings))
    t.assert_eq(0, status.readonly_changes, "native publication must not trigger FileChangedRO")
    t.assert_eq(0, #status.errors, vim.inspect(status.errors))
    t.assert_false(status.result_readonly)
    t.assert_false(status.preview_readonly)
    t.assert_false(status.result_modifiable, "the result remains protected from user edits")
    t.assert_false(status.preview_modifiable, "the preview remains protected from user edits")
    ui:lua("picker:hide()")
  end
end)

t:test("Visual Tab selects a mixed range uniformly and clears a fully selected range", function()
  local ui = UI.open(t, { width = 100, height = 40, runtime = "ark" })
  ui:lua([[
    selection_errors = {}
    stl.reporter.error = function(value) selection_errors[#selection_errors+1] = value.message end
    picker = era.m.picker.FiletreeComposer.new(require("__test__.support.picker").tree_props({
      name="Visual selection", permanent=true, preview=false, title="Visual selection", flag_viewtype="list",
    }))
    picker:reset_filepaths("/workspace", {"one.lua", "two.lua"}, false)
    picker.result:create_win({border="none",number=false,winhighlight=""}, {row=0,col=0,width=60,height=8})
    picker.result:focus()
    one, two = yoz.fn.md5("/workspace/one.lua"), yoz.fn.md5("/workspace/two.lua")
  ]])
  ui:wait_lua(
    "return picker.result.lnum_total:snapshot() == 2 and picker._treeview.view and picker._treeview.view:frame() ~= nil",
    5000,
    "two rows"
  )
  ui:lua("picker._treeview:toggle_select(one, true, true)")
  ui:wait_lua(
    "assert(#selection_errors == 0, vim.inspect(selection_errors)); return picker._treeview:isselected(one)",
    5000,
    "one selected"
  )
  for _, expected in ipairs({ true, false }) do
    ui:rpc("nvim_input", "ggVj")
    ui:wait_lua(
      [[
        return vim.api.nvim_get_mode().mode == "V"
          and vim.api.nvim_win_get_cursor(picker.result:get_winnr())[1] == 2
      ]],
      5000,
      "Visual range over both rows"
    )
    ui:lua("picker._treeview:toggle_selection()")
    ui:wait_lua(
      [[
        local expected = ...
        return not picker._treeview:selection_pending()
          and picker._treeview:isselected(one) == expected
          and picker._treeview:isselected(two) == expected
          and vim.api.nvim_get_mode().mode == "n"
      ]],
      5000,
      "Visual range must use one selection value",
      expected
    )
  end
  local errors = ui:lua("return selection_errors")
  t.assert_eq(0, #errors, vim.inspect(errors))
end)

t:run()
