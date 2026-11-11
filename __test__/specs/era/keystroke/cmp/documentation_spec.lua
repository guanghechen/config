local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")
local t = harness.new()

---@return table
local function documentation_editor()
  local ui = UI.open(t, { width = 100, height = 35 })
  ui:lua([[
    local runtime=require('__test__.support.cmp.runtime')
    runtime.setup()
    vim.o.completeopt='menuone,noselect,popup'
    vim.o.pumborder='rounded'
    _G.cmp_doc_context=runtime.context('al')
    _G.cmp_doc=require('era.keystroke.cmp.documentation').new()
  ]])
  ui:rpc("nvim_input", "ial")
  ui:wait_until(function()
    return ui:rpc("nvim_get_mode").mode == "i"
  end, 5000, "insert mode")
  ui:lua([[
    vim.fn.complete(1,{{word='alpha'},{word='alpine'}})
    vim.api.nvim_select_popupmenu_item(0,false,false,{})
  ]])
  ui:wait_until(function()
    return ui:lua([[return vim.fn.complete_info({'selected'}).selected==0]])
  end, 5000, "native candidate selected")
  t:defer(function()
    t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "native documentation has no editor errors")
  end)
  return ui
end

---@param ui                           table
---@return table
local function documentation_state(ui)
  return ui:lua([[
    local state={visible=cmp_doc:is_visible(),native=vim.fn.complete_info({'selected'}),windows=#vim.api.nvim_list_wins()}
    if not state.visible then return state end
    local winnr=cmp_doc.winnr
    local position=vim.api.nvim_win_get_position(winnr)
    local config=vim.api.nvim_win_get_config(winnr)
    state.winnr=winnr
    state.bufnr=cmp_doc.bufnr
    state.config=config
    state.position=position
    state.content=vim.api.nvim_buf_get_lines(cmp_doc.bufnr,0,-1,false)
    state.view=vim.api.nvim_win_call(winnr,vim.fn.winsaveview)
    state.screen={}
    for row=position[1]+2,position[1]+config.height+1 do
      local cells={}
      for col=position[2]+2,position[2]+config.width+1 do
        cells[#cells+1]=vim.fn.screenstring(row,col)
      end
      state.screen[#state.screen+1]=table.concat(cells)
    end
    return state
  ]])
end

t:test("native info popup measures concealed content and has a single section separator", function()
  local ui = documentation_editor()
  for _, text in ipairs({ "Description.", "---\nDescription.", "  * * *\n\nDescription.", "___\nDescription." }) do
    ui:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',detail='alpha(value)',documentation=...},0)]], text)
    ui:wait_until(function()
      local state = documentation_state(ui)
      return state.visible
        and state.config.height == 3
        and vim.trim(state.screen[1]) == "alpha(value)"
        and state.screen[2] == ("─"):rep(state.config.width)
        and vim.trim(state.screen[3]) == "Description."
    end, 5000, "three visible rows, without exposed fences or duplicate separator: " .. text)
    local state = documentation_state(ui)
    t.assert_eq(state.winnr, state.native.preview_winid, "Neovim owns the info window")
    t.assert_eq(state.bufnr, state.native.preview_bufnr, "Neovim owns the info buffer")
  end
end)

t:test("LuaLS documentation displays its full signature above one native separator", function()
  local ui = documentation_editor()
  ui:lua([[
    local Lsp=require('era.keystroke.cmp.source.lsp')
    local client={id=9001,name='lua_ls',offset_encoding='utf-8',server_capabilities={completionProvider={}}}
    vim.lsp.get_client_by_id=function()return client end
    local item=Lsp.response(cmp_doc_context,client,{{label='alpha',detail='function',documentation={kind='markdown',
      value='```lua\nfunction alpha(value: string)\n  -> string\n```\n\n---\n\nDescription.'}}}).items[1]
    Lsp.resolve(item,function(raw)cmp_doc:show(cmp_doc_context,raw,0)end)
  ]])
  ui:wait_until(function()
    local state = documentation_state(ui)
    return state.visible
      and state.config.height == 4
      and vim.trim(state.screen[1]) == "function alpha(value: string)"
      and vim.trim(state.screen[2]) == "-> string"
      and state.screen[3] == ("─"):rep(state.config.width)
      and vim.trim(state.screen[4]) == "Description."
  end, 5000, "complete signature, one separator and prose use four visible rows")
end)

t:test("native documentation preserves plaintext Markdown characters", function()
  local ui = documentation_editor()
  ui:lua([[
    cmp_doc:show(cmp_doc_context,{label='alpha',detail='alpha(value)',
      documentation={kind='plaintext',value='---\nliteral **text**\n```'}},0)
  ]])
  ui:wait_until(function()
    local state = documentation_state(ui)
    return state.visible
      and state.config.height == 5
      and vim.trim(state.screen[3]) == "---"
      and vim.trim(state.screen[4]) == "literal **text**"
      and vim.trim(state.screen[5]) == "```"
  end, 5000, "plaintext rules, emphasis and backticks stay literal")
  for _, indented in ipairs({ "    ---", " \t---" }) do
    ui:lua(
      [[
      cmp_doc:show(cmp_doc_context,{label='alpha',detail='alpha(value)',documentation=...},0)
    ]],
      indented
    )
    t.assert_true(
      vim.list_contains(documentation_state(ui).content, indented),
      "indented Markdown code is not a section divider"
    )
  end
end)

t:test("native documentation wraps wide text and preserves its view through resize", function()
  local ui = documentation_editor()
  ui:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',documentation='a'..('中'):rep(90)..'b'},0)]])
  ui:wait_until(function()
    local state = documentation_state(ui)
    return state.visible and table.concat(state.screen):find("b", 1, true) ~= nil
  end, 5000, "the final character of a wrapped wide line is actually visible")
  ui:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',
    documentation=('A long documentation line with enough words to wrap after resizing.\n'):rep(60)},0)]])
  t.assert_eq(20, documentation_state(ui).config.height, "tall content is bounded")
  ui:lua([[cmp_doc:scroll(1);cmp_doc:scroll(1)]])
  local before = documentation_state(ui)
  t.assert_eq(9, before.view.topline)
  ui:rpc("nvim_ui_try_resize", 40, 24)
  ui:wait_until(function()
    return ui:lua([[return vim.o.columns==40]])
  end, 5000)
  ui:lua([[cmp_doc:reposition(0)]])
  ui:wait_until(function()
    local state = documentation_state(ui)
    return state.visible and state.config.width < before.config.width
  end, 5000, "native info reflows into the available width")
  local after = documentation_state(ui)
  t.assert_eq(before.winnr, after.winnr, "native window is reused")
  t.assert_eq(before.view.topline, after.view.topline, "reading position is retained")
  t.assert_same(before.content, after.content, "document text is retained")
  t.assert_true(after.position[2] + after.config.width + 2 <= 40, "border fits within the resized grid")
  ui:lua([[vim.api.nvim_select_popupmenu_item(1,false,false,{})]])
  ui:wait_until(function()
    return not documentation_state(ui).visible
  end, 5000, "selection hides old info")
  ui:lua([[cmp_doc:show(cmp_doc_context,{label='alpine',documentation='short'},1)]])
  local short = documentation_state(ui)
  t.assert_eq(1, short.config.height, "reused popup shrinks with content")
  t.assert_eq(1, short.view.topline, "new candidate begins at the top")
  ui:lua([[vim.api.nvim_select_popupmenu_item(-1,false,true,{})]])
  ui:wait_until(function()
    local state = documentation_state(ui)
    return not state.visible and state.native.preview_winid == nil and state.windows == 1
  end, 5000, "native cancellation destroys its info window")
end)

t:test("temporarily hidden native documentation retains its reading position", function()
  local ui = documentation_editor()
  ui:lua([[
    vim.fn.complete(1,{{word='alpha_'..('x'):rep(50)}})
    vim.api.nvim_select_popupmenu_item(0,false,false,{})
  ]])
  ui:wait_until(function()
    return ui:lua([[return vim.fn.complete_info({'selected'}).selected==0]])
  end, 5000, "wide menu selected")
  ui:lua([[
    cmp_doc:show(cmp_doc_context,{label='alpha',documentation=('Documentation line.\n'):rep(60)},0)
    cmp_doc:scroll(1);cmp_doc:scroll(1)
  ]])
  local before = documentation_state(ui)
  t.assert_true(before.view.topline > 1, "document has been scrolled")
  ui:rpc("nvim_ui_try_resize", 60, 24)
  ui:wait_until(function()
    return ui:lua([[return vim.o.columns==60]])
  end, 5000)
  ui:lua([[cmp_doc:reposition(0)]])
  t.assert_false(documentation_state(ui).visible, "native info has no room beside the menu")
  ui:rpc("nvim_ui_try_resize", 100, 35)
  ui:wait_until(function()
    return ui:lua([[return vim.o.columns==100]])
  end, 5000)
  ui:lua([[cmp_doc:reposition(0)]])
  local after = documentation_state(ui)
  t.assert_true(after.visible, "native info is visible again")
  t.assert_eq(before.winnr, after.winnr, "native window retains its identity while hidden")
  t.assert_eq(before.view.topline, after.view.topline, "temporary hiding does not reset the reading position")
end)

t:test("native documentation scrolls inside a wrapped paragraph without moving the input cursor", function()
  local ui = documentation_editor()
  ui:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',documentation=('word '):rep(1000)},0)]])
  local cursor = ui:rpc("nvim_win_get_cursor", 0)
  ui:lua([[cmp_doc:scroll(1)]])
  ui:wait_until(function()
    local state = documentation_state(ui)
    return state.visible and state.view.topline == 1 and state.view.skipcol > 0
  end, 5000, "native smooth scrolling reveals the rest of a single long paragraph")
  t.assert_same(cursor, ui:rpc("nvim_win_get_cursor", 0), "input cursor is unchanged")
  t.assert_eq("ic", ui:rpc("nvim_get_mode").mode, "native completion remains active in Insert mode")
  ui:lua([[cmp_doc:scroll(-1)]])
  ui:wait_until(function()
    return documentation_state(ui).view.skipcol == 0
  end, 5000, "scrolling back reaches the paragraph start")
end)

t:test("empty documentation and disappearing sections leave no stale separator", function()
  local ui = documentation_editor()
  for _, raw in ipairs({
    { label = "empty", detail = vim.NIL, documentation = vim.NIL },
    { label = "empty", documentation = { kind = "markdown", value = vim.NIL } },
  }) do
    ui:lua([[cmp_doc:show(cmp_doc_context,...,0)]], raw)
    t.assert_false(documentation_state(ui).visible)
  end
  for _, raw in ipairs({
    { label = "docs", documentation = "Documentation without a header." },
    { label = "detail", detail = "Header without documentation." },
    { label = "blank", detail = "Header with empty documentation.", documentation = " \n\t" },
    { label = "truncated", detail = ("header\n"):rep(1001), documentation = "Outside the line limit." },
  }) do
    ui:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',detail='header',documentation='description'},0)]])
    ui:lua([[cmp_doc:show(cmp_doc_context,...,0)]], raw)
    ui:wait_until(function()
      local state = documentation_state(ui)
      return state.visible and not vim.list_contains(state.screen, ("─"):rep(state.config.width))
    end, 5000, "no stale separator for " .. raw.label)
    t.assert_true(#documentation_state(ui).content <= 1000, "long content is bounded")
  end
  ui:lua([[cmp_doc:show(cmp_doc_context,{label='empty'},0)]])
  t.assert_false(documentation_state(ui).visible, "empty info hides the native window")
end)

t:run()
