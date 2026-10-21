local harness = require("__test__.support.harness")
local embedded = require("__test__.support.cmp.embedded")
local t = harness.new()

---@param lines                         string[]
---@return __test__.support.UI
local function editor(lines)
  return embedded.editor(t, lines)
end

local wait = embedded.wait

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

t:test("closing completion releases native popup visibility", function()
  local ui = editor({ "alpha alpine", "" })
  ui:rpc("nvim_input", "ial")
  wait(ui, [[return require('era.keystroke.cmp').is_menu_visible()]], "completion menu")
  t.assert_eq(1, ui:lua([[return vim.fn.pumvisible()]]), "native menu is visible")
  ui:lua([[require('era.keystroke.cmp').cancel()]])
  wait(ui, [[return vim.fn.pumvisible() == 0]], "native menu is dismissed")
end)

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
