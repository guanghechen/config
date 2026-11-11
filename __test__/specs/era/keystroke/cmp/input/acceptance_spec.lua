local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local t = harness.new()

local lsp_client = embedded.lsp_client

t:test("compound LSP acceptance replaces the full input instead of a suffix snippet", function()
  local ui = embedded.editor(t, { "" })
  ui:lua([[
    vim.api.nvim_set_option_value('filetype', 'html', { buf = 0 })
    require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp', 'snippets' } end
    require('era.keystroke.cmp.source.snippets').complete = function(context, callback)
      local Item = require('era.keystroke.cmp.item')
      callback({ items = { Item.new(context, 'snippets', {
        label = 'li', kind = 15, insertTextFormat = 2, insertText = '<li>$0</li>',
      }) }, incomplete = false })
    end
  ]])
  lsp_client(
    ui,
    [[return function(_, callback)
    local range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 9 } }
    callback(nil, { isIncomplete = true, items = {
      { label = 'div>ul>li', insertTextFormat = 2,
        textEdit = { range = range, newText = '<div><ul><li>$0</li></ul></div>' } },
      { label = 'link', insertTextFormat = 2,
        textEdit = { range = range, newText = '<div><ul><link href="$0"></ul></div>' } },
    } })
  end]]
  )
  ui:rpc("nvim_input", "idiv>ul>li")
  embedded.wait_menu_item(ui, "div>ul>li", "the full LSP result has arrived alongside the local snippet")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.api.nvim_get_current_line() == '<div><ul><li></li></ul></div>']],
    5000,
    "default acceptance expands the complete abbreviation"
  )
end)

t:test("accepting an invalid snippet preserves the prefix and additional edit targets", function()
  local ui = embedded.editor(t, { "-- keep", "pre" })
  lsp_client(
    ui,
    [[return function(_, callback)
    callback(nil, { { label = 'prefix', insertTextFormat = 2, insertText = 'hello$0world$0',
      additionalTextEdits = { { newText = 'IMPORT\n', range = {
        start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 },
      } } },
    } })
  end]]
  )
  ui:lua([[stl.reporter.warn = function() _G.cmp_invalid_snippet = true end]])
  ui:rpc("nvim_input", "A")
  ui:wait_lua([[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], 5000, "insert mode")
  ui:lua([[require('era.keystroke.cmp').show()]])
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "candidate menu")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return cmp_invalid_snippet == true]], 5000, "invalid snippet rejected")
  t.assert_eq("-- keep\npre", ui:lua([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]]))
  t.assert_eq(0, ui:lua([[return #cmp_commands]]), "no completion command ran")
end)

t:test("acceptance creates an undo boundary and records dot repeat", function()
  local ui = embedded.editor(t, { "alpha alpine", "", "" })
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 2, 0 })]])
  ui:rpc("nvim_input", "ial")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "completion menu")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'alpha']], 5000, "accepted text")
  ui:rpc("nvim_input", "<Esc>j0.")
  ui:wait_lua([[return vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == 'alpha']], 5000, "dot repeat")
  ui:rpc("nvim_input", "u")
  ui:wait_lua([[return vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == '']], 5000, "undo repeat")
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 2, 0 })]])
  ui:rpc("nvim_input", "u")
  ui:wait_lua([[return vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == 'al']], 5000, "undo accepted edit")
end)

for _, command in ipairs({ "editor.action.triggerSuggest", "editor.action.triggerParameterHints" }) do
  t:test("acceptance executes the native client command " .. command, function()
    local ui = embedded.editor(t, { "" })
    ui:lua([[_G.cmp_completion_command = ...]], command)
    lsp_client(
      ui,
      [[return function(_, callback)
        callback(nil, { { label = 'alpha', kind = 6, command = { title = 'continue', command = cmp_completion_command } } })
      end]]
    )
    ui:lua([[
      local client = vim.lsp.get_clients({ method = 'textDocument/completion' })[1]
      client.commands = {}
      client.exec_cmd = require('vim.lsp.client').exec_cmd
      client.server_capabilities.signatureHelpProvider = { triggerCharacters = { '(' } }
      local request = client.request
      client.request = function(self, method, params, callback, bufnr)
        if method == 'textDocument/signatureHelp' then
          cmp_requests[#cmp_requests + 1] = { method = method, params = params }
          callback(nil, { signatures = { { label = 'alpha(value)', parameters = { { label = 'value' } } } } })
          return true, #cmp_requests
        end
        return request(self, method, params, callback, bufnr)
      end
      vim.lsp.get_clients = function(filter)
        return filter and (filter.method == 'textDocument/completion' or filter.method == 'textDocument/signatureHelp')
          and { client } or {}
      end
      _G.cmp_command_notices = {}
      vim.notify = function(message) cmp_command_notices[#cmp_command_notices + 1] = message end
    ]])
    ui:rpc("nvim_input", "ial")
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "initial menu")
    ui:rpc("nvim_input", "<C-y>")
    ui:wait_lua([[return vim.api.nvim_get_current_line() == 'alpha']], 5000, "completion accepted")
    if command == "editor.action.triggerSuggest" then
      ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "command reopens completion")
    else
      ui:wait_lua(
        [[
        for _, winnr in ipairs(vim.api.nvim_list_wins()) do
          local bufnr = vim.api.nvim_win_get_buf(winnr)
          if vim.api.nvim_get_option_value('filetype', { buf = bufnr }) == 'cmp-signature' then return true end
        end
        return false
      ]],
        5000,
        "command opens parameter hints without a trigger character"
      )
    end
    t.assert_eq(0, ui:lua([[return #cmp_command_notices]]), "Neovim recognizes the client command")
    local request_count = ui:lua([[return #cmp_requests]])
    ui:lua([[
      local other = vim.api.nvim_create_buf(false, true)
      vim.lsp.get_client_by_id(9001):exec_cmd({ title = 'other buffer', command = cmp_completion_command }, { bufnr = other })
      vim.api.nvim_buf_delete(other, { force = true })
      vim.defer_fn(function() _G.cmp_foreign_command_settled = true end, 60)
    ]])
    ui:wait_lua([[return cmp_foreign_command_settled]], 5000, "other-buffer command settles")
    t.assert_true(
      ui:lua(
        [[
      for index = (...) + 1, #cmp_requests do
        if cmp_requests[index].method ~= 'completionItem/resolve' then return false end
      end
      return true
    ]],
        request_count
      ),
      "other-buffer command does not issue a current-buffer request"
    )
  end)
end

t:test("UTF-16 acceptance applies resolved imports and commands once", function()
  local ui = embedded.editor(t, { "-- imports", "" })
  lsp_client(
    ui,
    [[return function(params, callback)
    callback(nil, { { label = 'foobar', kind = 6,
      textEdit = { newText = 'foobar', range = { start = { line = 1, character = 3 }, ['end'] = params.position } } } })
  end]],
    [[return function(item)
    item.additionalTextEdits = { { newText = "local Foo = require('foo')\n", range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } } } }
    item.command = { title = 'done', command = 'fixture.done' }
    return item, 20
  end]]
  )
  ui:rpc("nvim_input", "i😀 fo")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "LSP candidate")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_buf_line_count(0) == 3]], 5000, "import applied")
  t.assert_same(
    { "local Foo = require('foo')", "-- imports", "😀 foobar" },
    ui:lua([[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]),
    "complete edit"
  )
  t.assert_eq(1, ui:lua([[return #cmp_commands]]), "command executed once")
  t.assert_eq(3, ui:lua("return vim.api.nvim_win_get_cursor(0)[1]"), "cursor follows import")
  ui:rpc("nvim_input", "<Esc>u")
  ui:wait_lua([[return vim.api.nvim_buf_line_count(0) == 2]], 5000, "undo entire completion")
  t.assert_eq("😀 fo", ui:lua("return vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]"), "typed prefix restored")
end)

t:test("UTF-16 boundary insertions track the completion after further typing", function()
  local ui = embedded.editor(t, { "" })
  lsp_client(
    ui,
    [[return function(params, callback)
      local start = { line = 0, character = 3 }
      callback(nil, { { label = 'foobar', kind = 6,
        textEdit = { newText = 'foobar', range = { start = start, ['end'] = params.position } },
        additionalTextEdits = {
          { newText = 'prefix ', range = { start = start, ['end'] = start } },
          { newText = ' suffix', range = { start = params.position, ['end'] = params.position } },
        },
      } })
    end]]
  )
  ui:rpc("nvim_input", "i😀 f")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "original candidate")
  ui:rpc("nvim_input", "o")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == '😀 fo']], 5000, "continued input")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.api.nvim_get_current_line() == '😀 prefix foobar suffix']],
    5000,
    "both boundary edits applied"
  )
  t.assert_eq(#"😀 prefix foobar", ui:lua("return vim.api.nvim_win_get_cursor(0)[2]"), "cursor precedes suffix")
  ui:rpc("nvim_input", "<Esc>u")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == '😀 fo']], 5000, "one undo restores the continued prefix")
end)

t:test("typing during resolve prevents a late edit and command", function()
  local ui = embedded.editor(t, { "" })
  lsp_client(
    ui,
    [[return function(_, callback) callback(nil, { { label = 'foobar', kind = 6 } }) end]],
    [[return function(item)
    item.command = { title = 'late', command = 'fixture.late' }
    return item, 80
  end]]
  )
  ui:rpc("nvim_input", "ifo")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "LSP menu")
  ui:rpc("nvim_input", "<C-y>x")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'fox']], 5000, "new user input")
  vim.wait(150)
  t.assert_eq("fox", ui:lua([[return vim.api.nvim_get_current_line()]]), "late resolve ignored")
  t.assert_eq(0, ui:lua([[return #cmp_commands]]), "late command ignored")
end)

for _, target in ipairs({ "background", "current" }) do
  t:test(target .. " buffer edits respect pending acceptance ownership", function()
    local ui = embedded.editor(t, { "" })
    ui:lua([[
      _G.cmp_background_bufnr = vim.api.nvim_get_current_buf()
      vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = cmp_background_bufnr })
      require('era.keystroke.cmp.policy').sources_for = function(context, manual)
        return (manual or context.trigger == 'typing') and { 'lsp' } or {}
      end
    ]])
    ui:rpc("nvim_input", "i")
    ui:wait_lua([[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], 5000, "background buffer attached")
    local version = ui:lua([[return require('era.keystroke.cmp.context').capture().buffer_version]])
    ui:rpc("nvim_input", "<Esc>")
    ui:wait_lua([[return vim.api.nvim_get_mode().mode == 'n']], 5000, "leave background buffer")
    ui:lua([[
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
      vim.api.nvim_set_option_value('filetype', 'lua', { buf = 0 })
    ]])
    lsp_client(
      ui,
      [[return function(_, callback) callback(nil, { { label = 'foobar', kind = 6 } }) end]],
      [[return function(item)
        item.command = { title = 'accepted', command = 'fixture.accepted' }
        return item, 80
      end]]
    )
    ui:rpc("nvim_input", "ifo")
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "current buffer candidate")
    embedded.accept_resolving(ui)
    local cancelled = ui:lua(
      [[
      local target = ...
      local cancels = 0
      vim.lsp.get_client_by_id(9001).cancel_request = function(_, id)
        if cmp_requests[id].method == 'completionItem/resolve' then cancels = cancels + 1 end
      end
      local bufnr = target == 'background' and cmp_background_bufnr or vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'edited' })
      return cancels
    ]],
      target
    )
    local current = target == "current"
    t.assert_eq(current and 1 or 0, cancelled, "only edits to the owning buffer cancel acceptance")
    -- A cancelled acceptance must not apply within the window; a kept one applies its delayed resolve.
    vim.wait(150)
    local expected = current and "edited" or "foobar"
    ui:wait_until(function()
      return ui:lua([[return vim.api.nvim_get_current_line()]]) == expected
    end, 5000, "resolved text")
    t.assert_eq(current and 0 or 1, ui:lua([[return #cmp_commands]]), "resolved command ownership")
    if not current then
      ui:rpc("nvim_input", "<Esc>")
      ui:wait_lua([[return vim.api.nvim_get_mode().mode == 'n']], 5000, "leave completed buffer")
      ui:lua([[vim.api.nvim_set_current_buf(cmp_background_bufnr)]])
      ui:rpc("nvim_input", "i")
      ui:wait_lua([[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], 5000, "return to background buffer")
      t.assert_true(
        version ~= ui:lua([[return require('era.keystroke.cmp.context').capture().buffer_version]]),
        "background edit still invalidates its own context"
      )
    end
  end)
end

t:test("function completion records cursor placement inside brackets", function()
  local ui = embedded.editor(t, { "", "" })
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 1, 0 })]])
  lsp_client(ui, [[return function(_, callback) callback(nil, { { label = 'foobar', kind = 3 } }) end]])
  ui:rpc("nvim_input", "ifo")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "function menu")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.api.nvim_get_current_line() == 'foobar()' and vim.api.nvim_win_get_cursor(0)[2] == 7]],
    5000,
    "bracket cursor"
  )
  ui:rpc("nvim_input", "42<Esc>j0.")
  ui:wait_lua(
    [[return vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == 'foobar(42)']],
    5000,
    "repeat bracket placement"
  )
end)

t:test("semantic brackets follow language delimiters and context exclusions after acceptance", function()
  for _, case in ipairs({
    { filetype = "lua", line = "fo", text = "foobar()", col = 7, allowed = true },
    { filetype = "sh", line = "fo", text = "foobar ", col = 7, allowed = true },
    { filetype = "python", line = "from pkg import fo", text = "from pkg import foobar", col = 22 },
    { filetype = "typescript", line = "import { fo", text = "import { foobar", col = 15 },
    { filetype = "rust", line = "fo", text = "foobar", col = 6 },
    { filetype = "java", line = "fo", text = "foobar", col = 6 },
  }) do
    local ui = embedded.editor(t, { case.line })
    lsp_client(ui, [[return function(_, callback) callback(nil, { { label = 'foobar', kind = 6 } }) end]])
    ui:lua(
      [[
      vim.api.nvim_set_option_value('filetype', ..., { buf = 0 })
      require('era.keystroke.cmp.policy').sources_for = function(_, manual) return manual and { 'lsp' } or {} end
      vim.lsp.get_client_by_id(9001).server_capabilities.semanticTokensProvider = {
        full = true, legend = { tokenTypes = { 'function' }, tokenModifiers = {} },
      }
      _G.cmp_token_checks = 0
      _G.cmp_tokens_ready = false
      vim.lsp.semantic_tokens.get_at_pos = function()
        cmp_token_checks = cmp_token_checks + 1
        return cmp_tokens_ready and { { client_id = 9001, type = 'function' } } or nil
      end
      vim.lsp.semantic_tokens.force_refresh = function(bufnr)
        vim.schedule(function()
          cmp_tokens_ready = true
          vim.api.nvim_exec_autocmds('LspTokenUpdate', { buffer = bufnr })
        end)
      end
    ]],
      case.filetype
    )
    ui:rpc("nvim_input", "A")
    ui:wait_lua([[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], 5000, "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, case.filetype .. " semantic candidate")
    ui:rpc("nvim_input", "<C-y>")
    ui:wait_until(function()
      return ui:lua([[return vim.api.nvim_get_current_line()]]) == case.text
    end, 5000, case.filetype .. " accepted text")
    ui:lua([[
      vim.schedule(function()
        vim.schedule(function() _G.cmp_accept_drained = true end)
      end)
    ]])
    ui:wait_lua([[return cmp_accept_drained == true]], 5000, "acceptance callbacks drained")
    t.assert_eq(case.col, ui:lua("return vim.api.nvim_win_get_cursor(0)[2]"), case.filetype .. " cursor")
    if case.allowed then
      t.assert_true(ui:lua([[return cmp_token_checks >= 2]]), "delayed semantic tokens resolved")
    else
      ui:lua([[
        local context = assert(require('era.keystroke.cmp.context').capture())
        local cancel = require('era.keystroke.cmp.brackets').watch(context, 9001, function()
          error('excluded context must not insert semantic brackets')
        end)
        cancel()
      ]])
      t.assert_eq(0, ui:lua([[return cmp_token_checks]]), case.filetype .. " excludes semantic resolution")
    end
    t.assert_eq(case.text, ui:lua([[return vim.api.nvim_get_current_line()]]), case.filetype .. " final text")
  end
end)

for _, action in ipairs({ "(", "<C-e>", "<CR>" }) do
  t:test("snippet preview separates display labels from insertion before " .. action, function()
    local ui = embedded.editor(t, { "" })
    lsp_client(
      ui,
      [[return function(_, callback)
      callback(nil, {{label='normalize(value)',kind=3,insertTextFormat=2,insertText='normalize(${1:value})$0'}})
    end]]
    )
    ui:rpc("nvim_input", "inor")
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "function candidate")
    t.assert_eq(
      "normalize(value)",
      ui:lua([[return vim.fn.complete_info({'items'}).items[1].abbr]]),
      "display retains the signature"
    )
    ui:rpc("nvim_input", "<Down><Down>")
    ui:wait_lua(
      [[return vim.api.nvim_get_current_line() == 'normalize']],
      5000,
      "preview inserts only the function name"
    )
    ui:rpc("nvim_input", action)
    local expected = action == "(" and "normalize(" or action == "<C-e>" and "nor" or "normalize(value)"
    ui:wait_until(function()
      return ui:lua([[return vim.api.nvim_get_current_line()]]) == expected
    end, 5000, "preview follow-up " .. action)
    t.assert_eq(action == "<CR>", ui:lua([[return vim.snippet.active()]]), "only acceptance starts a snippet")
  end)
end

t:test("LSP snippets expand and Tab moves through the native snippet session", function()
  local ui = embedded.editor(t, { "" })
  lsp_client(
    ui,
    [[return function(_, callback)
    callback(nil, { { label = 'function', kind = 15, insertTextFormat = 2, insertText = 'call(${1:value})$0' } })
  end]]
  )
  ui:rpc("nvim_input", "ifu")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "snippet menu")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.snippet.active() and vim.api.nvim_get_current_line() == 'call(value)']],
    5000,
    "snippet expansion"
  )
  ui:rpc("nvim_input", "argument")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'call(argument)']], 5000, "placeholder edit")
  ui:rpc("nvim_input", "<Tab>")
  ui:wait_lua([[return vim.api.nvim_win_get_cursor(0)[2] == #'call(argument)']], 5000, "final tabstop")
end)

for _, example in ipairs({
  {
    name = "snippet documentation expands datetime variables before navigation",
    body = "$CURRENT_YEAR-$CURRENT_MONTH-$CURRENT_DATE $CURRENT_HOUR:$CURRENT_MINUTE$0",
    expected = "2026-10-08 16:03",
  },
  {
    name = "snippet documentation shares dynamic values with preview and acceptance",
    body = "${RANDOM}:${1:name}$0",
    expected = "123456:name",
    preview = true,
  },
}) do
  t:test(example.name, function()
    local ui = embedded.editor(t, { "" })
    ui:lua(
      [[
      local example = ...
      _G.cmp_documentation_expected = example.expected
      _G.cmp_random_reads = 0
      local dates = { ['%Y'] = '2026', ['%m'] = '10', ['%d'] = '08', ['%H'] = '16', ['%M'] = '03' }
      os.date = function(format) return assert(dates[format]) end
      math.random = function()
        cmp_random_reads = cmp_random_reads + 1
        return 123455 + cmp_random_reads
      end
      require('era.keystroke.cmp.policy').sources_for = function() return { 'snippets' } end
      require('era.keystroke.cmp.source.snippets').complete = function(context, callback)
        local Item = require('era.keystroke.cmp.item')
        callback({ items = { Item.new(context, 'snippets', {
          label = 'zzcmppreview', kind = 15, insertTextFormat = 2,
          textEdit = Item.text_edit(context, context.start_col, example.body),
          documentation = { kind = 'markdown', value = 'Snippet description.' },
        }) }, incomplete = false })
      end
    ]],
      example
    )
    ui:rpc("nvim_input", "izzcmppreview")
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "snippet menu")
    if example.preview then
      ui:rpc("nvim_input", "<Tab><Tab>")
      ui:wait_lua([[return vim.fn.complete_info({ 'selected' }).selected == 0]], 5000, "native snippet selected")
      t.assert_eq(
        "zzcmppreview",
        ui:lua([[return vim.api.nvim_get_current_line()]]),
        "native inline preview uses the label"
      )
    end
    ui:wait_lua(
      [[
      for _, winnr in ipairs(vim.api.nvim_list_wins()) do
        local bufnr = vim.api.nvim_win_get_buf(winnr)
        if vim.api.nvim_get_option_value('filetype', { buf = bufnr }) == 'cmp-documentation' then
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
          return vim.list_contains(lines, cmp_documentation_expected)
            and vim.list_contains(lines, 'Snippet description.')
        end
      end
      return false
    ]],
      5000,
      "documentation contains the expanded snippet and its description"
    )
    if not example.preview then
      t.assert_eq(
        "zzcmppreview",
        ui:lua([[return vim.api.nvim_get_current_line()]]),
        "documentation does not insert text"
      )
    end
    ui:rpc("nvim_input", "<C-y>")
    ui:wait_lua(
      [[return vim.api.nvim_get_current_line() == cmp_documentation_expected]],
      5000,
      "accepted text matches documentation"
    )
    t.assert_eq(example.preview and 1 or 0, ui:lua([[return cmp_random_reads]]), "dynamic values are evaluated once")
  end)
end

t:test("resolved acceptance applies before input queued behind Enter", function()
  local ui = embedded.editor(t, { "" })
  lsp_client(
    ui,
    [[return function(_,callback)
    callback(nil, {{label='foobar',kind=6,documentation='Resolved completion.',
      command={title='accepted',command='fixture.accepted'}}})
  end]]
  )
  ui:rpc("nvim_input", "ifo")
  ui:wait_lua(
    [[
    for _,winnr in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_get_option_value('filetype',{buf=vim.api.nvim_win_get_buf(winnr)})=='cmp-documentation' then
        return true
      end
    end
    return false
  ]],
    5000,
    "completion has resolved for documentation"
  )
  ui:rpc("nvim_input", "<C-y>x")
  ui:wait_lua([[return vim.api.nvim_get_current_line()=='foobarx']], 5000, "completion precedes queued input")
  t.assert_eq(1, ui:lua([[return #cmp_commands]]), "completion command executes once")
end)

for _, accept in ipairs({ true, false }) do
  t:test(
    accept and "native API acceptance applies full LSP ranges after prefix preview"
      or "native API cancellation never applies LSP imports or commands",
    function()
      local ui = embedded.editor(t, { "-- imports", "foTAIL" })
      ui:lua([[
      vim.api.nvim_win_set_cursor(0,{2,2})
      require('era.keystroke.cmp.policy').sources_for=function() return {'lsp'} end
    ]])
      lsp_client(
        ui,
        [[return function(_,callback)
      callback(nil, {{label='foobar',kind=6,textEdit={newText='foobar',range={start={line=1,character=0},['end']={line=1,character=6}}},
        additionalTextEdits={{newText='IMPORT\n',range={start={line=0,character=0},['end']={line=0,character=0}}}},
        command={title='accepted',command='fixture.accepted'}}})
    end]]
      )
      ui:rpc("nvim_input", "i")
      ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "native menu")
      ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,false,{})]])
      ui:wait_lua(
        [[return vim.api.nvim_get_current_line()=='foobarTAIL']],
        5000,
        "native preview replaces only the prefix"
      )
      ui:lua([[vim.api.nvim_select_popupmenu_item(...,true,true,{})]], accept and 0 or -1)
      if accept then
        ui:wait_lua(
          [[return vim.deep_equal({'IMPORT','-- imports','foobar'},vim.api.nvim_buf_get_lines(0,0,-1,false))]],
          5000,
          "full LSP range replaces the suffix at acceptance"
        )
        t.assert_eq(1, ui:lua([[return #cmp_commands]]), "command executes once")
      else
        ui:wait_lua(
          [[return vim.fn.pumvisible()==0 and vim.api.nvim_get_current_line()=='foTAIL']],
          5000,
          "native cancellation restores the original input"
        )
        t.assert_eq(2, ui:lua([[return vim.api.nvim_buf_line_count(0)]]), "no import applied")
        t.assert_eq(0, ui:lua([[return #cmp_commands]]), "no command executed")
      end
    end
  )
end

t:test("Unicode completion records character-safe dot repeat", function()
  local ui = embedded.editor(t, { "中文变量", "", "" })
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 2, 0 })]])
  ui:rpc("nvim_input", "i中变")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "Unicode candidate")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == '中文变量']], 5000, "Unicode acceptance")
  ui:rpc("nvim_input", "<Esc>j0.")
  ui:wait_lua([[return vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == '中文变量']], 5000, "Unicode repeat")
end)

t:test("multiline plain-text completions retain their cursor and undo semantics", function()
  local ui = embedded.editor(t, { "" })
  lsp_client(
    ui,
    [[return function(_, callback)
    callback(nil, { { label = 'fragment', kind = 1, insertText = 'first\nsecond' } })
  end]]
  )
  ui:rpc("nvim_input", "ifr")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "multiline candidate")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_buf_line_count(0) == 2]], 5000, "multiline edit")
  t.assert_same({ "first", "second" }, ui:lua([[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), "inserted lines")
  t.assert_same({ 2, 6 }, ui:lua([[return vim.api.nvim_win_get_cursor(0)]]), "cursor after inserted text")
  ui:rpc("nvim_input", "<Esc>u")
  ui:wait_lua(
    [[return vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_get_current_line() == 'fr']],
    5000,
    "undo multiline edit"
  )
end)

t:run()
