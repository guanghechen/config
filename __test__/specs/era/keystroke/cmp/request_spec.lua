local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")
local t = harness.new()

for _, timeout in ipairs({ false, true }) do
  for _, prefix in ipairs({ "", "😀 " }) do
    t:test(
      (timeout and "timeout" or "incomplete")
        .. " refresh submits the logical input before native preview"
        .. (prefix == "" and "" or " with UTF-16 offsets"),
      function()
        local ui = UI.new()
        t:defer(function()
          ui:close()
        end)
        ui:start({ width = 100, height = 35 })
        ui:lua(
          [[
          local prefix = ...
          require('__test__.support.cmp.behavior').setup({
            lines = { prefix .. 'a TAIL' }, cursor = { 1, #prefix + 1 },
            items = {{ label = 'alpha', kind = 6 }},
          })
          _G.cmp_refresh_requests = {}
          local client = vim.lsp.get_client_by_id(9001)
          local request = client.request
          client.request = function(self, method, params, callback, bufnr)
            if method ~= 'textDocument/completion' then
              return request(self, method, params, callback, bufnr)
            end
            local index = #cmp_refresh_requests + 1
            local line = vim.api.nvim_get_current_line()
            local start = vim.str_utfindex(prefix, 'utf-16')
            local item = {
              label = 'alpha', kind = 6,
              textEdit = {
                newText = 'alpha',
                range = { start = { line = 0, character = start }, ['end'] = params.position },
              },
            }
            cmp_refresh_requests[index] = { line = line, params = params, callback = callback, item = item }
            if index == 1 then
              callback(nil, { isIncomplete = true, items = { item } })
            elseif index == 3 then
              -- A real server computes ranges against the document flushed at request submission.
              local tail = vim.str_utfindex(line, 'utf-16', assert(line:find('TAIL', 1, true)) - 1)
              vim.defer_fn(function()
                callback(nil, { items = {{
                  label = 'alpNEW', kind = 6,
                  textEdit = {
                    newText = 'alpNEW',
                    range = { start = { line = 0, character = start }, ['end'] = { line = 0, character = tail - 1 } },
                  },
                  additionalTextEdits = {{
                    newText = 'CHANGED',
                    range = { start = { line = 0, character = tail }, ['end'] = { line = 0, character = tail + 4 } },
                  }},
                  command = { title = 'accepted', command = 'fixture.accepted' },
                }} })
              end, 20)
            end
            return true, 100 + index
          end
        ]],
          prefix
        )
        ui:rpc("nvim_input", "i")
        ui:wait_until(function()
          return ui:rpc("nvim_get_mode").mode:sub(1, 1) == "i"
        end, 1000, "insert mode")
        ui:lua([[require('era.keystroke.cmp').show()]])
        ui:wait_until(function()
          return ui:lua([[return vim.fn.complete_info({'selected'}).selected == 0]])
        end, 1000, "initial incomplete candidate")
        for _, step in ipairs({ { "l", "al TAIL" }, { "p", "alp TAIL" } }) do
          ui:rpc("nvim_input", step[1])
          ui:wait_until(function()
            return ui:lua(
              [[
              local session = require('__test__.support.cmp.behavior').session
              return session.context ~= nil and session.context.line == ...
            ]],
              prefix .. step[2]
            )
          end, 1000, "latest input owns the pending request")
        end
        ui:lua([[vim.api.nvim_select_popupmenu_item(0, true, false, {})]])
        ui:wait_until(function()
          return ui:lua([[return vim.api.nvim_get_current_line() == ...]], prefix .. "alpha TAIL")
        end, 1000, "native preview is inserted before refresh")
        if not timeout then
          ui:lua([[
            local request = cmp_refresh_requests[2]
            request.callback(nil, { isIncomplete = true, items = { request.item } })
          ]])
        end
        ui:wait_until(function()
          return ui:lua([[
            local session = require('__test__.support.cmp.behavior').session
            return #cmp_refresh_requests == 3 and session.items[1] ~= nil
              and session.items[1].raw.label == 'alpNEW' and session:is_visible()
          ]])
        end, 3000, "latest queued query publishes its own result")
        ui:rpc("nvim_input", "<CR>")
        ui:wait_until(function()
          return ui:lua([[return #require('__test__.support.cmp.behavior').commands == 1]])
        end, 1000, "completion accepted")
        t.assert_eq(
          prefix .. "alpNEW CHANGED",
          ui:lua([[return vim.api.nvim_get_current_line()]]),
          "main and additional edits use the actual request document"
        )
        t.assert_eq(
          prefix .. "alp TAIL",
          ui:lua([[return cmp_refresh_requests[3].line]]),
          "request submission sees logical input without preview"
        )
        t.assert_eq(
          vim.str_utfindex(prefix .. "alp", "utf-16"),
          ui:lua([[return cmp_refresh_requests[3].params.position.character]]),
          "request position matches its document"
        )
        t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
        t.assert_eq(
          0,
          ui:lua([[return #require('__test__.support.cmp.behavior').notices]]),
          "no stale-edit warning masks a failed acceptance"
        )
        ui:rpc("nvim_input", "<Esc>u")
        ui:wait_until(function()
          return ui:lua([[return vim.api.nvim_get_current_line() == ...]], prefix .. "alp TAIL")
        end, 1000, "undo restores logical input and the original suffix together")
        ui:rpc("nvim_input", "<C-r>")
        ui:wait_until(function()
          return ui:lua([[return vim.api.nvim_get_current_line() == ...]], prefix .. "alpNEW CHANGED")
        end, 1000, "redo reapplies the same edit transaction")
      end
    )
  end
end

for _, operation in ipairs({ "incomplete", "timeout", "accept", "cancel" }) do
  for _, action in ipairs({ "hide", "show" }) do
    t:test(operation .. " preserves a reentrant " .. action .. " while restoring preview", function()
      local ui = UI.new()
      t:defer(function()
        ui:close()
      end)
      ui:start({ width = 100, height = 35 })
      ui:lua([[
        require('__test__.support.cmp.behavior').setup({
          lines = { 'a TAIL' }, cursor = { 1, 1 },
          items = {{ label = 'alpha', kind = 6 }},
        })
        _G.cmp_refresh_requests = {}
        local client = vim.lsp.get_client_by_id(9001)
        local request = client.request
        client.request = function(self, method, params, callback, bufnr)
          if method ~= 'textDocument/completion' then
            return request(self, method, params, callback, bufnr)
          end
          local index = #cmp_refresh_requests + 1
          cmp_refresh_requests[index] = { line = vim.api.nvim_get_current_line(), callback = callback }
          if index == 1 then
            callback(nil, { isIncomplete = true, items = {{ label = 'alpha', kind = 6 }} })
          end
          return true, 100 + index
        end
      ]])
      ui:rpc("nvim_input", "i")
      ui:wait_until(function()
        return ui:rpc("nvim_get_mode").mode:sub(1, 1) == "i"
      end, 1000, "insert mode")
      ui:lua([[require('era.keystroke.cmp').show()]])
      ui:wait_until(function()
        return ui:lua([[return vim.fn.complete_info({'selected'}).selected == 0]])
      end, 1000, "initial incomplete candidate")
      for _, step in ipairs({ { "l", "al TAIL" }, { "p", "alp TAIL" } }) do
        ui:rpc("nvim_input", step[1])
        ui:wait_until(function()
          return ui:lua(
            [[
              local session = require('__test__.support.cmp.behavior').session
              return session.context ~= nil and session.context.line == ...
            ]],
            step[2]
          )
        end, 1000, "latest input owns the pending request")
      end
      ui:lua([[vim.api.nvim_select_popupmenu_item(0, true, false, {})]])
      ui:wait_until(function()
        return ui:lua([[return vim.api.nvim_get_current_line() == 'alpha TAIL']])
      end, 1000, "native preview is inserted before refresh")
      ui:lua(
        [[
        local action, operation = ...
        _G.cmp_reentered = false
        vim.api.nvim_create_autocmd('CompleteDone', { once = true, callback = function()
          require('era.keystroke.cmp')[action]()
          cmp_reentered = true
        end })
        if operation == 'incomplete' then
          cmp_refresh_requests[2].callback(nil, { isIncomplete = true, items = {{ label = 'alpha', kind = 6 }} })
        elseif operation ~= 'timeout' then
          require('era.keystroke.cmp')[operation]()
        end
      ]],
        action,
        operation
      )
      ui:wait_until(function()
        return ui:lua([[return cmp_reentered]])
      end, 3000, "closing the native menu runs the reentrant hook")
      t.assert_eq("alpha TAIL", ui:lua([[return vim.api.nvim_get_current_line()]]), "superseded restore cannot edit")
      t.assert_eq(
        action == "show" and "alpha TAIL" or false,
        ui:lua([[
          local session = require('__test__.support.cmp.behavior').session
          return session.context ~= nil and session.context.line or false
        ]]),
        "the reentrant action retains context ownership"
      )
      t.assert_eq(
        action == "show" and 3 or 2,
        ui:lua([[return #cmp_refresh_requests]]),
        "only the current owner can submit a request"
      )
      t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
    end)
  end
end

for _, operation in ipairs({ "manual", "input" }) do
  t:test(operation .. " redraw preserves a reentrant hide and rejects native acceptance", function()
    local ui = UI.new()
    t:defer(function()
      ui:close()
    end)
    ui:start({ width = 100, height = 35 })
    ui:lua([[
      require('__test__.support.cmp.behavior').setup({
        lines = { 'a TAIL' }, cursor = { 1, 1 },
        items = {{
          label = 'alpha', kind = 6,
          command = { title = 'accepted', command = 'fixture.accepted' },
        }},
      })
    ]])
    ui:rpc("nvim_input", "i")
    ui:wait_until(function()
      return ui:rpc("nvim_get_mode").mode:sub(1, 1) == "i"
    end, 1000, "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_until(function()
      return ui:lua([[return vim.fn.complete_info({'selected'}).selected == 0]])
    end, 1000, "initial candidate is visible without inserting a preview")
    ui:lua([[
      cmp_redraw_reentered = false
      vim.api.nvim_create_autocmd('CompleteDone', { once = true, callback = function()
        local session = require('__test__.support.cmp.behavior').session
        cmp_redraw_internal = session.internal
        require('era.keystroke.cmp').hide()
        cmp_redraw_reentered = true
      end })
    ]])
    if operation == "manual" then
      ui:lua([[require('era.keystroke.cmp').show()]])
    else
      ui:rpc("nvim_input", "l")
    end
    ui:wait_until(function()
      return ui:lua([[return cmp_redraw_reentered]])
    end, 1000, "replacing the native list runs the reentrant hook")
    t.assert_true(ui:lua([[return cmp_redraw_internal]]), "hide runs during the internal redraw")
    local input = operation == "manual" and "a TAIL" or "al TAIL"
    t.assert_eq(input, ui:lua([[return vim.api.nvim_get_current_line()]]), "hide preserves logical input")
    local state = ui:lua([[
      local session = require('__test__.support.cmp.behavior').session
      return {
        context = session.context ~= nil,
        count = #session.items,
        active = session.menu.active,
        visible = vim.fn.pumvisible() == 1,
      }
    ]])
    t.assert_false(state.context, "hide releases the context")
    t.assert_eq(0, state.count, "hide releases the candidates")
    t.assert_false(state.active, "the cancelled owner cannot reactivate its menu")
    t.assert_false(state.visible, "the cancelled native list cannot remain visible")
    ui:lua([[vim.api.nvim_select_popupmenu_item(0, true, true, {})]])
    t.assert_eq(input, ui:lua([[return vim.api.nvim_get_current_line()]]), "a cancelled list cannot insert text")
    t.assert_eq(
      0,
      ui:lua([[return #require('__test__.support.cmp.behavior').commands]]),
      "a cancelled list cannot execute an acceptance command"
    )
    t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no assertion after native acceptance")
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_until(function()
      return ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]])
    end, 1000, "a new owner can reopen completion")
    ui:lua([[vim.api.nvim_select_popupmenu_item(0, true, true, {})]])
    ui:wait_until(function()
      return ui:lua([[return #require('__test__.support.cmp.behavior').commands == 1]])
    end, 1000, "the new owner completes the full acceptance transaction")
    t.assert_eq("alpha TAIL", ui:lua([[return vim.api.nvim_get_current_line()]]))
    t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors after reopening")
  end)
end

t:run()
