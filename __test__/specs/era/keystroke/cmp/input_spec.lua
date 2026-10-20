local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")
local t = harness.new()

---@param lines                         string[]
---@return __test__.support.UI
local function editor(lines)
  local ui = UI.new()
  t:defer(function()
    ui:close()
  end)
  ui:start({})
  ui:lua(
    [[
    local lines = ...
    require('__test__.support.cmp.runtime').setup()
    vim.api.nvim_set_option_value('filetype', 'lua', { buf = 0 })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { #lines, 0 })
    require('era.keystroke.cmp').setup()
  ]],
    lines
  )
  t:defer(function()
    t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
  end)
  return ui
end

---@param ui                            __test__.support.UI
---@param complete                      string
---@param resolve                       ?string
---@return nil
local function lsp_client(ui, complete, resolve)
  ui:lua(
    [[
    local complete_code, resolve_code = ...
    local completion = assert(loadstring(complete_code))()
    local resolve = resolve_code and assert(loadstring(resolve_code))() or function(item) return item end
    _G.cmp_requests = {}
    _G.cmp_commands = {}
    local client = {
      id = 9001, name = 'completion-fixture', offset_encoding = 'utf-16',
      server_capabilities = { completionProvider = { resolveProvider = true, triggerCharacters = { '.' } } },
      cancel_request = function() end,
      exec_cmd = function(_, command) cmp_commands[#cmp_commands + 1] = command end,
    }
    function client:request(method, params, callback, bufnr)
      cmp_requests[#cmp_requests + 1] = { method = method, params = params, bufnr = bufnr }
      local id = #cmp_requests
      if method == 'textDocument/completion' then
        completion(params, callback)
      elseif method == 'completionItem/resolve' then
        local result, delay = resolve(params)
        vim.defer_fn(function() callback(nil, result) end, delay or 0)
      end
      return true, id
    end
    vim.lsp.get_clients = function(filter)
      return filter and filter.method == 'textDocument/completion' and { client } or {}
    end
    vim.lsp.get_client_by_id = function(id) return id == client.id and client or nil end
  ]],
    complete,
    resolve
  )
end

---@param ui                            __test__.support.UI
---@param code                          string
---@param message                       string
---@return nil
local function wait(ui, code, message)
  ui:wait_until(function()
    return ui:lua(code)
  end, 3000, message)
end

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

t:test("compound LSP acceptance replaces the full input instead of a suffix snippet", function()
  local ui = editor({ "" })
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
  wait(
    ui,
    [[
      for _, item in ipairs(vim.fn.complete_info({ 'items' }).items) do
        if item.abbr:find('div>ul>li', 1, true) then return true end
      end
      return false
    ]],
    "the full LSP result has arrived alongside the local snippet"
  )
  ui:rpc("nvim_input", "<CR>")
  wait(
    ui,
    [[return vim.api.nvim_get_current_line() == '<div><ul><li></li></ul></div>']],
    "default acceptance expands the complete abbreviation"
  )
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

t:test("Tab fallback preserves queued input and existing mappings", function()
  for _, mapped in ipairs({ false, true }) do
    local ui = editor({ "" })
    ui:lua(
      [[
      local mapped = ...
      vim.api.nvim_set_option_value('expandtab', false, { buf = 0 })
      require('era.keystroke.cmp.policy').sources_for = function() return {} end
      vim.lsp.inline_completion.get = function() return false end
      if mapped then vim.keymap.set('i', '<Tab>', function() return 'mapped' end, { buffer = 0, expr = true }) end
    ]],
      mapped
    )
    ui:rpc("nvim_input", "i<Tab>x")
    local expected = mapped and "mappedx" or "\tx"
    t.wait_until(function()
      return ui:lua("return vim.api.nvim_get_current_line()") == expected
    end, 1000, "Tab precedes the next queued character")
  end
end)

t:test("disabled completion preserves native keys and existing mappings", function()
  for _, example in ipairs({
    { key = "<C-j>", keys = "iabc<C-j>def", native = { "abc", "def" }, mapped = { "abcmappeddef" } },
    { key = "<C-k>", keys = "i<C-k>ae", native = { "æ" }, mapped = { "mappedae" } },
  }) do
    for _, mapped in ipairs({ false, true }) do
      local ui = editor({ "" })
      ui:lua(
        [[
        local key, mapped = ...
        vim.api.nvim_set_option_value('filetype', 'gitcommit', { buf = 0 })
        if mapped then
          vim.keymap.set('i', key, function() return 'mapped' end, { buffer = 0, expr = true })
        end
      ]],
        example.key,
        mapped
      )
      ui:rpc("nvim_input", example.keys)
      local expected = mapped and example.mapped or example.native
      t.wait_until(function()
        return vim.deep_equal(expected, ui:lua("return vim.api.nvim_buf_get_lines(0, 0, -1, false)"))
      end, 1000, example.key .. " preserves queued input")
      t.assert_false(ui:lua("return require('era.keystroke.cmp').is_menu_visible()"))
    end
  end
end)

t:test("accepting an invalid snippet preserves the prefix and additional edit targets", function()
  local ui = editor({ "-- keep", "pre" })
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
  wait(ui, [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], "insert mode")
  ui:lua([[require('era.keystroke.cmp').show()]])
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "candidate menu")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return cmp_invalid_snippet == true]], "invalid snippet rejected")
  t.assert_eq("-- keep\npre", ui:lua([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]]))
  t.assert_eq(0, ui:lua([[return #cmp_commands]]), "no completion command ran")
end)

---@param ui                            __test__.support.UI
---@return string
local function reload_target(ui)
  local path = vim.fn.tempname() .. ".lua"
  vim.fn.writefile({ "old", "fo" }, path)
  t:defer(function()
    vim.fn.delete(path)
  end)
  ui:lua(
    [[
    vim.cmd.edit({ args = { ... }, bang = true })
    vim.api.nvim_set_option_value('autoread', true, { buf = 0 })
    vim.api.nvim_set_option_value('filetype', 'lua', { buf = 0 })
    vim.api.nvim_win_set_cursor(0, { 2, 1 })
    require('era.keystroke.cmp.policy').sources_for = function(context, manual)
      return (manual or context.trigger == 'typing') and { 'lsp' } or {}
    end
    _G.cmp_reload_fallbacks = 0
    vim.keymap.set('i', '<C-j>', function() cmp_reload_fallbacks = cmp_reload_fallbacks + 1 end, { buffer = 0 })
  ]],
    path
  )
  return path
end

for _, command in ipairs({ "checktime", "edit" }) do
  t:test(command .. " cancels a pending acceptance and permits a fresh one", function()
    local ui = editor({ "" })
    local path = reload_target(ui)
    lsp_client(
      ui,
      [[return function(_, callback)
      local length = #vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      callback(nil, { items = { { label = 'foobar', kind = 6, additionalTextEdits = {
        { range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = length } }, newText = 'IMPORT' },
      } } }, isIncomplete = false })
    end]],
      [[return function(item) return item, 60 end]]
    )
    ui:rpc("nvim_input", "A")
    wait(ui, [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "original candidate")
    ui:lua([[
      _G.cmp_reload_resolve_cancels = 0
      vim.lsp.get_client_by_id(9001).cancel_request = function(_, id)
        if cmp_requests[id].method == 'completionItem/resolve' then
          cmp_reload_resolve_cancels = cmp_reload_resolve_cancels + 1
        end
      end
    ]])
    ui:lua([[
      _G.cmp_before_accept_request = #cmp_requests
      assert(require('era.keystroke.cmp').accept())
    ]])
    wait(
      ui,
      [[
      for index = cmp_before_accept_request + 1, #cmp_requests do
        if cmp_requests[index].method == 'completionItem/resolve' then return true end
      end
      return false
    ]],
      "native acceptance reached resolve"
    )
    ui:lua([[_G.cmp_reload_resolve_cancels = 0]])
    vim.fn.writefile({ "new content", "fo" }, path)
    t.assert_eq(
      1,
      ui:lua(
        [[
      local command = ...
      if command == 'checktime' then vim.cmd.checktime() else vim.cmd.edit({ bang = true }) end
      return cmp_reload_resolve_cancels
    ]],
        command
      ),
      "old acceptance request cancelled during reload"
    )
    ui:lua([[require('era.keystroke.cmp').show()]])
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "fresh candidate")
    ui:rpc("nvim_input", "<CR>")
    wait(
      ui,
      [[return vim.deep_equal({ 'IMPORT', 'foobar' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))]],
      "only the newer resolved edit applies"
    )
  end)

  t:test(command .. " invalidates cached edits and preserves buffer tracking and mappings", function()
    local ui = editor({ "" })
    local path = reload_target(ui)
    lsp_client(
      ui,
      [[return function(_, callback)
      local length = #vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      callback(nil, { items = { { label = 'foobar', kind = 6, additionalTextEdits = {
        { range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = length } }, newText = 'IMPORT' },
      } } }, isIncomplete = false })
    end]]
    )
    ui:rpc("nvim_input", "A")
    wait(ui, [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "original completion")
    local original = ui:lua([[return require('era.keystroke.cmp.context').capture()]])
    vim.fn.writefile({ "new content", "fo" }, path)
    t.assert_eq(
      false,
      ui:lua(
        [[
      local command = ...
      if command == 'checktime' then vim.cmd.checktime() else vim.cmd.edit({ bang = true }) end
      return require('era.keystroke.cmp').accept()
    ]],
        command
      ),
      "old completion cannot be accepted during reload cleanup"
    )
    t.assert_true(
      ui:lua([[return vim.deep_equal({ 'new content', 'fo' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))]]),
      "reloaded text intact"
    )
    local reloaded = ui:lua([[return require('era.keystroke.cmp.context').capture()]])
    t.assert_eq(original.bufnr, reloaded.bufnr, "same buffer reloaded")
    t.assert_true(original.buffer_version ~= reloaded.buffer_version, "old version is not reused")
    ui:lua([[vim.api.nvim_win_set_cursor(0, { 2, 2 })]])
    ui:rpc("nvim_input", "o")
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "completion after reload")
    t.assert_eq(
      2,
      ui:lua([[
      local count = 0
      for _, request in ipairs(cmp_requests) do if request.method == 'textDocument/completion' then count = count + 1 end end
      return count
    ]]),
      "typing cannot reuse the pre-reload LSP cache"
    )
    t.assert_true(
      ui:lua([[
      local Context = require('era.keystroke.cmp.context')
      local version = Context.capture().buffer_version
      vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'again' })
      return version ~= Context.capture().buffer_version
    ]]),
      "out-of-query edits remain observed after reload"
    )
    t.assert_eq(
      false,
      ui:lua([[return require('era.keystroke.cmp').accept()]]),
      "subsequent external edit invalidates candidates"
    )
    ui:rpc("nvim_input", "<C-j>")
    wait(ui, [[return cmp_reload_fallbacks == 1]], "buffer-local mapping fallback retained")
    ui:lua([[require('era.keystroke.cmp').show()]])
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "fresh candidate")
    ui:rpc("nvim_input", "<CR>")
    wait(
      ui,
      [[return vim.deep_equal({ 'IMPORT', 'foobar' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))]],
      "fresh edit uses the current coordinates"
    )
  end)

  t:test(command .. " rejects a completion response delivered after reloading the same query", function()
    local ui = editor({ "" })
    local path = reload_target(ui)
    ui:lua([[_G.cmp_reload_replies = {}]])
    lsp_client(
      ui,
      [[return function(_, callback)
      local length = #vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      cmp_reload_replies[#cmp_reload_replies + 1] = function()
        callback(nil, { items = { { label = 'foobar', kind = 6, additionalTextEdits = {
          { range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = length } }, newText = 'IMPORT' },
        } } }, isIncomplete = false })
      end
    end]]
    )
    ui:rpc("nvim_input", "A")
    wait(ui, [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    wait(ui, [[return #cmp_reload_replies == 1]], "pending original request")
    vim.fn.writefile({ "new content", "fo" }, path)
    ui:lua(
      [[
      local command = ...
      if command == 'checktime' then vim.cmd.checktime() else vim.cmd.edit({ bang = true }) end
      cmp_reload_replies[1]()
    ]],
      command
    )
    vim.wait(30)
    t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "late response stays hidden")
    ui:lua([[require('era.keystroke.cmp').show()]])
    wait(ui, [[return #cmp_reload_replies == 2]], "new request")
    ui:lua([[cmp_reload_replies[2]()]])
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "new response")
    ui:rpc("nvim_input", "<CR>")
    wait(
      ui,
      [[return vim.deep_equal({ 'IMPORT', 'foobar' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))]],
      "new response uses reloaded coordinates"
    )
  end)
end

t:test("selection previews and cancellation restores only the completion edit", function()
  local ui = editor({ "alpha alpine", "" })
  ui:rpc("nvim_input", "ial")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "completion menu")
  t.assert_eq("al", ui:lua([[return vim.api.nvim_get_current_line()]]), "preselection does not edit")
  ui:rpc("nvim_input", "<Tab>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'alpine']], "selection preview")
  ui:lua([[require('era.keystroke.cmp').cancel()]])
  wait(ui, [[return vim.api.nvim_get_current_line() == 'al']], "native cancellation restores input")
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "menu closes")
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

t:test("typing after a preview retains the selected text", function()
  local ui = editor({ "alpha alpine", "" })
  ui:rpc("nvim_input", "ial")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "completion menu")
  ui:rpc("nvim_input", "<Tab>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'alpine']], "preview")
  ui:rpc("nvim_input", "x")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'alpinex']], "typed suffix")
  ui:lua([[require('era.keystroke.cmp').cancel()]])
  t.assert_eq("alpinex", ui:lua([[return vim.api.nvim_get_current_line()]]), "user input survives cancellation")
end)

t:test("acceptance creates an undo boundary and records dot repeat", function()
  local ui = editor({ "alpha alpine", "", "" })
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 2, 0 })]])
  ui:rpc("nvim_input", "ial")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "completion menu")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'alpha']], "accepted text")
  ui:rpc("nvim_input", "<Esc>j0.")
  wait(ui, [[return vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == 'alpha']], "dot repeat")
  ui:rpc("nvim_input", "u")
  wait(ui, [[return vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == '']], "undo repeat")
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 2, 0 })]])
  ui:rpc("nvim_input", "u")
  wait(ui, [[return vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == 'al']], "undo accepted edit")
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

for _, independent in ipairs({ false, true }) do
  t:test(
    independent and "late LSP candidates preserve an independent source selection"
      or "late primary results remove an ineligible fallback preview",
    function()
      local ui = editor({ "alpha alpine", "" })
      if independent then
        ui:lua([[
      require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp', 'snippets' } end
      require('era.keystroke.cmp.source.snippets').complete = function(context, callback)
        local Item = require('era.keystroke.cmp.item')
        callback({ items = {
          assert(Item.new(context, 'snippets', { label = 'alpha', sortText = '1', kind = 6 })),
          assert(Item.new(context, 'snippets', { label = 'alpine', sortText = '2', kind = 6 })),
        }, incomplete = false })
      end
    ]])
      end
      lsp_client(
        ui,
        [[return function(_, callback)
    _G.release_late_completion = function()
      callback(nil, { { label = 'albatross', kind = 6 } })
    end
  end]]
      )
      ui:rpc("nvim_input", "ial")
      wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "buffer candidates")
      ui:rpc("nvim_input", "<Tab>")
      wait(ui, [[return vim.api.nvim_get_current_line() == 'alpine']], "explicit selection")
      ui:lua([[_G.release_late_completion()]])
      wait(
        ui,
        [[
    for _, item in ipairs(vim.fn.complete_info({ 'items' }).items) do
      if item.abbr:find('albatross', 1, true) then return true end
    end
    return false
  ]],
        "late LSP response rendered"
      )
      wait(
        ui,
        independent and [[return vim.api.nvim_get_current_line() == 'alpine']]
          or [[return vim.api.nvim_get_current_line() == 'al']],
        "preview follows candidate eligibility"
      )
      ui:rpc("nvim_input", "<CR>")
      -- This fixture's independent sources also opt into the accept trigger and open a fresh list.
      wait(
        ui,
        independent and [[return #vim.fn.complete_info({'items'}).items == 1]]
          or [[return vim.api.nvim_get_current_line() == 'albatross']],
        "acceptance completes and any fresh list uses the accepted input"
      )
      t.assert_true(
        vim.wait(3000, function()
          return ui:lua([[return vim.api.nvim_get_current_line()]]) == (independent and "alpine" or "albatross")
        end, 5),
        "acceptance uses an eligible item"
      )
    end
  )
end

t:test("incomplete LSP refresh keeps compatible candidates until the new response arrives", function()
  local ui = editor({ "" })
  ui:lua([[require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp' } end]])
  lsp_client(
    ui,
    [[return function(_, callback)
    if _G.first_response then
      _G.release_response = function()
        callback(nil, { isIncomplete = true, items = { { label = 'albatross', kind = 6 } } })
      end
    else
      _G.first_response = true
      callback(nil, { isIncomplete = true, items = { { label = 'alpha', kind = 6 } } })
    end
  end]]
  )
  ui:rpc("nvim_input", "ia")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "initial LSP candidates")
  ui:rpc("nvim_input", "l")
  wait(ui, [[return _G.release_response ~= nil]], "incomplete refresh requested")
  t.assert_true(
    ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]),
    "old compatible menu remains visible"
  )
  ui:lua([[_G.release_response()]])
  wait(
    ui,
    [[
    for _, item in ipairs(vim.fn.complete_info({ 'items' }).items) do
      if item.abbr:find('albatross', 1, true) then return true end
    end
    return false
  ]],
    "fresh candidates replace the previous snapshot"
  )
end)

t:test("typing and native backspace share a pending LSP request while Escape still cancels it", function()
  local ui = editor({ "" })
  ui:lua([[
    require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp' } end
    local Session = require('era.keystroke.cmp.session')
    local new = Session.new
    Session.new = function(props) _G.cmp_queue_session = new(props); return cmp_queue_session end
  ]])
  lsp_client(
    ui,
    [[
    _G.cmp_queue_requests = {}
    return function(params, callback)
      local request = { id = #cmp_requests, params = params, callback = callback }
      cmp_queue_requests[#cmp_queue_requests + 1] = request
      if #cmp_queue_requests == 1 then
        request.settled = true
        callback(nil, { items = { { label = 'alpha', kind = 6 } }, isIncomplete = true })
      end
    end
  ]]
  )
  ui:lua([[
    _G.cmp_queue_cancellations = 0
    vim.lsp.get_client_by_id(9001).cancel_request = function(_, id)
      for _, request in ipairs(cmp_queue_requests) do
        if request.id == id and not request.settled then cmp_queue_cancellations = cmp_queue_cancellations + 1 end
      end
    end
  ]])
  ui:rpc("nvim_input", "ia")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "initial incomplete list")
  for _, step in ipairs({ { "l", "al" }, { "p", "alp" }, { "h", "alph" }, { "<BS>", "alp" } }) do
    ui:rpc("nvim_input", step[1])
    ui:lua([[_G.cmp_queue_expected = ...]], step[2])
    wait(
      ui,
      [[return cmp_queue_session.context ~= nil and cmp_queue_session.context.line == cmp_queue_expected]],
      "latest input is observed"
    )
    t.assert_eq(2, ui:lua([[return #cmp_queue_requests]]), "one refresh survives typing and native discard")
    t.assert_true(
      ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]),
      "compatible candidates stay visible"
    )
  end
  t.assert_eq(0, ui:lua([[return cmp_queue_cancellations]]))
  ui:lua([[
    cmp_queue_requests[2].settled = true
    cmp_queue_requests[2].callback(nil, { items = { { label = 'alpha', kind = 6 } }, isIncomplete = true })
  ]])
  wait(ui, [[return #cmp_queue_requests == 3]], "only the latest query follows the pending response")
  t.assert_eq(3, ui:lua([[return cmp_queue_requests[3].params.position.character]]))
  ui:lua([[
    cmp_queue_requests[3].settled = true
    cmp_queue_requests[3].callback(nil, { items = { { label = 'alpine', kind = 6, textEdit = {
      newText = 'alpine', range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 3 } },
    } } }, isIncomplete = false })
  ]])
  wait(
    ui,
    [[
    for _, item in ipairs(vim.fn.complete_info({ 'items' }).items) do
      if item.abbr:find('alpine', 1, true) then return true end
    end
    return false
  ]],
    "latest candidates replace the partial result"
  )
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'alpine']], "acceptance uses the latest edit coordinates")
  ui:rpc("nvim_input", "<Esc>")
  wait(ui, [[return vim.api.nvim_get_mode().mode == 'n']], "normal mode")
  ui:lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  ]])
  ui:rpc("nvim_input", "ia")
  wait(ui, [[return #cmp_queue_requests == 4]], "new pending completion")
  ui:rpc("nvim_input", "l<Esc>")
  wait(ui, [[return vim.api.nvim_get_mode().mode == 'n']], "Escape before the next scheduled refresh")
  t.assert_eq(1, ui:lua([[return cmp_queue_cancellations]]), "Escape retains access to the real cancellation handle")
  ui:lua([[
    cmp_queue_requests[4].callback(nil, { { label = 'ancient', kind = 6 } })
    vim.schedule(function() _G.cmp_queue_drained = true end)
  ]])
  wait(ui, [[return cmp_queue_drained]], "late response drained")
  t.assert_eq(
    false,
    ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]),
    "late reply cannot reopen the menu"
  )
  t.assert_eq("al", ui:lua([[return vim.api.nvim_get_current_line()]]))
end)

t:test("provisional LSP edits remain valid after backspace while a wider query is pending", function()
  local ui = editor({ "-- imports", "" })
  ui:lua([[require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp' } end]])
  lsp_client(
    ui,
    [[
    local initial = true
    return function(_, callback)
      if initial then
        initial = false
        callback(nil, { items = { { label = 'alpha', kind = 6,
          textEdit = { newText = 'alpha', range = {
            start = { line = 1, character = 0 }, ['end'] = { line = 1, character = 4 },
          } },
          additionalTextEdits = { { newText = 'local alpha = require("alpha")\n', range = {
            start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 },
          } } },
        } }, isIncomplete = true })
      else
        _G.cmp_wider_reply = callback
      end
    end
  ]]
  )
  ui:rpc("nvim_input", "ialph")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "initial narrow result")
  ui:rpc("nvim_input", "<BS><BS>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'al' and cmp_wider_reply ~= nil]], "broader query is pending")
  t.assert_true(ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "provisional menu remains available")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_buf_line_count(0) == 3]], "provisional import and main edit are applied")
  t.assert_eq(
    'local alpha = require("alpha")\n-- imports\nalpha',
    ui:lua([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]]),
    "main range shrinks with the input and the import keeps its original coordinate"
  )
end)

for _, action in ipairs({ "foreign menu", "empty menu", "native Ctrl-X" }) do
  t:test(action .. " cancels the discarded completion transport", function()
    local ui = editor({ "" })
    ui:lua([[require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp' } end]])
    lsp_client(
      ui,
      [[
      local initial = true
      return function(_, callback)
        if initial then
          initial = false
          callback(nil, { items = { { label = 'alpha', kind = 6 } }, isIncomplete = true })
        else
          _G.cmp_discard_id = #cmp_requests
          _G.cmp_discard_reply = callback
        end
      end
    ]]
    )
    ui:lua([[
      _G.cmp_discard_cancellations = 0
      vim.lsp.get_client_by_id(9001).cancel_request = function(_, id)
        if id == cmp_discard_id then cmp_discard_cancellations = cmp_discard_cancellations + 1 end
      end
    ]])
    ui:rpc("nvim_input", "ia")
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "initial menu")
    ui:rpc("nvim_input", "l")
    wait(ui, [[return cmp_discard_reply ~= nil]], "pending refresh")
    if action == "native Ctrl-X" then
      ui:rpc("nvim_input", "<C-x>")
    else
      ui:lua([[vim.fn.complete(1, ...)]], action == "foreign menu" and { { word = "alien" } } or {})
    end
    wait(ui, [[return not require('era.keystroke.cmp').is_menu_visible()]], "completion is discarded")
    t.assert_eq(1, ui:lua([[return cmp_discard_cancellations]]), "discard without typing releases the transport")
    ui:lua([[
      cmp_discard_reply(nil, { { label = 'ancient', kind = 6 } })
      vim.schedule(function() _G.cmp_discard_drained = true end)
    ]])
    wait(ui, [[return cmp_discard_drained]], "late response drained")
    t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]))
    if action == "foreign menu" then
      t.assert_eq(
        "alien",
        ui:lua([[return vim.fn.complete_info({ 'items' }).items[1].word]]),
        "foreign menu retains ownership"
      )
    end
  end)
end

t:test("external edits cancel a pending completion even before a menu is visible", function()
  local ui = editor({ "-- unchanged", "" })
  ui:lua([[require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp' } end]])
  lsp_client(ui, [[return function(_, callback) _G.cmp_external_reply = callback end]])
  ui:lua([[
    _G.cmp_external_cancellations = 0
    vim.lsp.get_client_by_id(9001).cancel_request = function()
      cmp_external_cancellations = cmp_external_cancellations + 1
    end
  ]])
  ui:rpc("nvim_input", "ia")
  wait(ui, [[return cmp_external_reply ~= nil]], "completion request is pending")
  ui:lua([[
    _G.cmp_external_obsolete = cmp_external_reply
    vim.api.nvim_buf_set_text(0, 0, 3, 0, 12, { 'changed' })
  ]])
  t.assert_eq(1, ui:lua([[return cmp_external_cancellations]]), "an edit outside the input scope cancels immediately")
  ui:lua([[
    cmp_external_obsolete(nil, { { label = 'ancient', kind = 6 } })
    vim.schedule(function() _G.cmp_external_drained = true end)
  ]])
  wait(ui, [[return cmp_external_drained]], "obsolete response drained")
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]))
end)

for _, resolved in ipairs({ false, true }) do
  t:test(
    resolved and "same-label resolved imports retain selection when another client responds"
      or "same-label additional edits retain selection when another client responds",
    function()
      local ui = editor({ "-- imports", "" })
      ui:lua([[_G.cmp_import_on_resolve = ...]], resolved)
      lsp_client(
        ui,
        [[return function(_, callback)
          local items = {}
          for _, name in ipairs({ 'module_a', 'module_b' }) do
            local item = { label = 'Foo', kind = 6, insertText = 'Foo', data = { module = name } }
            if not cmp_import_on_resolve then
              item.additionalTextEdits = { { newText = 'local Foo = require("' .. name .. '")\n', range = {
                start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 },
              } } }
            end
            items[#items + 1] = item
          end
          callback(nil, items)
        end]],
        [[return function(item)
          if cmp_import_on_resolve then
            item.additionalTextEdits = { { newText = 'local Foo = require("' .. item.data.module .. '")\n', range = {
              start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 },
            } } }
          end
          return item
        end]]
      )
      ui:lua([[
        require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp' } end
        local client = vim.lsp.get_clients({ method = 'textDocument/completion' })[1]
        local late = vim.tbl_extend('force', {}, client, {
          id = 9002,
          request = function(_, _, _, callback)
            _G.cmp_release_other_client = function()
              callback(nil, { { label = 'Foo', kind = 6, data = { module = 'module_c' } } })
            end
            return true, 1
          end,
        })
        vim.lsp.get_clients = function(filter)
          return filter and filter.method == 'textDocument/completion' and { late, client } or {}
        end
        vim.lsp.get_client_by_id = function(id) return id == client.id and client or late end
      ]])
      ui:rpc("nvim_input", "iFo")
      wait(
        ui,
        [[
        return #vim.fn.complete_info({ 'items' }).items == 2
      ]],
        "both import alternatives are visible"
      )
      ui:rpc("nvim_input", "<Tab>")
      wait(ui, [[return vim.api.nvim_get_current_line() == 'Foo']], "second candidate preview")
      ui:lua([[cmp_release_other_client()]])
      wait(
        ui,
        [[
        return #vim.fn.complete_info({ 'items' }).items == 3
      ]],
        "earlier client inserts its candidate before the selected item"
      )
      ui:rpc("nvim_input", "<CR>")
      wait(ui, [[return vim.api.nvim_buf_line_count(0) == 3]], "selected import edit settled")
      t.assert_eq(
        'local Foo = require("module_b")\n-- imports\nFoo',
        ui:lua([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]]),
        "acceptance follows the selected payload, not its label or old list index"
      )
    end
  )
end

t:test("a fresh LSP response does not inherit a selected cached alternative", function()
  local ui = editor({ "-- imports", "" })
  ui:lua([[require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp' } end]])
  lsp_client(
    ui,
    [[local initial = true
      return function(_, callback)
        local item = { label = 'Foo', kind = 6, insertText = 'Foo', data = { module = initial and 'module_a' or 'module_b' } }
        if initial then
          initial = false
          callback(nil, { isIncomplete = true, items = { item } })
        else
          _G.cmp_replace_alternative = function() callback(nil, { isIncomplete = true, items = { item } }) end
        end
      end]],
    [[return function(item)
      item.additionalTextEdits = { { newText = 'local Foo = require("' .. item.data.module .. '")\n', range = {
        start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 },
      } } }
      return item
    end]]
  )
  ui:rpc("nvim_input", "iF")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "initial incomplete list")
  ui:rpc("nvim_input", "o")
  wait(ui, [[return cmp_replace_alternative ~= nil]], "replacement request pending")
  ui:rpc("nvim_input", "<Tab><Tab>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'Foo']], "cached alternative explicitly previewed")
  ui:lua([[cmp_replace_alternative()]])
  wait(ui, [[return vim.api.nvim_get_current_line() == 'Fo']], "replacement restores the stale preview")
  t.assert_true(ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "replacement remains available")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_buf_line_count(0) == 3]], "new alternative accepted")
  t.assert_eq('local Foo = require("module_b")', ui:lua("return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]"))
end)

for _, command in ipairs({ "editor.action.triggerSuggest", "editor.action.triggerParameterHints" }) do
  t:test("acceptance executes the native client command " .. command, function()
    local ui = editor({ "" })
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
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "initial menu")
    ui:rpc("nvim_input", "<CR>")
    wait(ui, [[return vim.api.nvim_get_current_line() == 'alpha']], "completion accepted")
    if command == "editor.action.triggerSuggest" then
      wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "command reopens completion")
    else
      wait(
        ui,
        [[
        for _, winnr in ipairs(vim.api.nvim_list_wins()) do
          local bufnr = vim.api.nvim_win_get_buf(winnr)
          if vim.api.nvim_get_option_value('filetype', { buf = bufnr }) == 'cmp-signature' then return true end
        end
        return false
      ]],
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
    wait(ui, [[return cmp_foreign_command_settled]], "other-buffer command settles")
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
  local ui = editor({ "-- imports", "" })
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
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "LSP candidate")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_buf_line_count(0) == 3]], "import applied")
  t.assert_same(
    { "local Foo = require('foo')", "-- imports", "😀 foobar" },
    ui:lua([[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]),
    "complete edit"
  )
  t.assert_eq(1, ui:lua([[return #cmp_commands]]), "command executed once")
  t.assert_eq(3, ui:lua("return vim.api.nvim_win_get_cursor(0)[1]"), "cursor follows import")
  ui:rpc("nvim_input", "<Esc>u")
  wait(ui, [[return vim.api.nvim_buf_line_count(0) == 2]], "undo entire completion")
  t.assert_eq("😀 fo", ui:lua("return vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]"), "typed prefix restored")
end)

t:test("UTF-16 boundary insertions track the completion after further typing", function()
  local ui = editor({ "" })
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
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "original candidate")
  ui:rpc("nvim_input", "o")
  wait(ui, [[return vim.api.nvim_get_current_line() == '😀 fo']], "continued input")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_get_current_line() == '😀 prefix foobar suffix']], "both boundary edits applied")
  t.assert_eq(#"😀 prefix foobar", ui:lua("return vim.api.nvim_win_get_cursor(0)[2]"), "cursor precedes suffix")
  ui:rpc("nvim_input", "<Esc>u")
  wait(ui, [[return vim.api.nvim_get_current_line() == '😀 fo']], "one undo restores the continued prefix")
end)

t:test("typing during resolve prevents a late edit and command", function()
  local ui = editor({ "" })
  lsp_client(
    ui,
    [[return function(_, callback) callback(nil, { { label = 'foobar', kind = 6 } }) end]],
    [[return function(item)
    item.command = { title = 'late', command = 'fixture.late' }
    return item, 80
  end]]
  )
  ui:rpc("nvim_input", "ifo")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "LSP menu")
  ui:rpc("nvim_input", "<CR>x")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'fox']], "new user input")
  vim.wait(150)
  t.assert_eq("fox", ui:lua([[return vim.api.nvim_get_current_line()]]), "late resolve ignored")
  t.assert_eq(0, ui:lua([[return #cmp_commands]]), "late command ignored")
end)

for _, target in ipairs({ "background", "current" }) do
  t:test(target .. " buffer edits respect pending acceptance ownership", function()
    local ui = editor({ "" })
    ui:lua([[
      _G.cmp_background_bufnr = vim.api.nvim_get_current_buf()
      vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = cmp_background_bufnr })
      require('era.keystroke.cmp.policy').sources_for = function(context, manual)
        return (manual or context.trigger == 'typing') and { 'lsp' } or {}
      end
    ]])
    ui:rpc("nvim_input", "i")
    wait(ui, [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], "background buffer attached")
    local version = ui:lua([[return require('era.keystroke.cmp.context').capture().buffer_version]])
    ui:rpc("nvim_input", "<Esc>")
    wait(ui, [[return vim.api.nvim_get_mode().mode == 'n']], "leave background buffer")
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
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "current buffer candidate")
    ui:lua([[
      _G.cmp_before_accept_request = #cmp_requests
      assert(require('era.keystroke.cmp').accept())
    ]])
    wait(
      ui,
      [[
      for index = cmp_before_accept_request + 1, #cmp_requests do
        if cmp_requests[index].method == 'completionItem/resolve' then return true end
      end
      return false
    ]],
      "native acceptance reached resolve"
    )
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
    vim.wait(150)
    t.assert_eq(current and "edited" or "foobar", ui:lua([[return vim.api.nvim_get_current_line()]]), "resolved text")
    t.assert_eq(current and 0 or 1, ui:lua([[return #cmp_commands]]), "resolved command ownership")
    if not current then
      ui:rpc("nvim_input", "<Esc>")
      wait(ui, [[return vim.api.nvim_get_mode().mode == 'n']], "leave completed buffer")
      ui:lua([[vim.api.nvim_set_current_buf(cmp_background_bufnr)]])
      ui:rpc("nvim_input", "i")
      wait(ui, [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], "return to background buffer")
      t.assert_true(
        version ~= ui:lua([[return require('era.keystroke.cmp.context').capture().buffer_version]]),
        "background edit still invalidates its own context"
      )
    end
  end)
end

t:test("function completion records cursor placement inside brackets", function()
  local ui = editor({ "", "" })
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 1, 0 })]])
  lsp_client(ui, [[return function(_, callback) callback(nil, { { label = 'foobar', kind = 3 } }) end]])
  ui:rpc("nvim_input", "ifo")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "function menu")
  ui:rpc("nvim_input", "<CR>")
  wait(
    ui,
    [[return vim.api.nvim_get_current_line() == 'foobar()' and vim.api.nvim_win_get_cursor(0)[2] == 7]],
    "bracket cursor"
  )
  ui:rpc("nvim_input", "42<Esc>j0.")
  wait(ui, [[return vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == 'foobar(42)']], "repeat bracket placement")
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
    local ui = editor({ case.line })
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
    wait(ui, [[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], case.filetype .. " semantic candidate")
    ui:rpc("nvim_input", "<CR>")
    t.wait_until(function()
      return ui:lua([[return vim.api.nvim_get_current_line()]]) == case.text
    end, 3000, case.filetype .. " accepted text")
    ui:lua([[
      vim.schedule(function()
        vim.schedule(function() _G.cmp_accept_drained = true end)
      end)
    ]])
    wait(ui, [[return cmp_accept_drained == true]], "acceptance callbacks drained")
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
    local ui = editor({ "" })
    lsp_client(
      ui,
      [[return function(_, callback)
      callback(nil, {{label='normalize(value)',kind=3,insertTextFormat=2,insertText='normalize(${1:value})$0'}})
    end]]
    )
    ui:rpc("nvim_input", "inor")
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "function candidate")
    t.assert_eq(
      "normalize(value)",
      ui:lua([[return vim.fn.complete_info({'items'}).items[1].abbr]]),
      "display retains the signature"
    )
    ui:rpc("nvim_input", "<Down><Down>")
    wait(ui, [[return vim.api.nvim_get_current_line() == 'normalize']], "preview inserts only the function name")
    ui:rpc("nvim_input", action)
    local expected = action == "(" and "normalize(" or action == "<C-e>" and "nor" or "normalize(value)"
    t.wait_until(function()
      return ui:lua([[return vim.api.nvim_get_current_line()]]) == expected
    end, 1000, "preview follow-up " .. action)
    t.assert_eq(action == "<CR>", ui:lua([[return vim.snippet.active()]]), "only acceptance starts a snippet")
  end)
end

t:test("LSP snippets expand and Tab moves through the native snippet session", function()
  local ui = editor({ "" })
  lsp_client(
    ui,
    [[return function(_, callback)
    callback(nil, { { label = 'function', kind = 15, insertTextFormat = 2, insertText = 'call(${1:value})$0' } })
  end]]
  )
  ui:rpc("nvim_input", "ifu")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "snippet menu")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.snippet.active() and vim.api.nvim_get_current_line() == 'call(value)']], "snippet expansion")
  ui:rpc("nvim_input", "argument")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'call(argument)']], "placeholder edit")
  ui:rpc("nvim_input", "<Tab>")
  wait(ui, [[return vim.api.nvim_win_get_cursor(0)[2] == #'call(argument)']], "final tabstop")
end)

t:test("complete LSP lists retain their snapshot while the prefix grows and shrinks", function()
  local ui = editor({ "" })
  ui:lua([[
    _G.cmp_snapshot_creations = 0
    local new = yoz.completion.new_snapshot
    yoz.completion.new_snapshot = function(data)
      cmp_snapshot_creations = cmp_snapshot_creations + 1
      return new(data)
    end
    _G.cmp_menu_updates = 0
    local menu = require('era.keystroke.cmp.menu')
    local show = menu.show
    menu.show = function(...)
      cmp_menu_updates = cmp_menu_updates + 1
      return show(...)
    end
  ]])
  lsp_client(ui, [[return function(_, callback) callback(nil, { { label = 'abcdefgh', kind = 6 } }) end]])
  ui:rpc("nvim_input", "iabc")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "initial list")
  local created = ui:lua([[return cmp_snapshot_creations]])
  local updates = ui:lua([[return cmp_menu_updates]])
  for index, step in ipairs({
    { "d", "abcd" },
    { "<BS>", "abc" },
    { "d", "abcd" },
    { "ef", "abcdef" },
    { "<BS><BS><BS>", "abc" },
    { "def", "abcdef" },
    { "<BS><BS><BS>d", "abcd" },
  }) do
    ui:rpc("nvim_input", step[1])
    t.wait_until(function()
      return ui:lua(
        [[return vim.api.nvim_get_current_line() == ... and require('era.keystroke.cmp').is_menu_visible()]],
        step[2]
      )
    end, 3000, "filtered list after " .. step[1])
    vim.wait(30)
    t.assert_eq(created, ui:lua([[return cmp_snapshot_creations]]), "cached native candidate set after " .. step[1])
    if index == 1 then
      t.assert_eq(updates + 1, ui:lua([[return cmp_menu_updates]]), "unchanged source snapshot is not rendered twice")
    end
  end
  t.assert_eq(
    1,
    ui:lua(
      [[local count = 0; for _, r in ipairs(cmp_requests) do if r.method == 'textDocument/completion' then count = count + 1 end end; return count]]
    ),
    "complete list reused"
  )
end)

t:test("closing completion releases native popup visibility", function()
  local ui = editor({ "alpha alpine", "" })
  ui:rpc("nvim_input", "ial")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "completion menu")
  t.assert_eq(1, ui:lua([[return vim.fn.pumvisible()]]), "native menu is visible")
  ui:lua([[require('era.keystroke.cmp').cancel()]])
  wait(ui, [[return vim.fn.pumvisible() == 0]], "native menu is dismissed")
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
    local ui = editor({ "" })
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
    wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "snippet menu")
    if example.preview then
      ui:rpc("nvim_input", "<Tab><Tab>")
      wait(ui, [[return vim.fn.complete_info({ 'selected' }).selected == 0]], "native snippet selected")
      t.assert_eq(
        "zzcmppreview",
        ui:lua([[return vim.api.nvim_get_current_line()]]),
        "native inline preview uses the label"
      )
    end
    wait(
      ui,
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
      "documentation contains the expanded snippet and its description"
    )
    if not example.preview then
      t.assert_eq(
        "zzcmppreview",
        ui:lua([[return vim.api.nvim_get_current_line()]]),
        "documentation does not insert text"
      )
    end
    ui:rpc("nvim_input", "<CR>")
    wait(
      ui,
      [[return vim.api.nvim_get_current_line() == cmp_documentation_expected]],
      "accepted text matches documentation"
    )
    t.assert_eq(example.preview and 1 or 0, ui:lua([[return cmp_random_reads]]), "dynamic values are evaluated once")
  end)
end

t:test("a documentation resolve cannot recreate a dismissed window", function()
  local ui = editor({ "" })
  lsp_client(
    ui,
    [[return function(_, callback) callback(nil, { { label = 'foobar', kind = 6 } }) end]],
    [[return function(item)
    item.documentation = { kind = 'markdown', value = 'late documentation' }
    return item, 80
  end]]
  )
  ui:rpc("nvim_input", "ifo")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "menu")
  ui:rpc("nvim_input", "<C-space>")
  ui:lua([[require('era.keystroke.cmp').cancel()]])
  vim.wait(150)
  t.assert_true(
    ui:lua([[
    for _, winnr in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_win_get_buf(winnr) }) == 'cmp-documentation' then return false end
    end
    return true
  ]]),
    "late documentation discarded"
  )
end)

for _, example in ipairs({
  { name = "prefix", start_col = 0, end_col = 3, text = "xxx", expected = "xxx.fo TAIL" },
  { name = "longer prefix", start_col = 0, end_col = 3, text = "longer", expected = "longer.fo TAIL" },
  { name = "suffix", start_col = 7, end_col = 11, text = "changed", expected = "obj.fo changed" },
  { name = "query replacement", start_col = 4, end_col = 6, text = "external", expected = "obj.external TAIL" },
  { name = "query insertion", start_col = 5, end_col = 5, text = "x", expected = "obj.fxo TAIL" },
  {
    name = "prefix before native acceptance",
    start_col = 0,
    end_col = 3,
    text = "xxx",
    expected = "xxx.fo TAIL",
    native = true,
  },
  {
    name = "suffix before native acceptance",
    start_col = 7,
    end_col = 11,
    text = "changed",
    expected = "obj.fo changed",
    native = true,
  },
}) do
  t:test("external " .. example.name .. " invalidates pending completion without losing dirty state", function()
    local ui = editor({ "-- imports", "obj.fo TAIL" })
    ui:lua([[
      vim.api.nvim_win_set_cursor(0, {2, 6})
      vim.api.nvim_set_option_value('modified', false, {buf=0})
      require('era.keystroke.cmp.policy').sources_for = function(context)
        return context.trigger == 'enter' and {'lsp'} or {}
      end
    ]])
    lsp_client(
      ui,
      [[return function(_, callback)
      callback(nil, {{label='foobar',kind=6,
        textEdit={newText='foobar',range={start={line=1,character=4},['end']={line=1,character=6}}},
        additionalTextEdits={{newText='IMPORT\n',range={start={line=0,character=0},['end']={line=0,character=0}}}},
        command={title='accepted',command='fixture.accepted'}}})
    end]],
      [[return function(item) return item, 1000 end]]
    )
    ui:rpc("nvim_input", "i")
    wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "native selection settled")
    ui:lua(
      [[
      local example = ...
      if not example.native then assert(require('era.keystroke.cmp').accept()) end
      vim.api.nvim_buf_set_text(0, 1, example.start_col, 1, example.end_col, {example.text})
      if example.native then vim.api.nvim_select_popupmenu_item(0,true,true,{}) end
    ]],
      example
    )
    wait(ui, [[return not require('era.keystroke.cmp').is_menu_visible()]], "stale completion dismissed")
    vim.wait(120)
    t.assert_true(
      ui:lua([[return vim.deep_equal({'-- imports',...},vim.api.nvim_buf_get_lines(0,0,-1,false))]], example.expected),
      "external edit remains intact and no import is applied"
    )
    t.assert_true(ui:lua([[return vim.api.nvim_get_option_value('modified',{buf=0})]]), "external changes stay dirty")
    t.assert_eq(0, ui:lua([[return #cmp_commands]]), "stale command does not execute")
  end)
end

for _, preview in ipairs({ false, true }) do
  for _, cancel in ipairs({ { before = false }, { before = true }, { key = true } }) do
    t:test(
      "cancelling "
        .. (preview and "a preview" or "a menu")
        .. (cancel.before and " before" or cancel.key and " with Ctrl-E after" or " after")
        .. " an external query edit preserves that edit",
      function()
        local ui = editor({ "obj.fo TAIL" })
        ui:lua([[
          vim.api.nvim_win_set_cursor(0,{1,6})
          vim.api.nvim_set_option_value('modified',false,{buf=0})
        ]])
        lsp_client(
          ui,
          [[return function(_,callback)
          callback(nil, {{label='foobar',kind=6,command={title='accepted',command='fixture.accepted'}}})
        end]]
        )
        ui:rpc("nvim_input", "i")
        wait(ui, [[return vim.api.nvim_get_mode().mode:sub(1,1)=='i']], "insert mode")
        ui:lua([[require('era.keystroke.cmp').show()]])
        wait(ui, [[return vim.fn.complete_info({'selected'}).selected==0]], "native selection settled")
        if preview then
          ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,false,{})]])
          wait(ui, [[return vim.api.nvim_get_current_line()=='obj.foobar TAIL']], "native prefix preview")
        end
        ui:lua(
          [[
          local cancel=...
          local cmp=require('era.keystroke.cmp')
          if cancel.before then assert(cmp.cancel()) end
          vim.api.nvim_buf_set_text(0,0,4,0,6,{'xx'})
          if cancel.key then vim.api.nvim_input('<C-e>')
          elseif not cancel.before then assert(cmp.cancel()) end
        ]],
          cancel
        )
        wait(ui, [[return not require('era.keystroke.cmp').is_menu_visible()]], "menu cancelled")
        t.assert_eq(
          preview and not cancel.before and "obj.xxobar TAIL" or "obj.xx TAIL",
          ui:lua([[return vim.api.nvim_get_current_line()]]),
          "cancellation does not roll back external input"
        )
        t.assert_true(
          ui:lua([[return vim.api.nvim_get_option_value('modified',{buf=0})]]),
          "external input stays dirty"
        )
        t.assert_eq(0, ui:lua([[return #cmp_commands]]), "cancellation does not execute the command")
      end
    )
  end
end

t:test("resolved acceptance applies before input queued behind Enter", function()
  local ui = editor({ "" })
  lsp_client(
    ui,
    [[return function(_,callback)
    callback(nil, {{label='foobar',kind=6,documentation='Resolved completion.',
      command={title='accepted',command='fixture.accepted'}}})
  end]]
  )
  ui:rpc("nvim_input", "ifo")
  wait(
    ui,
    [[
    for _,winnr in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_get_option_value('filetype',{buf=vim.api.nvim_win_get_buf(winnr)})=='cmp-documentation' then
        return true
      end
    end
    return false
  ]],
    "completion has resolved for documentation"
  )
  ui:rpc("nvim_input", "<CR>x")
  wait(ui, [[return vim.api.nvim_get_current_line()=='foobarx']], "completion precedes queued input")
  t.assert_eq(1, ui:lua([[return #cmp_commands]]), "completion command executes once")
end)

for _, accept in ipairs({ true, false }) do
  t:test(
    accept and "native API acceptance applies full LSP ranges after prefix preview"
      or "native API cancellation never applies LSP imports or commands",
    function()
      local ui = editor({ "-- imports", "foTAIL" })
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
      wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "native menu")
      ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,false,{})]])
      wait(ui, [[return vim.api.nvim_get_current_line()=='foobarTAIL']], "native preview replaces only the prefix")
      ui:lua([[vim.api.nvim_select_popupmenu_item(...,true,true,{})]], accept and 0 or -1)
      if accept then
        wait(
          ui,
          [[return vim.deep_equal({'IMPORT','-- imports','foobar'},vim.api.nvim_buf_get_lines(0,0,-1,false))]],
          "full LSP range replaces the suffix at acceptance"
        )
        t.assert_eq(1, ui:lua([[return #cmp_commands]]), "command executes once")
      else
        wait(
          ui,
          [[return vim.fn.pumvisible()==0 and vim.api.nvim_get_current_line()=='foTAIL']],
          "native cancellation restores the original input"
        )
        t.assert_eq(2, ui:lua([[return vim.api.nvim_buf_line_count(0)]]), "no import applied")
        t.assert_eq(0, ui:lua([[return #cmp_commands]]), "no command executed")
      end
    end
  )
end

t:test("native cancellation dismisses an overflowing menu without extra windows", function()
  local labels = {}
  for index = 1, 40 do
    labels[index] = string.format("alpha%02d", index)
  end
  local ui = editor({ table.concat(labels, " "), "" })
  ui:rpc("nvim_input", "ial")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "menu")
  t.assert_true(ui:lua([[return vim.fn.pum_getpos().scrollbar]]), "native overflow scrollbar")
  t.assert_eq(1, ui:lua([[return #vim.api.nvim_list_wins()]]), "PUM does not create a menu or scrollbar window")
  ui:lua([[vim.api.nvim_select_popupmenu_item(-1, false, true, {})]])
  wait(ui, [[return not require('era.keystroke.cmp').is_menu_visible()]], "menu dismissed")
  t.assert_eq("al", ui:lua([[return vim.api.nvim_get_current_line()]]), "native cancellation preserves input")
  t.assert_eq(1, ui:lua([[return #vim.api.nvim_list_wins()]]), "no residual windows")
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

t:test("Unicode completion records character-safe dot repeat", function()
  local ui = editor({ "中文变量", "", "" })
  ui:lua([[vim.api.nvim_win_set_cursor(0, { 2, 0 })]])
  ui:rpc("nvim_input", "i中变")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "Unicode candidate")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_get_current_line() == '中文变量']], "Unicode acceptance")
  ui:rpc("nvim_input", "<Esc>j0.")
  wait(ui, [[return vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == '中文变量']], "Unicode repeat")
end)

t:test("multiline plain-text completions retain their cursor and undo semantics", function()
  local ui = editor({ "" })
  lsp_client(
    ui,
    [[return function(_, callback)
    callback(nil, { { label = 'fragment', kind = 1, insertText = 'first\nsecond' } })
  end]]
  )
  ui:rpc("nvim_input", "ifr")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "multiline candidate")
  ui:rpc("nvim_input", "<CR>")
  wait(ui, [[return vim.api.nvim_buf_line_count(0) == 2]], "multiline edit")
  t.assert_same({ "first", "second" }, ui:lua([[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), "inserted lines")
  t.assert_same({ 2, 6 }, ui:lua([[return vim.api.nvim_win_get_cursor(0)]]), "cursor after inserted text")
  ui:rpc("nvim_input", "<Esc>u")
  wait(
    ui,
    [[return vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_get_current_line() == 'fr']],
    "undo multiline edit"
  )
end)

t:test("hide falls back to backspace when an empty completion request has no UI", function()
  local ui = editor({ "" })
  ui:rpc("nvim_input", "iqqq")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'qqq']], "typed input")
  vim.wait(30)
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "no candidates")
  ui:rpc("nvim_input", "<C-h>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'qq']], "native backspace fallback")
end)

t:test("Tab without a menu or snippet inserts a tab instead of running an Insert-mode <C-i> mapping", function()
  local lines = {} ---@type string[]
  for index = 1, 60 do
    lines[index] = "line " .. index
  end
  local ui = editor(lines)
  ui:lua([[
    vim.keymap.set('i', '<C-i>', '<C-o><C-o>', { noremap = true })
    vim.cmd('normal! 50G')
    vim.cmd('normal! 10G')
  ]])
  ui:rpc("nvim_input", "A<Tab>X<Esc>")
  wait(ui, [[return vim.api.nvim_get_mode().mode == 'n' and vim.fn.search('X', 'nw') > 0]], "input settled")
  t.assert_eq("line 10\tX", ui:lua([[return vim.fn.getline(10)]]), "tab at the cursor")
  t.assert_eq("line 50", ui:lua([[return vim.fn.getline(50)]]), "jump target untouched")
end)

t:run()
