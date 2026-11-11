local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local t = harness.new()

local lsp_client = embedded.lsp_client

-- A completion handler answering with one item whose additional edit replaces the first line, as long as that line is
-- when the request arrives, with IMPORT; `reply` is the statement that passes `result` to `callback`.
---@param reply                         string
---@return string
local function import_handler(reply)
  return [[
    return function(_, callback)
      local length = #vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      local result = { items = { { label = 'foobar', kind = 6, additionalTextEdits = {
        { range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = length } }, newText = 'IMPORT' },
      } } }, isIncomplete = false }
  ]] .. reply .. "\nend"
end

-- Opens a file that the case rewrites on disk; the child's `cmp_reload(command)` reloads it with `checktime` or
-- `:edit!`.
---@param ui                            __test__.support.UI
---@return string
local function reload_target(ui)
  local path = t:tempdir() .. "/reloaded.lua"
  vim.fn.writefile({ "old", "fo" }, path)
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
    _G.cmp_reload = function(command)
      if command == 'checktime' then vim.cmd.checktime() else vim.cmd.edit({ bang = true }) end
    end
  ]],
    path
  )
  return path
end

for _, command in ipairs({ "checktime", "edit" }) do
  t:test(command .. " cancels a pending acceptance and permits a fresh one", function()
    local ui = embedded.editor(t, { "" })
    local path = reload_target(ui)
    lsp_client(ui, import_handler("callback(nil, result)"), [[return function(item) return item, 60 end]])
    ui:rpc("nvim_input", "A")
    ui:wait_lua([[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], 5000, "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "original candidate")
    ui:lua([[
      _G.cmp_reload_resolve_cancels = 0
      vim.lsp.get_client_by_id(9001).cancel_request = function(_, id)
        if cmp_requests[id].method == 'completionItem/resolve' then
          cmp_reload_resolve_cancels = cmp_reload_resolve_cancels + 1
        end
      end
    ]])
    embedded.accept_resolving(ui)
    ui:lua([[_G.cmp_reload_resolve_cancels = 0]])
    vim.fn.writefile({ "new content", "fo" }, path)
    t.assert_eq(
      1,
      ui:lua(
        [[
      cmp_reload(...)
      return cmp_reload_resolve_cancels
    ]],
        command
      ),
      "old acceptance request cancelled during reload"
    )
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "fresh candidate")
    ui:rpc("nvim_input", "<C-y>")
    ui:wait_lua(
      [[return vim.deep_equal({ 'IMPORT', 'foobar' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))]],
      5000,
      "only the newer resolved edit applies"
    )
  end)

  t:test(command .. " invalidates cached edits and preserves buffer tracking and mappings", function()
    local ui = embedded.editor(t, { "" })
    local path = reload_target(ui)
    lsp_client(ui, import_handler("callback(nil, result)"))
    ui:rpc("nvim_input", "A")
    ui:wait_lua([[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], 5000, "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "original completion")
    local original = ui:lua([[return require('era.keystroke.cmp.context').capture()]])
    vim.fn.writefile({ "new content", "fo" }, path)
    t.assert_eq(
      false,
      ui:lua(
        [[
      cmp_reload(...)
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
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "completion after reload")
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
    ui:wait_lua([[return cmp_reload_fallbacks == 1]], 5000, "buffer-local mapping fallback retained")
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "fresh candidate")
    ui:rpc("nvim_input", "<C-y>")
    ui:wait_lua(
      [[return vim.deep_equal({ 'IMPORT', 'foobar' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))]],
      5000,
      "fresh edit uses the current coordinates"
    )
  end)

  t:test(command .. " rejects a completion response delivered after reloading the same query", function()
    local ui = embedded.editor(t, { "" })
    local path = reload_target(ui)
    ui:lua([[_G.cmp_reload_replies = {}]])
    lsp_client(ui, import_handler("cmp_reload_replies[#cmp_reload_replies + 1] = function() callback(nil, result) end"))
    ui:rpc("nvim_input", "A")
    ui:wait_lua([[return vim.api.nvim_get_mode().mode:sub(1, 1) == 'i']], 5000, "insert mode")
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_lua([[return #cmp_reload_replies == 1]], 5000, "pending original request")
    vim.fn.writefile({ "new content", "fo" }, path)
    ui:lua(
      [[
      cmp_reload(...)
      cmp_reload_replies[1]()
    ]],
      command
    )
    vim.wait(30)
    t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]), "late response stays hidden")
    ui:lua([[require('era.keystroke.cmp').show()]])
    ui:wait_lua([[return #cmp_reload_replies == 2]], 5000, "new request")
    ui:lua([[cmp_reload_replies[2]()]])
    ui:wait_lua([[return require('era.keystroke.cmp').is_menu_visible()]], 5000, "new response")
    ui:rpc("nvim_input", "<C-y>")
    ui:wait_lua(
      [[return vim.deep_equal({ 'IMPORT', 'foobar' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))]],
      5000,
      "new response uses reloaded coordinates"
    )
  end)
end

t:run()
