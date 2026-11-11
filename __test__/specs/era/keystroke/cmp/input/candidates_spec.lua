local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local t = harness.new()

local lsp_client = embedded.lsp_client

-- An editor over an empty Lua file named stem.lua, with the friendly-snippets fixture package on the runtimepath.
---@return __test__.support.UI
local function snippet_editor()
  local ui = embedded.editor(t, { "" })
  ui:lua(
    [[
    local root = ...
    vim.opt.runtimepath:prepend(root .. '/__test__/fixtures/era/keystroke/cmp/friendly-snippets')
    vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. '/stem.lua')
  ]],
    vim.uv.cwd()
  )
  return ui
end

t:test("native fuzzy completion preserves ranked aliases and duplicate alternatives", function()
  local ui = embedded.editor(t, { "" })
  ui:lua([[
    local Menu = require('era.keystroke.cmp.menu')
    local show = Menu.show
    Menu.show = function(self,context,items,selected)
      _G.cmp_ranked_labels = vim.tbl_map(function(item) return item.raw.label end,items)
      return show(self,context,items,selected)
    end
  ]])
  lsp_client(
    ui,
    [[return function(_, callback)
    callback(nil, {
      {label='dateDMY',filterText='dd',sortText='1',insertText='replacement'},
      {label='dateMDY',filterText='dd',sortText='2'},
      {label='dd',filterText='dd',sortText='3'},
      {label='filter alias',filterText='dd',sortText='4'},
      {label='dateDMY',filterText='dd',sortText='5',insertText='replacement',detail='alternative'},
    })
  end]]
  )
  ui:rpc("nvim_input", "idd")
  ui:wait_lua([[return #vim.fn.complete_info({'items'}).items == 5]], 5000, "all ranked candidates remain visible")
  t.assert_eq(
    ui:lua([[return table.concat(cmp_ranked_labels,',')]]),
    ui:lua([[
      return table.concat(vim.tbl_map(function(item) return item.abbr end,vim.fn.complete_info({'items'}).items),',')
    ]]),
    "native items retain the published Rust order, including filterText aliases"
  )
  for index = 0, 4 do
    ui:lua([[vim.api.nvim_select_popupmenu_item(...,false,false,{})]], index)
    ui:wait_lua("return vim.fn.complete_info({'selected'}).selected == " .. index, 5000, "native selection")
    t.assert_eq(
      index + 1,
      ui:lua([[return vim.fn.complete_info({'completed'}).completed.user_data.index]]),
      "native selection follows the Rust candidate order"
    )
  end
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'replacement']], 5000, "the selected alternative is accepted")
end)

t:test("native fuzzy completion retains typo-only candidates", function()
  local ui = embedded.editor(t, { "" })
  lsp_client(
    ui,
    [[return function(_, callback)
    callback(nil, {{label='completion'}})
  end]]
  )
  ui:rpc("nvim_input", "icompletiom")
  ui:wait_lua(
    [[return require('era.keystroke.cmp').is_menu_visible()]],
    5000,
    "Rust typo match survives native filtering"
  )
  t.assert_eq("completion", ui:lua([[return vim.fn.complete_info({'items'}).items[1].abbr]]))
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'completion']], 5000, "typo candidate remains acceptable")
end)

t:test("plain quoted words retain buffer fallback even when the directory has files", function()
  local directory = t:tempdir()
  vim.fn.writefile({}, directory .. "/unrelated.lua")
  for _, quote in ipairs({ '"', "'", "`" }) do
    local ui = embedded.editor(t, { 'local jargon = "qzxProjectToken"', "" })
    ui:lua(
      [[
      local directory = ...
      vim.api.nvim_set_current_dir(directory)
      vim.api.nvim_buf_set_name(0, directory .. '/main.lua')
      require('era.keystroke.cmp.policy').sources_for = function() return { 'path', 'buffer' } end
    ]],
      directory
    )
    ui:rpc("nvim_input", "ilocal text = " .. quote .. "qzxP")
    ui:wait_lua(
      [[return require('era.keystroke.cmp').is_menu_visible()]],
      5000,
      "buffer candidate appears automatically"
    )
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_lua(
      [[return require('era.keystroke.cmp').is_menu_visible()]],
      5000,
      "manual refresh keeps the buffer candidate"
    )
    ui:rpc("nvim_input", "<C-y>")
    ui:wait_until(function()
      return ui:lua("return vim.api.nvim_get_current_line()") == "local text = " .. quote .. "qzxProjectToken"
    end, 5000, "acceptance replaces only the quoted prefix")
  end
end)

t:test("long path prefixes remain visible and accept after the fuzzy query limit", function()
  local directory = t:tempdir()
  local prefix = ("a"):rep(128)
  local filename = prefix .. "b.lua"
  vim.fn.writefile({}, directory .. "/" .. filename)
  local ui = embedded.editor(t, { "" })
  ui:lua(
    [[
    local directory = ...
    vim.api.nvim_set_current_dir(directory)
    vim.api.nvim_buf_set_name(0, directory .. '/main.lua')
    require('era.keystroke.cmp.policy').sources_for = function() return { 'path' } end
  ]],
    directory
  )
  ui:rpc("nvim_input", 'ilocal file = "./' .. prefix)
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "128-codepoint prefix matches")
  ui:rpc("nvim_input", "b")
  ui:wait_lua([[return vim.api.nvim_get_current_line():sub(-1) == 'b']], 5000, "129th character is processed")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "long prefix retains its candidate")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_until(function()
    return ui:lua("return vim.api.nvim_get_current_line()") == 'local file = "./' .. filename
  end, 5000, "long filename is accepted without changing the path prefix")
end)

t:test("raw bytes in a background file cannot interrupt valid completion", function()
  local path = t:tempdir() .. "/raw_bytes.txt"
  vim.fn.writefile({ "\255broken alpha 中文变量" }, path)
  local ui = embedded.editor(t, { "" })
  t.assert_eq(
    255,
    ui:lua(
      [[
      vim.o.hidden = true
      vim.cmd('edit ++enc=utf-8 ++bad=keep ' .. vim.fn.fnameescape(...))
      _G.cmp_bytes_bufnr = vim.api.nvim_get_current_buf()
      vim.api.nvim_set_option_value('swapfile', false, { buf = cmp_bytes_bufnr })
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
      vim.api.nvim_set_option_value('filetype', 'lua', { buf = 0 })
      assert(vim.api.nvim_buf_is_loaded(cmp_bytes_bufnr))
      require('era.keystroke.cmp.policy').sources_for = function() return { 'buffer' } end
      return vim.api.nvim_buf_get_lines(cmp_bytes_bufnr, 0, 1, false)[1]:byte(1)
    ]],
      path
    ),
    "file retains the invalid byte in a loaded background buffer"
  )
  ui:rpc("nvim_input", "ial")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "valid candidate remains available")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'alpha']], 5000, "valid candidate accepted")
  t.assert_eq("i", ui:lua([[return vim.api.nvim_get_mode().mode:sub(1, 1)]]), "editor remains in Insert mode")
  t.assert_eq(
    255,
    ui:lua([[return vim.api.nvim_buf_get_lines(cmp_bytes_bufnr, 0, 1, false)[1]:byte(1)]]),
    "background content is not rewritten"
  )
end)

t:test("an invalid UTF-8 query stays idle and completion resumes at the next word", function()
  local ui = embedded.editor(t, { "alpha", "\255" })
  ui:lua([[require('era.keystroke.cmp.policy').sources_for = function() return { 'buffer' } end]])
  ui:rpc("nvim_input", "Aa")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == '\255a']], 5000, "invalid query typed")
  vim.wait(30)
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "invalid query has no menu")
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "invalid query does not raise a matcher error")
  ui:rpc("nvim_input", " al")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "next valid word completes")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == '\255a alpha']], 5000, "only the valid word is replaced")
end)

t:test("persisted acceptance history survives a new LSP client instance", function()
  local completion = [[return function(_, callback)
    callback(nil, {
      { label = 'alpha', filterText = 'al', sortText = '1', kind = 6 },
      { label = 'alpine', filterText = 'al', sortText = '2', kind = 6 },
    })
  end]]
  local ui = embedded.editor(t, { "" })
  lsp_client(ui, completion)
  ui:rpc("nvim_input", "ial")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "initial candidates")
  ui:rpc("nvim_input", "<Tab>")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'alpine']], 5000, "less preferred candidate preview")
  ui:rpc("nvim_input", "<CR>")
  ui:wait_lua(
    [[return vim.api.nvim_get_current_line() == 'alpine' and not require('era.keystroke.cmp').is_menu_visible()]],
    5000,
    "acceptance recorded"
  )
  local history = ui:lua([[return vim.json.encode(dot.context.frecency.completions:dump())]])

  local restarted = embedded.editor(t, { "" })
  restarted:lua(
    [[
    dot.context.frecency.completions = yoz.completion.new_history(vim.json.decode(...))
  ]],
    history
  )
  lsp_client(restarted, completion)
  restarted:lua([[vim.lsp.get_clients({ method = 'textDocument/completion' })[1].id = 9002]])
  restarted:rpc("nvim_input", "ial")
  restarted:wait_lua(
    [[return require('era.keystroke.cmp').is_menu_visible()]],
    5000,
    "candidates from restarted client"
  )
  restarted:rpc("nvim_input", "<C-y>")
  restarted:wait_lua(
    [[return vim.api.nvim_get_current_line() == 'alpine' and not require('era.keystroke.cmp').is_menu_visible()]],
    5000,
    "accept remembered candidate"
  )
  t.assert_eq(
    "alpine",
    restarted:lua([[return vim.api.nvim_get_current_line()]]),
    "persisted history influences ranking"
  )
end)

for _, mode in ipairs({ "insert", "cmdline" }) do
  t:test(mode .. " path completion accepts a valid file alongside invalid UTF-8 filenames", function()
    local directory = t:tempdir()
    vim.fn.writefile({}, directory .. "/alpha.txt")
    -- APFS refuses names that are not UTF-8; such names only exist on byte-oriented filesystems.
    local written, err = pcall(vim.fn.writefile, {}, directory .. "/a\255.txt")
    if not written and tostring(err):find("illegal byte sequence", 1, true) then
      t.skip("the filesystem refuses names that are not UTF-8")
    end
    assert(written, err)
    local ui = embedded.editor(t, { "" })
    ui:lua([[_G.cmp_utf8_directory = ...]], directory)
    if mode == "insert" then
      ui:rpc("nvim_input", 'i"' .. directory .. "/a")
    else
      ui:rpc("nvim_input", ":edit " .. directory .. "/a")
    end
    ui:wait_lua(
      [[
      if not require('era.keystroke.cmp').is_menu_visible() then return false end
      if vim.api.nvim_get_mode().mode == 'c' then
        for index, value in ipairs(vim.fn.cmdcomplete_info().matches) do
          if value == cmp_utf8_directory .. '/alpha.txt' or value == 'alpha.txt' then
            _G.cmp_valid_file_index = index - 1
            return true
          end
        end
        return false
      end
      for _, item in ipairs(vim.fn.complete_info({ 'items' }).items) do
      if item.abbr:find('alpha.txt', 1, true) then return true end
    end
      return false
    ]],
      5000,
      "valid file candidate"
    )
    if mode == "cmdline" then
      ui:lua([[vim.api.nvim_select_popupmenu_item(cmp_valid_file_index, false, false, {})]])
      ui:wait_lua(
        [[return vim.fn.cmdcomplete_info().selected == cmp_valid_file_index]],
        5000,
        "valid native filename selected"
      )
    end
    ui:rpc("nvim_input", "<C-y>")
    if mode == "insert" then
      ui:wait_lua(
        [[return vim.api.nvim_get_current_line() == '"' .. cmp_utf8_directory .. '/alpha.txt']],
        5000,
        "file accepted"
      )
      t.assert_eq("i", ui:lua([[return vim.api.nvim_get_mode().mode:sub(1, 1)]]), "Insert mode is not interrupted")
    else
      ui:wait_lua(
        [[return vim.fn.getcmdline() == 'edit ' .. cmp_utf8_directory .. '/alpha.txt']],
        5000,
        "file argument accepted"
      )
      ui:rpc("nvim_input", "<Esc>")
    end
  end)
end

t:test("the snippet registry loads package data and native filename variables", function()
  local ui = snippet_editor()
  ui:rpc("nvim_input", "izzcmpf")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "filetype snippets")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.api.nvim_get_current_line() == "local stem = 'stem'" and vim.snippet.active()]],
    5000,
    "nested snippet variable expansion"
  )
end)

t:test("snippets come up for the start of their trigger, not for an empty or fuzzy query", function()
  local ui = snippet_editor()
  -- The language server keeps a candidate in the menu, so a missing snippet is not a menu that has yet to open.
  lsp_client(ui, [[return function(_, callback) callback(nil, { { label = 'zzcfield', kind = 5 } }) end]])
  ui:lua([[
    _G.cmp_menu_labels = function()
      local labels = {}
      for _, item in ipairs(vim.fn.complete_info({ 'items' }).items) do labels[#labels + 1] = item.abbr end
      return table.concat(labels, ' ')
    end
  ]])
  for _, keys in ipairs({ "ix.", "Szzcf" }) do
    ui:rpc("nvim_input", "<Esc>")
    ui:rpc("nvim_input", keys)
    ui:wait_lua([[return cmp_menu_labels():find('zzcfield', 1, true) ~= nil]], 5000, keys .. " menu")
    t.assert_eq(nil, ui:lua([[return cmp_menu_labels():find('zzcmp', 1, true)]]), keys .. " brings up no snippet")
  end
  ui:rpc("nvim_input", "<Esc>")
  ui:rpc("nvim_input", "Szzcm")
  ui:wait_lua([[return cmp_menu_labels():find('zzcmpfixture', 1, true) ~= nil]], 5000, "the start of a trigger")
end)

t:run()
