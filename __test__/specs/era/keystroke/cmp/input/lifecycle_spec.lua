local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local t = harness.new()

local lsp_client = embedded.lsp_client

for _, independent in ipairs({ false, true }) do
  t:test(
    independent and "late LSP candidates preserve an independent source selection"
      or "late primary results remove an ineligible fallback preview",
    function()
      local ui = embedded.editor(t, { "alpha alpine", "" })
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
      ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "buffer candidates")
      ui:rpc("nvim_input", "<Tab>")
      ui:wait_lua([[return vim.api.nvim_get_current_line() == 'alpine']], 5000, "explicit selection")
      ui:lua([[_G.release_late_completion()]])
      embedded.wait_menu_item(ui, "albatross", "late LSP response rendered")
      ui:wait_lua(
        independent and [[return vim.api.nvim_get_current_line() == 'alpine']]
          or [[return vim.api.nvim_get_current_line() == 'al']],
        5000,
        "preview follows candidate eligibility"
      )
      ui:rpc("nvim_input", "<C-y>")
      -- This fixture's independent sources also opt into the accept trigger and open a fresh list.
      ui:wait_lua(
        independent and [[return #vim.fn.complete_info({'items'}).items == 1]]
          or [[return vim.api.nvim_get_current_line() == 'albatross']],
        5000,
        "acceptance completes and any fresh list uses the accepted input"
      )
      ui:wait_until(function()
        return ui:lua([[return vim.api.nvim_get_current_line()]]) == (independent and "alpine" or "albatross")
      end, 5000, "acceptance uses an eligible item")
    end
  )
end

t:test("incomplete LSP refresh keeps compatible candidates until the new response arrives", function()
  local ui = embedded.editor(t, { "" })
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
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "initial LSP candidates")
  ui:rpc("nvim_input", "l")
  ui:wait_lua([[return _G.release_response ~= nil]], 5000, "incomplete refresh requested")
  t.assert_true(
    ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]),
    "old compatible menu remains visible"
  )
  ui:lua([[_G.release_response()]])
  embedded.wait_menu_item(ui, "albatross", "fresh candidates replace the previous snapshot")
end)

t:test("typing and native backspace share a pending LSP request while Escape still cancels it", function()
  local ui = embedded.editor(t, { "" })
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
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "initial incomplete list")
  for _, step in ipairs({ { "l", "al" }, { "p", "alp" }, { "h", "alph" }, { "<BS>", "alp" } }) do
    ui:rpc("nvim_input", step[1])
    ui:lua([[_G.cmp_queue_expected = ...]], step[2])
    ui:wait_lua(
      [[return cmp_queue_session.context ~= nil and cmp_queue_session.context.line == cmp_queue_expected]],
      5000,
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
  ui:wait_lua([[return #cmp_queue_requests == 3]], 5000, "only the latest query follows the pending response")
  t.assert_eq(3, ui:lua([[return cmp_queue_requests[3].params.position.character]]))
  ui:lua([[
    cmp_queue_requests[3].settled = true
    cmp_queue_requests[3].callback(nil, { items = { { label = 'alpine', kind = 6, textEdit = {
      newText = 'alpine', range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 3 } },
    } } }, isIncomplete = false })
  ]])
  embedded.wait_menu_item(ui, "alpine", "latest candidates replace the partial result")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua(
    [[return vim.api.nvim_get_current_line() == 'alpine']],
    5000,
    "acceptance uses the latest edit coordinates"
  )
  ui:rpc("nvim_input", "<Esc>")
  ui:wait_lua([[return vim.api.nvim_get_mode().mode == 'n']], 5000, "normal mode")
  ui:lua([[
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '' })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  ]])
  ui:rpc("nvim_input", "ia")
  ui:wait_lua([[return #cmp_queue_requests == 4]], 5000, "new pending completion")
  ui:rpc("nvim_input", "l<Esc>")
  ui:wait_lua([[return vim.api.nvim_get_mode().mode == 'n']], 5000, "Escape before the next scheduled refresh")
  t.assert_eq(1, ui:lua([[return cmp_queue_cancellations]]), "Escape retains access to the real cancellation handle")
  ui:lua([[
    cmp_queue_requests[4].callback(nil, { { label = 'ancient', kind = 6 } })
    vim.schedule(function() _G.cmp_queue_drained = true end)
  ]])
  ui:wait_lua([[return cmp_queue_drained]], 5000, "late response drained")
  t.assert_eq(
    false,
    ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]),
    "late reply cannot reopen the menu"
  )
  t.assert_eq("al", ui:lua([[return vim.api.nvim_get_current_line()]]))
end)

t:test("provisional LSP edits remain valid after backspace while a wider query is pending", function()
  local ui = embedded.editor(t, { "-- imports", "" })
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
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "initial narrow result")
  ui:rpc("nvim_input", "<BS><BS>")
  ui:wait_lua(
    [[return vim.api.nvim_get_current_line() == 'al' and cmp_wider_reply ~= nil]],
    5000,
    "broader query is pending"
  )
  t.assert_true(ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "provisional menu remains available")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_buf_line_count(0) == 3]], 5000, "provisional import and main edit are applied")
  t.assert_eq(
    'local alpha = require("alpha")\n-- imports\nalpha',
    ui:lua([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]]),
    "main range shrinks with the input and the import keeps its original coordinate"
  )
end)

for _, action in ipairs({ "foreign menu", "empty menu", "native Ctrl-X" }) do
  t:test(action .. " cancels the discarded completion transport", function()
    local ui = embedded.editor(t, { "" })
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
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "initial menu")
    ui:rpc("nvim_input", "l")
    ui:wait_lua([[return cmp_discard_reply ~= nil]], 5000, "pending refresh")
    if action == "native Ctrl-X" then
      ui:rpc("nvim_input", "<C-x>")
    else
      ui:lua([[vim.fn.complete(1, ...)]], action == "foreign menu" and { { word = "alien" } } or {})
    end
    ui:wait_lua([[return not require('era.keystroke.cmp').is_menu_visible()]], 5000, "completion is discarded")
    t.assert_eq(1, ui:lua([[return cmp_discard_cancellations]]), "discard without typing releases the transport")
    ui:lua([[
      cmp_discard_reply(nil, { { label = 'ancient', kind = 6 } })
      vim.schedule(function() _G.cmp_discard_drained = true end)
    ]])
    ui:wait_lua([[return cmp_discard_drained]], 5000, "late response drained")
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

for _, resolved in ipairs({ false, true }) do
  t:test(
    resolved and "same-label resolved imports retain selection when another client responds"
      or "same-label additional edits retain selection when another client responds",
    function()
      local ui = embedded.editor(t, { "-- imports", "" })
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
      ui:wait_lua(
        [[
        return #vim.fn.complete_info({ 'items' }).items == 2
      ]],
        5000,
        "both import alternatives are visible"
      )
      ui:rpc("nvim_input", "<Tab>")
      ui:wait_lua([[return vim.api.nvim_get_current_line() == 'Foo']], 5000, "second candidate preview")
      ui:lua([[cmp_release_other_client()]])
      ui:wait_lua(
        [[
        return #vim.fn.complete_info({ 'items' }).items == 3
      ]],
        5000,
        "earlier client inserts its candidate before the selected item"
      )
      ui:rpc("nvim_input", "<CR>")
      ui:wait_lua([[return vim.api.nvim_buf_line_count(0) == 3]], 5000, "selected import edit settled")
      t.assert_eq(
        'local Foo = require("module_b")\n-- imports\nFoo',
        ui:lua([[return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')]]),
        "acceptance follows the selected payload, not its label or old list index"
      )
    end
  )
end

t:test("a fresh LSP response does not inherit a selected cached alternative", function()
  local ui = embedded.editor(t, { "-- imports", "" })
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
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "initial incomplete list")
  ui:rpc("nvim_input", "o")
  ui:wait_lua([[return cmp_replace_alternative ~= nil]], 5000, "replacement request pending")
  ui:rpc("nvim_input", "<Tab><Tab>")
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'Foo']], 5000, "cached alternative explicitly previewed")
  ui:lua([[cmp_replace_alternative()]])
  ui:wait_lua([[return vim.api.nvim_get_current_line() == 'Fo']], 5000, "replacement restores the stale preview")
  t.assert_true(ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "replacement remains available")
  ui:rpc("nvim_input", "<C-y>")
  ui:wait_lua([[return vim.api.nvim_buf_line_count(0) == 3]], 5000, "new alternative accepted")
  t.assert_eq('local Foo = require("module_b")', ui:lua("return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]"))
end)

t:test("complete LSP lists retain their snapshot while the prefix grows and shrinks", function()
  local ui = embedded.editor(t, { "" })
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
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "initial list")
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
    ui:wait_until(function()
      return ui:lua(
        [[return vim.api.nvim_get_current_line() == ... and require('era.keystroke.cmp').is_menu_visible()]],
        step[2]
      )
    end, 5000, "filtered list after " .. step[1])
    vim.wait(30)
    t.assert_eq(created, ui:lua([[return cmp_snapshot_creations]]), "cached native candidate set after " .. step[1])
    if index == 1 then
      -- The key's refresh is scheduled; the previous render keeps the menu visible until it runs.
      ui:wait_until(function()
        return ui:lua([[return cmp_menu_updates]]) == updates + 1
      end, 5000, "unchanged source snapshot is not rendered twice")
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

t:test("a documentation resolve cannot recreate a dismissed window", function()
  local ui = embedded.editor(t, { "" })
  lsp_client(
    ui,
    [[return function(_, callback) callback(nil, { { label = 'foobar', kind = 6 } }) end]],
    [[return function(item)
    item.documentation = { kind = 'markdown', value = 'late documentation' }
    return item, 80
  end]]
  )
  ui:rpc("nvim_input", "ifo")
  ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "menu")
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

t:test("a terminating signal ends the editor while completion is visible", function()
  local lines = {} ---@type string[]
  for index = 1, 20 do
    lines[index] = ""
  end
  -- On a short screen an error message on exit waits at the more prompt, so the child never exits.
  local ui = embedded.behavior_editor(t, { lines = lines, cursor = { 10, 0 } }, { width = 80, height = 8 })
  ui:rpc("nvim_input", "ial")
  ui:wait_lua([[return vim.fn.pumvisible() == 1]], 5000, "completion menu is visible")
  -- The completion session is destroyed on VimLeavePre, after SIGTERM has unloaded the buffer contents.
  local closed, err = pcall(ui.close, ui)
  t.assert_true(closed, tostring(err))
end)

t:run()
