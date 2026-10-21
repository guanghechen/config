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

t:run()
