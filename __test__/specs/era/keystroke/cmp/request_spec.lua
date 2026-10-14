local harness = require("__test__.support.harness")
local Rpc = require("__test__.support.rpc")
local t = harness.new("era.keystroke.cmp.request")

for _, timeout in ipairs({ false, true }) do
  for _, prefix in ipairs({ "", "😀 " }) do
    t:test(
      (timeout and "timeout" or "incomplete")
        .. " refresh submits the logical input before native preview"
        .. (prefix == "" and "" or " with UTF-16 offsets"),
      function()
        local root = assert(vim.uv.cwd())
        local rpc = Rpc.new(root)
        t:defer(function()
          rpc:close()
        end)
        rpc:request("nvim_ui_attach", { 100, 35, { ext_linegrid = true, rgb = true } })
        rpc:lua(
          [[
          local root, prefix = ...
          vim.opt.runtimepath:prepend(root)
          package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
          require('__test__.fixtures.era.keystroke.cmp.behavior').setup({
            engine = 'era', lines = { prefix .. 'a TAIL' }, cursor = { 1, #prefix + 1 },
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
          root,
          prefix
        )
        rpc:request("nvim_input", { "i" })
        t.assert_true(
          Rpc.wait(1000, function()
            return rpc:request("nvim_get_mode", {}).mode:sub(1, 1) == "i"
          end, 5),
          "insert mode"
        )
        rpc:lua([[require('era.keystroke.cmp').show()]])
        t.assert_true(
          Rpc.wait(1000, function()
            return rpc:lua([[return vim.fn.complete_info({'selected'}).selected == 0]])
          end, 5),
          "initial incomplete candidate"
        )
        for _, step in ipairs({ { "l", "al TAIL" }, { "p", "alp TAIL" } }) do
          rpc:request("nvim_input", { step[1] })
          t.assert_true(
            Rpc.wait(1000, function()
              return rpc:lua(
                [[
              local session = require('__test__.fixtures.era.keystroke.cmp.behavior').session
              return session.context ~= nil and session.context.line == ...
            ]],
                prefix .. step[2]
              )
            end, 5),
            "latest input owns the pending request"
          )
        end
        rpc:lua([[vim.api.nvim_select_popupmenu_item(0, true, false, {})]])
        t.assert_true(
          Rpc.wait(1000, function()
            return rpc:lua([[return vim.api.nvim_get_current_line() == ...]], prefix .. "alpha TAIL")
          end, 5),
          "native preview is inserted before refresh"
        )
        if not timeout then
          rpc:lua([[
            local request = cmp_refresh_requests[2]
            request.callback(nil, { isIncomplete = true, items = { request.item } })
          ]])
        end
        t.assert_true(
          Rpc.wait(3000, function()
            return rpc:lua([[
            local session = require('__test__.fixtures.era.keystroke.cmp.behavior').session
            return #cmp_refresh_requests == 3 and session.items[1] ~= nil
              and session.items[1].raw.label == 'alpNEW' and session:is_visible()
          ]])
          end, 5),
          "latest queued query publishes its own result"
        )
        rpc:request("nvim_input", { "<CR>" })
        t.assert_true(
          Rpc.wait(1000, function()
            return rpc:lua([[return #require('__test__.fixtures.era.keystroke.cmp.behavior').commands == 1]])
          end, 5),
          "completion accepted"
        )
        t.assert_eq(
          prefix .. "alpNEW CHANGED",
          rpc:lua([[return vim.api.nvim_get_current_line()]]),
          "main and additional edits use the actual request document"
        )
        t.assert_eq(
          prefix .. "alp TAIL",
          rpc:lua([[return cmp_refresh_requests[3].line]]),
          "request submission sees logical input without preview"
        )
        t.assert_eq(
          vim.str_utfindex(prefix .. "alp", "utf-16"),
          rpc:lua([[return cmp_refresh_requests[3].params.position.character]]),
          "request position matches its document"
        )
        t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "no editor errors")
        t.assert_eq(
          0,
          rpc:lua([[return #require('__test__.fixtures.era.keystroke.cmp.behavior').notices]]),
          "no stale-edit warning masks a failed acceptance"
        )
        rpc:request("nvim_input", { "<Esc>u" })
        t.assert_true(
          Rpc.wait(1000, function()
            return rpc:lua([[return vim.api.nvim_get_current_line() == ...]], prefix .. "alp TAIL")
          end, 5),
          "undo restores logical input and the original suffix together"
        )
        rpc:request("nvim_input", { "<C-r>" })
        t.assert_true(
          Rpc.wait(1000, function()
            return rpc:lua([[return vim.api.nvim_get_current_line() == ...]], prefix .. "alpNEW CHANGED")
          end, 5),
          "redo reapplies the same edit transaction"
        )
      end
    )
  end
end

for _, operation in ipairs({ "incomplete", "timeout", "accept", "cancel" }) do
  for _, action in ipairs({ "hide", "show" }) do
    t:test(operation .. " preserves a reentrant " .. action .. " while restoring preview", function()
      local root = assert(vim.uv.cwd())
      local rpc = Rpc.new(root)
      t:defer(function()
        rpc:close()
      end)
      rpc:request("nvim_ui_attach", { 100, 35, { ext_linegrid = true, rgb = true } })
      rpc:lua(
        [[
        local root = ...
        vim.opt.runtimepath:prepend(root)
        package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
        require('__test__.fixtures.era.keystroke.cmp.behavior').setup({
          engine = 'era', lines = { 'a TAIL' }, cursor = { 1, 1 },
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
      ]],
        root
      )
      rpc:request("nvim_input", { "i" })
      t.assert_true(
        Rpc.wait(1000, function()
          return rpc:request("nvim_get_mode", {}).mode:sub(1, 1) == "i"
        end, 5),
        "insert mode"
      )
      rpc:lua([[require('era.keystroke.cmp').show()]])
      t.assert_true(
        Rpc.wait(1000, function()
          return rpc:lua([[return vim.fn.complete_info({'selected'}).selected == 0]])
        end, 5),
        "initial incomplete candidate"
      )
      for _, step in ipairs({ { "l", "al TAIL" }, { "p", "alp TAIL" } }) do
        rpc:request("nvim_input", { step[1] })
        t.assert_true(
          Rpc.wait(1000, function()
            return rpc:lua(
              [[
              local session = require('__test__.fixtures.era.keystroke.cmp.behavior').session
              return session.context ~= nil and session.context.line == ...
            ]],
              step[2]
            )
          end, 5),
          "latest input owns the pending request"
        )
      end
      rpc:lua([[vim.api.nvim_select_popupmenu_item(0, true, false, {})]])
      t.assert_true(
        Rpc.wait(1000, function()
          return rpc:lua([[return vim.api.nvim_get_current_line() == 'alpha TAIL']])
        end, 5),
        "native preview is inserted before refresh"
      )
      rpc:lua(
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
      t.assert_true(
        Rpc.wait(3000, function()
          return rpc:lua([[return cmp_reentered]])
        end, 5),
        "closing the native menu runs the reentrant hook"
      )
      t.assert_eq("alpha TAIL", rpc:lua([[return vim.api.nvim_get_current_line()]]), "superseded restore cannot edit")
      t.assert_eq(
        action == "show" and "alpha TAIL" or false,
        rpc:lua([[
          local session = require('__test__.fixtures.era.keystroke.cmp.behavior').session
          return session.context ~= nil and session.context.line or false
        ]]),
        "the reentrant action retains context ownership"
      )
      t.assert_eq(
        action == "show" and 3 or 2,
        rpc:lua([[return #cmp_refresh_requests]]),
        "only the current owner can submit a request"
      )
      t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "no editor errors")
    end)
  end
end

for _, operation in ipairs({ "manual", "input" }) do
  t:test(operation .. " redraw preserves a reentrant hide and rejects native acceptance", function()
    local root = assert(vim.uv.cwd())
    local rpc = Rpc.new(root)
    t:defer(function()
      rpc:close()
    end)
    rpc:request("nvim_ui_attach", { 100, 35, { ext_linegrid = true, rgb = true } })
    rpc:lua(
      [[
      local root = ...
      vim.opt.runtimepath:prepend(root)
      package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
      require('__test__.fixtures.era.keystroke.cmp.behavior').setup({
        engine = 'era', lines = { 'a TAIL' }, cursor = { 1, 1 },
        items = {{
          label = 'alpha', kind = 6,
          command = { title = 'accepted', command = 'fixture.accepted' },
        }},
      })
    ]],
      root
    )
    rpc:request("nvim_input", { "i" })
    t.assert_true(
      Rpc.wait(1000, function()
        return rpc:request("nvim_get_mode", {}).mode:sub(1, 1) == "i"
      end, 5),
      "insert mode"
    )
    rpc:lua([[require('era.keystroke.cmp').show()]])
    t.assert_true(
      Rpc.wait(1000, function()
        return rpc:lua([[return vim.fn.complete_info({'selected'}).selected == 0]])
      end, 5),
      "initial candidate is visible without inserting a preview"
    )
    rpc:lua([[
      cmp_redraw_reentered = false
      vim.api.nvim_create_autocmd('CompleteDone', { once = true, callback = function()
        local session = require('__test__.fixtures.era.keystroke.cmp.behavior').session
        cmp_redraw_internal = session.internal
        require('era.keystroke.cmp').hide()
        cmp_redraw_reentered = true
      end })
    ]])
    if operation == "manual" then
      rpc:lua([[require('era.keystroke.cmp').show()]])
    else
      rpc:request("nvim_input", { "l" })
    end
    t.assert_true(
      Rpc.wait(1000, function()
        return rpc:lua([[return cmp_redraw_reentered]])
      end, 5),
      "replacing the native list runs the reentrant hook"
    )
    t.assert_true(rpc:lua([[return cmp_redraw_internal]]), "hide runs during the internal redraw")
    local input = operation == "manual" and "a TAIL" or "al TAIL"
    t.assert_eq(input, rpc:lua([[return vim.api.nvim_get_current_line()]]), "hide preserves logical input")
    local state = rpc:lua([[
      local session = require('__test__.fixtures.era.keystroke.cmp.behavior').session
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
    rpc:lua([[vim.api.nvim_select_popupmenu_item(0, true, true, {})]])
    t.assert_eq(input, rpc:lua([[return vim.api.nvim_get_current_line()]]), "a cancelled list cannot insert text")
    t.assert_eq(
      0,
      rpc:lua([[return #require('__test__.fixtures.era.keystroke.cmp.behavior').commands]]),
      "a cancelled list cannot execute an acceptance command"
    )
    t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "no assertion after native acceptance")
    rpc:lua([[require('era.keystroke.cmp').show()]])
    t.assert_true(
      Rpc.wait(1000, function()
        return rpc:lua([[return require('era.keystroke.cmp').is_menu_visible()]])
      end, 5),
      "a new owner can reopen completion"
    )
    rpc:lua([[vim.api.nvim_select_popupmenu_item(0, true, true, {})]])
    t.assert_true(
      Rpc.wait(1000, function()
        return rpc:lua([[return #require('__test__.fixtures.era.keystroke.cmp.behavior').commands == 1]])
      end, 5),
      "the new owner completes the full acceptance transaction"
    )
    t.assert_eq("alpha TAIL", rpc:lua([[return vim.api.nvim_get_current_line()]]))
    t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "no editor errors after reopening")
  end)
end

t:run()
