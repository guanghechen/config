local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local UI = require("__test__.support.ui")
local t = harness.new()

---@param lines                         string[]
---@return __test__.support.UI
local function editor(lines)
  return embedded.editor(t, lines)
end

local wait = embedded.wait

t:test("command completion preserves command prefixes and cancel restores the command", function()
  local ui = editor({ "" })
  ui:rpc("nvim_input", ":set nu")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "command menu")
  ui:rpc("nvim_input", "<Tab>")
  wait(ui, [[return vim.fn.getcmdline() ~= 'set nu']], "command preview")
  t.assert_true(ui:lua([[return vim.startswith(vim.fn.getcmdline(), 'set ')]]), "command prefix")
  ui:rpc("nvim_input", "<C-e>")
  wait(ui, [[return vim.fn.getcmdline() == 'set nu']], "command cancellation")
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("native search completion remains manual and follows search matches", function()
  local ui = editor({ "alpha alpine" })
  ui:rpc("nvim_input", "/al")
  wait(ui, [[return vim.fn.getcmdline() == 'al']], "search input")
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "manual search menu")
  ui:rpc("nvim_input", "<Tab>")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "search menu")
  wait(ui, [[return vim.fn.getcmdline() == 'alpine']], "next native search match")
  ui:rpc("nvim_input", "<C-e>")
  wait(ui, [[return vim.fn.getcmdline() == 'al']], "search cancellation")
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("command completion handles escaped spaces and preserves the directory prefix", function()
  local directory = t:tempdir()
  vim.fn.mkdir(directory .. "/folder with space", "p")
  vim.fn.writefile({}, directory .. "/folder with space/file.lua")
  t:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  local ui = editor({ "" })
  ui:lua([[vim.api.nvim_set_current_dir(...)]], directory)
  ui:rpc("nvim_input", ":edit ./folder\\ with\\ space/fi")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "path menu")
  ui:rpc("nvim_input", "<C-y>")
  wait(ui, [[return vim.fn.getcmdline() == 'edit ./folder\\ with\\ space/file.lua']], "escaped path acceptance")
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("Lua command completion retains the expression namespace", function()
  local ui = editor({ "" })
  ui:rpc("nvim_input", ":lua vim.api.nvim_get_cu")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "expression candidates")
  ui:rpc("nvim_input", "<C-y>")
  wait(ui, [[return vim.startswith(vim.fn.getcmdline(), 'lua vim.api.nvim_get_current_')]], "complete expression")
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("custom completion preserves raw prefix bytes pasted from a register", function()
  local ui = editor({ "" })
  ui:lua([[
    vim.api.nvim_create_user_command('CmpBytes', function() end, {
      nargs = '*', complete = function() return { 'alpha', 'alpine' } end,
    })
    vim.fn.setreg('a', string.char(255) .. '.prefix ')
  ]])
  ui:rpc("nvim_input", ":CmpBytes <C-r>aal")
  wait(ui, [[return vim.fn.getcmdline() == 'CmpBytes ' .. string.char(255) .. '.prefix al']], "register pasted")
  vim.wait(30)
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "opaque prefix does not cause native conversion errors")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "valid custom candidates")
  ui:rpc("nvim_input", "<C-y>")
  wait(
    ui,
    [[return vim.fn.getcmdline() == 'CmpBytes ' .. string.char(255) .. '.prefix alpha']],
    "raw prefix preserved on accept"
  )
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("custom command completion replaces its argument exactly once", function()
  local ui = editor({ "" })
  ui:lua([[
    vim.api.nvim_create_user_command('CmpFixture', function() end, {
      nargs = 1, complete = function() return { 'mode=first', 'mode=second' } end,
    })
  ]])
  ui:rpc("nvim_input", ":CmpFixture mode=f")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "custom candidates")
  ui:rpc("nvim_input", "<C-y>")
  wait(ui, [[return vim.fn.getcmdline() == 'CmpFixture mode=first']], "custom argument acceptance")
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("initializing completion inside command-line mode installs working native mappings", function()
  local root = assert(vim.uv.cwd())
  local ui = UI.new()
  t:defer(function()
    ui:close()
  end)
  ui:start({ width = 100, height = 35 })
  ui:lua([[
    require('__test__.support.cmp.runtime').setup()
  ]])
  ui:rpc("nvim_input", ":")
  ui:wait_until(function()
    return ui:lua([[return vim.fn.getcmdtype()==':']])
  end, 1000, "cmdline before setup")
  ui:lua([[require('era.keystroke.cmp').setup()]])
  ui:rpc("nvim_input", "set nu")
  ui:wait_until(function()
    return ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]])
  end, 1000, "completion after setup")
  t.assert_eq("set nu", ui:lua([[return vim.fn.getcmdline()]]))
  ui:rpc("nvim_input", "<Tab>")
  ui:wait_until(function()
    return ui:lua([[return vim.fn.getcmdline()=='set number']])
  end, 1000, "installed mapping selects native candidate")
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "setup and mappings do not error")
end)

t:test("nested expression cmdlines leave completion to the native editor", function()
  local ui = editor({ "" })
  ui:rpc("nvim_input", ":set nu")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "outer menu")
  ui:rpc("nvim_input", "<C-r>=")
  wait(ui, [[return vim.fn.getcmdtype() == '=']], "nested expression")
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "inner menu remains native")
  ui:rpc("nvim_input", "1<CR>")
  wait(ui, [[return vim.fn.getcmdline() == 'set nu1']], "outer command restored")
  ui:rpc("nvim_input", "<BS>")
  wait(
    ui,
    [[return vim.fn.getcmdline() == 'set nu' and require('era.keystroke.cmp').is_menu_visible()]],
    "outer completion resumes"
  )
  ui:rpc("nvim_input", "<Esc>")
end)

t:test("nested input restores the outer command's native selection policy", function()
  local ui = editor({ "" })
  ui:rpc("nvim_input", ":set nu")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "outer completion")
  ui:rpc("nvim_input", "<C-e>")
  wait(ui, [[return not require('era.keystroke.cmp').is_menu_visible()]], "outer menu cancelled")
  ui:rpc("nvim_input", "<C-r>=input('nested: ')<CR>")
  wait(ui, [[return vim.fn.getcmdtype() == '@']], "nested input")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.fn.getcmdtype() == ':']], "outer command restored")
  ui:rpc("nvim_input", "m")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "outer completion resumed")
  t.assert_eq("set num", ui:lua([[return vim.fn.getcmdline()]]), "automatic completion does not insert a candidate")
end)

t:test("expression registers preserve native digraph and confirmation keys", function()
  local ui = editor({ "" })
  ui:rpc("nvim_input", "i<C-r>=")
  wait(ui, [[return vim.fn.getcmdtype() == '=']], "expression register")
  ui:rpc("nvim_input", "'<C-k>ae'")
  wait(ui, [[return vim.fn.getcmdline() == "'æ'"]], "native digraph")
  ui:rpc("nvim_input", "<C-j>")
  wait(
    ui,
    [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i' and vim.api.nvim_get_current_line() == 'æ']],
    "native confirmation"
  )
end)

t:run()
