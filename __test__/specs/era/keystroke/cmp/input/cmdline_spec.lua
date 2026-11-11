local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local UI = require("__test__.support.ui")
local t = harness.new()

t:test("command completion preserves command prefixes and cancel restores the command", function()
  local ui = embedded.editor(t, { "" })
  ui:rpc("nvim_input", ":set nu")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "command menu")
  ui:rpc("nvim_input", "<Tab>")
  ui:wait_lua([[return vim.fn.getcmdline() ~= 'set nu']], 5000, "command preview")
  t.assert_true(ui:lua([[return vim.startswith(vim.fn.getcmdline(), 'set ')]]), "command prefix")
  ui:rpc("nvim_input", "<C-e>")
  ui:wait_lua([[return vim.fn.getcmdline() == 'set nu']], 5000, "command cancellation")
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("native search completion remains manual and follows search matches", function()
  local ui = embedded.editor(t, { "alpha alpine" })
  ui:rpc("nvim_input", "/al")
  ui:wait_lua([[return vim.fn.getcmdline() == 'al']], 5000, "search input")
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "manual search menu")
  ui:rpc("nvim_input", "<Tab>")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "search menu")
  ui:wait_lua([[return vim.fn.getcmdline() == 'alpine']], 5000, "next native search match")
  ui:rpc("nvim_input", "<C-e>")
  ui:wait_lua([[return vim.fn.getcmdline() == 'al']], 5000, "search cancellation")
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("command completion handles escaped spaces and preserves the directory prefix", function()
  local directory = t:tempdir()
  vim.fn.mkdir(directory .. "/folder with space", "p")
  vim.fn.writefile({}, directory .. "/folder with space/file.lua")
  local ui = embedded.editor(t, { "" })
  ui:lua([[vim.api.nvim_set_current_dir(...)]], directory)
  ui:rpc("nvim_input", ":edit ./folder\\ with\\ space/fi")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "path menu")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.fn.getcmdline() == 'edit ./folder\\ with\\ space/file.lua']],
    5000,
    "escaped path acceptance"
  )
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("Lua command completion retains the expression namespace", function()
  local ui = embedded.editor(t, { "" })
  ui:rpc("nvim_input", ":lua vim.api.nvim_get_cu")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "expression candidates")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.startswith(vim.fn.getcmdline(), 'lua vim.api.nvim_get_current_')]],
    5000,
    "complete expression"
  )
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("custom completion preserves raw prefix bytes pasted from a register", function()
  local ui = embedded.editor(t, { "" })
  ui:lua([[
    vim.api.nvim_create_user_command('CmpBytes', function() end, {
      nargs = '*', complete = function() return { 'alpha', 'alpine' } end,
    })
    vim.fn.setreg('a', string.char(255) .. '.prefix ')
  ]])
  ui:rpc("nvim_input", ":CmpBytes <C-r>aal")
  ui:wait_lua(
    [[return vim.fn.getcmdline() == 'CmpBytes ' .. string.char(255) .. '.prefix al']],
    5000,
    "register pasted"
  )
  vim.wait(30)
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "opaque prefix does not cause native conversion errors")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "valid custom candidates")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.fn.getcmdline() == 'CmpBytes ' .. string.char(255) .. '.prefix alpha']],
    5000,
    "raw prefix preserved on accept"
  )
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("custom command completion replaces its argument exactly once", function()
  local ui = embedded.editor(t, { "" })
  ui:lua([[
    vim.api.nvim_create_user_command('CmpFixture', function() end, {
      nargs = 1, complete = function() return { 'mode=first', 'mode=second' } end,
    })
  ]])
  ui:rpc("nvim_input", ":CmpFixture mode=f")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "custom candidates")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.fn.getcmdline() == 'CmpFixture mode=first']], 5000, "custom argument acceptance")
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("initializing completion inside command-line mode installs working native mappings", function()
  local ui = UI.open(t, { width = 100, height = 35 })
  ui:lua([[
    require('__test__.support.cmp.runtime').setup()
  ]])
  ui:rpc("nvim_input", ":")
  ui:wait_until(function()
    return ui:lua([[return vim.fn.getcmdtype()==':']])
  end, 5000, "cmdline before setup")
  ui:lua([[require('era.keystroke.cmp').setup()]])
  ui:rpc("nvim_input", "set nu")
  ui:wait_until(function()
    return ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]])
  end, 5000, "completion after setup")
  t.assert_eq("set nu", ui:lua([[return vim.fn.getcmdline()]]))
  ui:rpc("nvim_input", "<Tab>")
  ui:wait_until(function()
    return ui:lua([[return vim.fn.getcmdline()=='set number']])
  end, 5000, "installed mapping selects native candidate")
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "setup and mappings do not error")
end)

t:test("nested expression cmdlines leave completion to the native editor", function()
  local ui = embedded.editor(t, { "" })
  ui:rpc("nvim_input", ":set nu")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "outer menu")
  ui:rpc("nvim_input", "<C-r>=")
  ui:wait_lua([[return vim.fn.getcmdtype() == '=']], 5000, "nested expression")
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "inner menu remains native")
  ui:rpc("nvim_input", "1<CR>")
  ui:wait_lua([[return vim.fn.getcmdline() == 'set nu1']], 5000, "outer command restored")
  ui:rpc("nvim_input", "<BS>")
  ui:wait_lua(
    [[return vim.fn.getcmdline() == 'set nu' and require('era.keystroke.cmp').is_menu_visible()]],
    5000,
    "outer completion resumes"
  )
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("nested input restores the outer command's native selection policy", function()
  local ui = embedded.editor(t, { "" })
  ui:rpc("nvim_input", ":set nu")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "outer completion")
  ui:rpc("nvim_input", "<C-e>")
  ui:wait_lua([[return not require('era.keystroke.cmp').is_menu_visible()]], 5000, "outer menu cancelled")
  ui:rpc("nvim_input", "<C-r>=input('nested: ')<CR>")
  ui:wait_lua([[return vim.fn.getcmdtype() == '@']], 5000, "nested input")
  ui:rpc("nvim_input", "<CR>")
  ui:wait_lua([[return vim.fn.getcmdtype() == ':']], 5000, "outer command restored")
  ui:rpc("nvim_input", "m")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "outer completion resumed")
  t.assert_eq("set num", ui:lua([[return vim.fn.getcmdline()]]), "automatic completion does not insert a candidate")
end)

t:test("expression registers preserve native digraph and confirmation keys", function()
  local ui = embedded.editor(t, { "" })
  ui:rpc("nvim_input", "i<C-r>=")
  ui:wait_lua([[return vim.fn.getcmdtype() == '=']], 5000, "expression register")
  ui:rpc("nvim_input", "'<C-k>ae'")
  ui:wait_lua([[return vim.fn.getcmdline() == "'æ'"]], 5000, "native digraph")
  -- A menu that must not open gets the time it would take.
  vim.wait(100)
  t.assert_false(ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "no menu in the expression")
  ui:rpc("nvim_input", "<C-j>")
  ui:wait_lua(
    [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i' and vim.api.nvim_get_current_line() == 'æ']],
    5000,
    "native confirmation"
  )
  vim.wait(100)
  t.assert_same({ "æ" }, ui:lua([[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), "confirmed text")
  t.assert_same({ 1, 2 }, ui:lua([[return vim.api.nvim_win_get_cursor(0)]]), "cursor after the confirmed text")
  t.assert_false(ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "no menu after confirmation")
end)

t:run()
