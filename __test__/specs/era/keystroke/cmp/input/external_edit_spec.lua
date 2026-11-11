local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local t = harness.new()

local lsp_client = embedded.lsp_client

t:test("external edits cancel a pending completion even before a menu is visible", function()
  local ui = embedded.editor(t, { "-- unchanged", "" })
  ui:lua([[require('era.keystroke.cmp.policy').sources_for = function() return { 'lsp' } end]])
  lsp_client(ui, [[return function(_, callback) _G.cmp_external_reply = callback end]])
  ui:lua([[
    _G.cmp_external_cancellations = 0
    vim.lsp.get_client_by_id(9001).cancel_request = function()
      cmp_external_cancellations = cmp_external_cancellations + 1
    end
  ]])
  ui:rpc("nvim_input", "ia")
  ui:wait_lua([[return cmp_external_reply ~= nil]], 5000, "completion request is pending")
  ui:lua([[
    _G.cmp_external_obsolete = cmp_external_reply
    vim.api.nvim_buf_set_text(0, 0, 3, 0, 12, { 'changed' })
  ]])
  t.assert_eq(1, ui:lua([[return cmp_external_cancellations]]), "an edit outside the input scope cancels immediately")
  ui:lua([[
    cmp_external_obsolete(nil, { { label = 'ancient', kind = 6 } })
    vim.schedule(function() _G.cmp_external_drained = true end)
  ]])
  ui:wait_lua([[return cmp_external_drained]], 5000, "obsolete response drained")
  t.assert_eq(false, ui:lua([[return require('era.keystroke.cmp').is_menu_visible()]]))
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
    local ui = embedded.editor(t, { "-- imports", "obj.fo TAIL" })
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
      [[return function(item) return item, 300 end]]
    )
    ui:rpc("nvim_input", "i")
    ui:wait_lua([[return vim.fn.complete_info({'selected'}).selected == 0]], 5000, "native selection settled")
    ui:lua(
      [[
      local example = ...
      if not example.native then assert(require('era.keystroke.cmp').accept()) end
      vim.api.nvim_buf_set_text(0, 1, example.start_col, 1, example.end_col, {example.text})
      if example.native then vim.api.nvim_select_popupmenu_item(0,true,true,{}) end
    ]],
      example
    )
    ui:wait_lua([[return not require('era.keystroke.cmp').is_menu_visible()]], 5000, "stale completion dismissed")
    -- The window outlasts the 300 ms resolve, so a late import or command would show.
    vim.wait(400)
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
        local ui = embedded.editor(t, { "obj.fo TAIL" })
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
        ui:wait_lua([[return vim.api.nvim_get_mode().mode:sub(1,1)=='i']], 5000, "insert mode")
        ui:lua([[require('era.keystroke.cmp').show()]])
        ui:wait_lua([[return vim.fn.complete_info({'selected'}).selected==0]], 5000, "native selection settled")
        if preview then
          ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,false,{})]])
          ui:wait_lua([[return vim.api.nvim_get_current_line()=='obj.foobar TAIL']], 5000, "native prefix preview")
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
        ui:wait_lua([[return not require('era.keystroke.cmp').is_menu_visible()]], 5000, "menu cancelled")
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
