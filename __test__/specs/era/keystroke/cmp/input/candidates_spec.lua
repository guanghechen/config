local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local t = harness.new()

---@param lines                         string[]
---@return __test__.support.UI
local function editor(lines)
  return embedded.editor(t, lines)
end

local lsp_client = embedded.lsp_client
local wait = embedded.wait

t:test("native fuzzy completion preserves ranked aliases and duplicate alternatives", function()
  local ui = editor({ "" })
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
  wait(ui, [[return #vim.fn.complete_info({'items'}).items == 5]], "all ranked candidates remain visible")
  t.assert_eq(
    ui:lua([[return table.concat(cmp_ranked_labels,',')]]),
    ui:lua([[
      return table.concat(vim.tbl_map(function(item) return item.abbr end,vim.fn.complete_info({'items'}).items),',')
    ]]),
    "native items retain the published Rust order, including filterText aliases"
  )
  for index = 0, 4 do
    ui:lua([[vim.api.nvim_select_popupmenu_item(...,false,false,{})]], index)
    wait(ui, "return vim.fn.complete_info({'selected'}).selected == " .. index, "native selection")
    t.assert_eq(
      index + 1,
      ui:lua([[return vim.fn.complete_info({'completed'}).completed.user_data.index]]),
      "native selection follows the Rust candidate order"
    )
  end
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'replacement']], "the selected alternative is accepted")
end)

t:test("native fuzzy completion retains typo-only candidates", function()
  local ui = editor({ "" })
  lsp_client(
    ui,
    [[return function(_, callback)
    callback(nil, {{label='completion'}})
  end]]
  )
  ui:rpc("nvim_input", "icompletiom")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "Rust typo match survives native filtering")
  t.assert_eq("completion", ui:lua([[return vim.fn.complete_info({'items'}).items[1].abbr]]))
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'completion']], "typo candidate remains acceptable")
end)

t:test("plain quoted words retain buffer fallback even when the directory has files", function()
  local directory = t:tempdir()
  vim.fn.writefile({}, directory .. "/unrelated.lua")
  for _, quote in ipairs({ '"', "'", "`" }) do
    local ui = editor({ 'local jargon = "qzxProjectToken"', "" })
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
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "buffer candidate appears automatically")
    ui:lua([[require('era.keystroke.cmp').show()]])
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "manual refresh keeps the buffer candidate")
    ui:rpc("nvim_input", "<CR>")
    t.wait_until(function()
      return ui:lua("return vim.api.nvim_get_current_line()") == "local text = " .. quote .. "qzxProjectToken"
    end, 1000, "acceptance replaces only the quoted prefix")
  end
end)

t:test("long path prefixes remain visible and accept after the fuzzy query limit", function()
  local directory = t:tempdir()
  local prefix = ("a"):rep(128)
  local filename = prefix .. "b.lua"
  vim.fn.writefile({}, directory .. "/" .. filename)
  local ui = editor({ "" })
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
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "128-codepoint prefix matches")
  ui:rpc("nvim_input", "b")
  wait(ui, [[return vim.api.nvim_get_current_line():sub(-1) == 'b']], "129th character is processed")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "long prefix retains its candidate")
  ui:rpc("nvim_input", "<CR>")
  t.wait_until(function()
    return ui:lua("return vim.api.nvim_get_current_line()") == 'local file = "./' .. filename
  end, 1000, "long filename is accepted without changing the path prefix")
end)

t:test("raw bytes in a background file cannot interrupt valid completion", function()
  local path = vim.fn.tempname() .. ".txt"
  vim.fn.writefile({ "\255broken alpha 中文变量" }, path)
  t:defer(function()
    vim.fn.delete(path)
  end)
  local ui = editor({ "" })
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
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "valid candidate remains available")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'alpha']], "valid candidate accepted")
  t.assert_eq("i", ui:lua([[return vim.api.nvim_get_mode().mode:sub(1, 1)]]), "editor remains in Insert mode")
  t.assert_eq(
    255,
    ui:lua([[return vim.api.nvim_buf_get_lines(cmp_bytes_bufnr, 0, 1, false)[1]:byte(1)]]),
    "background content is not rewritten"
  )
end)

t:test("an invalid UTF-8 query stays idle and completion resumes at the next word", function()
  local ui = editor({ "alpha", "\255" })
  ui:lua([[require('era.keystroke.cmp.policy').sources_for = function() return { 'buffer' } end]])
  ui:rpc("nvim_input", "Aa")
  wait(ui, [[return vim.api.nvim_get_current_line() == '\255a']], "invalid query typed")
  vim.wait(30)
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "invalid query has no menu")
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "invalid query does not raise a matcher error")
  ui:rpc("nvim_input", " al")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "next valid word completes")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_get_current_line() == '\255a alpha']], "only the valid word is replaced")
end)

t:test("persisted acceptance history survives a new LSP client instance", function()
  local completion = [[return function(_, callback)
    callback(nil, {
      { label = 'alpha', filterText = 'al', sortText = '1', kind = 6 },
      { label = 'alpine', filterText = 'al', sortText = '2', kind = 6 },
    })
  end]]
  local ui = editor({ "" })
  lsp_client(ui, completion)
  ui:rpc("nvim_input", "ial")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "initial candidates")
  ui:rpc("nvim_input", "<Tab>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'alpine']], "less preferred candidate preview")
  ui:rpc("nvim_input", "<CR>")
  wait(
    ui,
    [[return vim.api.nvim_get_current_line() == 'alpine' and not require('era.keystroke.cmp').is_menu_visible()]],
    "acceptance recorded"
  )
  local history = ui:lua([[return vim.json.encode(dot.context.frecency.completions:dump())]])

  local restarted = editor({ "" })
  restarted:lua(
    [[
    dot.context.frecency.completions = yoz.completion.new_history(vim.json.decode(...))
  ]],
    history
  )
  lsp_client(restarted, completion)
  restarted:lua([[vim.lsp.get_clients({ method = 'textDocument/completion' })[1].id = 9002]])
  restarted:rpc("nvim_input", "ial")
  wait(restarted, [[return require('era.keystroke.cmp').is_menu_visible()]], "candidates from restarted client")
  restarted:rpc("nvim_input", "<CR>")
  wait(
    restarted,
    [[return vim.api.nvim_get_current_line() == 'alpine' and not require('era.keystroke.cmp').is_menu_visible()]],
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
    local ui = editor({ "" })
    ui:lua([[_G.cmp_utf8_directory = ...]], directory)
    if mode == "insert" then
      ui:rpc("nvim_input", 'i"' .. directory .. "/a")
    else
      ui:rpc("nvim_input", ":edit " .. directory .. "/a")
    end
    wait(
      ui,
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
      "valid file candidate"
    )
    if mode == "cmdline" then
      ui:lua([[vim.api.nvim_select_popupmenu_item(cmp_valid_file_index, false, false, {})]])
      wait(ui, [[return vim.fn.cmdcomplete_info().selected == cmp_valid_file_index]], "valid native filename selected")
    end
    ui:rpc("nvim_input", "<C-y>")
    if mode == "insert" then
      wait(ui, [[return vim.api.nvim_get_current_line() == '"' .. cmp_utf8_directory .. '/alpha.txt']], "file accepted")
      t.assert_eq("i", ui:lua([[return vim.api.nvim_get_mode().mode:sub(1, 1)]]), "Insert mode is not interrupted")
    else
      wait(
        ui,
        [[return vim.fn.getcmdline() == 'edit ' .. cmp_utf8_directory .. '/alpha.txt']],
        "file argument accepted"
      )
      ui:rpc("nvim_input", "<Esc>")
    end
  end)
end

t:test("the snippet registry loads package data and native filename variables", function()
  local ui = editor({ "" })
  ui:lua(
    [[
    local root = ...
    vim.opt.runtimepath:prepend(root .. '/__test__/fixtures/era/keystroke/cmp/friendly-snippets')
    vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. '/stem.lua')
  ]],
    vim.uv.cwd()
  )
  ui:rpc("nvim_input", "izzcmpf")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "filetype snippets")
  ui:rpc("nvim_input", "<CR>")
  wait(
    ui,
    [[return vim.api.nvim_get_current_line() == "local stem = 'stem'" and vim.snippet.active()]],
    "nested snippet variable expansion"
  )
end)

t:run()
