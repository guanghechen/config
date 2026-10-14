---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.keystroke.cmp.window" ---@type string

local harness = require("__test__.support.harness")
local runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
runtime.setup()
local t = harness.new("era.keystroke.cmp.window")
require("era.keystroke.cmp").setup()

t:test("numeric signature parameter offsets are UTF-16 regardless of client encoding", function()
  local signature = require("era.keystroke.cmp.signature").new()
  t:defer(function()
    signature:destroy()
  end)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "call(" })
  signature:render(runtime.context("call("), {
    activeSignature = 0,
    activeParameter = 0,
    signatures = { { label = "call(😀 value)", parameters = { { label = { 8, 13 } } } } },
  })
  local bufnr = signature.bufnr
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })
  t.assert_eq(1, #marks, "active parameter")
  local mark = marks[1]
  local text = vim.api.nvim_buf_get_lines(bufnr, mark[2], mark[2] + 1, false)[1]
  t.assert_eq("value", text:sub(mark[3] + 1, mark[4].end_col), "highlighted parameter")
end)

t:test("string signature parameters start after the server's trigger characters", function()
  local signature = require("era.keystroke.cmp.signature").new()
  t:defer(function()
    signature:destroy()
  end)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo(" })
  for _, example in ipairs({
    { label = "foo(foo)", parameter = 0, start_col = 4, end_col = 7 },
    { label = "(foo)", parameter = 0, start_col = 1, end_col = 4 },
    { label = "pkg.foo(foo)", parameter = 0, start_col = 8, end_col = 11 },
    { label = "foo(foo, foo)", parameter = 1, start_col = 9, end_col = 12 },
  }) do
    local parameters = { { label = "foo" } }
    if example.parameter == 1 then
      parameters[2] = { label = "foo" }
    end
    signature:render(runtime.context("foo("), {
      activeParameter = example.parameter,
      signatures = { { label = example.label, parameters = parameters } },
    }, { "(", "," })
    local marks = vim.api.nvim_buf_get_extmarks(signature.bufnr, -1, 0, -1, {
      details = true,
    })
    t.assert_eq(1, #marks, example.label)
    t.assert_eq(0, marks[1][2], "plain signature label row")
    t.assert_eq(example.start_col, marks[1][3], "parameter start")
    t.assert_eq(example.end_col, marks[1][4].end_col, "parameter end")
  end
end)

t:test("signature nulls and overload projection preserve the server response", function()
  local signature = require("era.keystroke.cmp.signature").new()
  t:defer(function()
    signature:destroy()
  end)
  local context = runtime.context("call(")
  vim.api.nvim_buf_set_lines(context.bufnr, 0, -1, false, { context.line })
  local result = vim.json.decode([[
    {"activeSignature":null,"activeParameter":null,
     "signatures":[{"label":"call(value)","parameters":null,"documentation":null}]}
  ]])
  local original = vim.deepcopy(result)
  signature:render(context, result)
  t.assert_true(vim.api.nvim_win_is_valid(assert(signature.winnr)), "nullable signature is displayed")
  t.assert_eq(0, #vim.api.nvim_buf_get_extmarks(signature.bufnr, -1, 0, -1, {}))
  t.assert_true(vim.deep_equal(original, result), "nullable response is immutable")

  result = {
    activeSignature = 1,
    activeParameter = 0,
    signatures = {
      { label = "unused()", parameters = vim.NIL, documentation = { kind = "markdown", value = "unused docs" } },
      { label = "call(😀 value)", parameters = { { label = { 8, 13 }, documentation = "parameter docs" } } },
    },
  }
  original = vim.deepcopy(result)
  signature:render(context, result)
  local bufnr = assert(signature.bufnr)
  t.assert_eq("call(😀 value)", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "selected overload")
  t.assert_eq(1, vim.api.nvim_buf_line_count(bufnr), "unselected overload and documentation are omitted")
  local mark = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, mark[2], mark[2] + 1, false)[1]
  t.assert_eq("value", line:sub(mark[3] + 1, mark[4].end_col), "UTF-16 parameter remains highlighted")
  t.assert_true(vim.deep_equal(original, result), "retrigger response retains original offsets and documentation")
end)

t:test("signature explicit null overrides the response active parameter", function()
  local signature = require("era.keystroke.cmp.signature").new()
  t:defer(function()
    signature:destroy()
  end)
  for _, example in ipairs({ { count = 1 }, { active = vim.NIL, count = 0 }, { active = 0, count = 1 } }) do
    local result = {
      activeParameter = 0,
      signatures = { { label = "call(value)", activeParameter = example.active, parameters = { { label = "value" } } } },
    }
    local before = vim.deepcopy(result)
    signature:render(runtime.context("call("), result, { "(" })
    local marks = vim.api.nvim_buf_get_extmarks(signature.bufnr, -1, 0, -1, {})
    t.assert_eq(example.count, #marks, "only a missing signature field inherits the response value")
    t.assert_true(vim.deep_equal(before, result), "explicit null remains available to retrigger requests")
  end
end)

t:test("signature ranges cover label boundaries, multiline text and mixed parameter labels", function()
  local signature = require("era.keystroke.cmp.signature").new()
  t:defer(function()
    signature:destroy()
  end)
  for _, example in ipairs({
    {
      label = "entire label",
      parameters = { { label = { 0, 12 } } },
      row = 0,
      col = 0,
      finish = 12,
      text = "entire label",
    },
    {
      label = "foo(\n  😀 value\n)",
      parameters = { { label = { 10, 15 } } },
      row = 1,
      col = 7,
      finish = 12,
      text = "value",
    },
    {
      label = "foo(a, b)",
      activeParameter = 1,
      parameters = { { label = { 4, 5 } }, { label = "b" } },
      row = 0,
      col = 7,
      finish = 8,
      text = "b",
    },
  }) do
    signature:render(runtime.context("foo("), { activeParameter = 0, signatures = { example } }, { "(", "," })
    local bufnr = assert(signature.bufnr)
    local mark = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })[1]
    t.assert_true(mark ~= nil, example.label)
    t.assert_eq(example.row, mark[2])
    t.assert_eq(example.col, mark[3])
    t.assert_eq(example.finish, mark[4].end_col)
    local line = vim.api.nvim_buf_get_lines(bufnr, mark[2], mark[2] + 1, false)[1]
    t.assert_eq(example.text, line:sub(mark[3] + 1, mark[4].end_col), "highlight covers the intended parameter")
  end
end)

t:test("plain signatures wrap wide characters and reuse only their text", function()
  local signature = require("era.keystroke.cmp.signature").new()
  t:defer(function()
    signature:destroy()
  end)
  local context = runtime.context("call(")
  vim.api.nvim_buf_set_lines(context.bufnr, 0, -1, false, { context.line })
  local width = math.min(88, vim.o.columns - 4)
  local label = "a" .. ("中"):rep(width - 1) .. "b"
  signature:render(context, { signatures = { { label = label } } })
  t.assert_eq(width, vim.api.nvim_win_get_width(signature.winnr))
  t.assert_eq(3, vim.api.nvim_win_get_height(signature.winnr), "wide characters wrap without Markdown fence rows")
  local tick = vim.api.nvim_buf_get_changedtick(signature.bufnr)
  signature:hide()
  signature:render(context, { signatures = { { label = label } } })
  t.assert_eq(tick, vim.api.nvim_buf_get_changedtick(signature.bufnr), "reopening does not rewrite identical text")
  t.assert_eq(3, vim.api.nvim_win_get_height(signature.winnr))
  signature:render(context, { signatures = { { label = "short()" } } })
  t.assert_eq(1, vim.api.nvim_win_get_height(signature.winnr), "short content has no cached or fenced padding")
end)

---@return table
local function documentation_editor()
  local Rpc = require("__test__.support.rpc")
  local root = assert(vim.uv.cwd())
  local rpc = Rpc.new(root)
  t:defer(function()
    rpc:close()
  end)
  rpc:request("nvim_ui_attach", { 100, 35, { ext_linegrid = true, rgb = true } })
  rpc:lua(
    [[
    local root=...
    vim.opt.runtimepath:prepend(root)
    package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
    local runtime=require('__test__.fixtures.era.keystroke.cmp.runtime')
    runtime.setup()
    vim.o.completeopt='menuone,noselect,popup'
    vim.o.pumborder='rounded'
    _G.cmp_doc_context=runtime.context('al')
    _G.cmp_doc=require('era.keystroke.cmp.documentation').new()
  ]],
    root
  )
  rpc:request("nvim_input", { "ial" })
  t.assert_true(
    Rpc.wait(1000, function()
      return rpc:request("nvim_get_mode", {}).mode == "i"
    end, 5),
    "insert mode"
  )
  rpc:lua([[
    vim.fn.complete(1,{{word='alpha'},{word='alpine'}})
    vim.api.nvim_select_popupmenu_item(0,false,false,{})
  ]])
  t.assert_true(
    Rpc.wait(1000, function()
      return rpc:lua([[return vim.fn.complete_info({'selected'}).selected==0]])
    end, 5),
    "native candidate selected"
  )
  t:defer(function()
    t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "native documentation has no editor errors")
  end)
  return rpc
end

---@param rpc                           table
---@return table
local function documentation_state(rpc)
  return rpc:lua([[
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
  local Rpc = require("__test__.support.rpc")
  local rpc = documentation_editor()
  for _, text in ipairs({ "Description.", "---\nDescription.", "  * * *\n\nDescription.", "___\nDescription." }) do
    rpc:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',detail='alpha(value)',documentation=...},0)]], text)
    t.assert_true(
      Rpc.wait(1000, function()
        local state = documentation_state(rpc)
        return state.visible
          and state.config.height == 3
          and vim.trim(state.screen[1]) == "alpha(value)"
          and state.screen[2] == ("─"):rep(state.config.width)
          and vim.trim(state.screen[3]) == "Description."
      end, 5),
      "three visible rows, without exposed fences or duplicate separator: " .. text
    )
    local state = documentation_state(rpc)
    t.assert_eq(state.winnr, state.native.preview_winid, "Neovim owns the info window")
    t.assert_eq(state.bufnr, state.native.preview_bufnr, "Neovim owns the info buffer")
  end
end)

t:test("LuaLS documentation displays its full signature above one native separator", function()
  local Rpc = require("__test__.support.rpc")
  local rpc = documentation_editor()
  rpc:lua([[
    local Lsp=require('era.keystroke.cmp.source.lsp')
    local client={id=9001,name='lua_ls',offset_encoding='utf-8',server_capabilities={completionProvider={}}}
    vim.lsp.get_client_by_id=function()return client end
    local item=Lsp.response(cmp_doc_context,client,{{label='alpha',detail='function',documentation={kind='markdown',
      value='```lua\nfunction alpha(value: string)\n  -> string\n```\n\n---\n\nDescription.'}}}).items[1]
    Lsp.resolve(item,function(raw)cmp_doc:show(cmp_doc_context,raw,0)end)
  ]])
  t.assert_true(
    Rpc.wait(1000, function()
      local state = documentation_state(rpc)
      return state.visible
        and state.config.height == 4
        and vim.trim(state.screen[1]) == "function alpha(value: string)"
        and vim.trim(state.screen[2]) == "-> string"
        and state.screen[3] == ("─"):rep(state.config.width)
        and vim.trim(state.screen[4]) == "Description."
    end, 5),
    "complete signature, one separator and prose use four visible rows"
  )
end)

t:test("native documentation preserves plaintext Markdown characters", function()
  local Rpc = require("__test__.support.rpc")
  local rpc = documentation_editor()
  rpc:lua([[
    cmp_doc:show(cmp_doc_context,{label='alpha',detail='alpha(value)',
      documentation={kind='plaintext',value='---\nliteral **text**\n```'}},0)
  ]])
  t.assert_true(
    Rpc.wait(1000, function()
      local state = documentation_state(rpc)
      return state.visible
        and state.config.height == 5
        and vim.trim(state.screen[3]) == "---"
        and vim.trim(state.screen[4]) == "literal **text**"
        and vim.trim(state.screen[5]) == "```"
    end, 5),
    "plaintext rules, emphasis and backticks stay literal"
  )
  for _, indented in ipairs({ "    ---", " \t---" }) do
    rpc:lua(
      [[
      cmp_doc:show(cmp_doc_context,{label='alpha',detail='alpha(value)',documentation=...},0)
    ]],
      indented
    )
    t.assert_true(
      vim.list_contains(documentation_state(rpc).content, indented),
      "indented Markdown code is not a section divider"
    )
  end
end)

t:test("native documentation wraps wide text and preserves its view through resize", function()
  local Rpc = require("__test__.support.rpc")
  local rpc = documentation_editor()
  rpc:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',documentation='a'..('中'):rep(90)..'b'},0)]])
  t.assert_true(
    Rpc.wait(1000, function()
      local state = documentation_state(rpc)
      return state.visible and table.concat(state.screen):find("b", 1, true) ~= nil
    end, 5),
    "the final character of a wrapped wide line is actually visible"
  )
  rpc:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',
    documentation=('A long documentation line with enough words to wrap after resizing.\n'):rep(60)},0)]])
  t.assert_eq(20, documentation_state(rpc).config.height, "tall content is bounded")
  rpc:lua([[cmp_doc:scroll(1);cmp_doc:scroll(1)]])
  local before = documentation_state(rpc)
  t.assert_eq(9, before.view.topline)
  rpc:request("nvim_ui_try_resize", { 40, 24 })
  t.assert_true(Rpc.wait(1000, function()
    return rpc:lua([[return vim.o.columns==40]])
  end, 5))
  rpc:lua([[cmp_doc:reposition(0)]])
  t.assert_true(
    Rpc.wait(1000, function()
      local state = documentation_state(rpc)
      return state.visible and state.config.width < before.config.width
    end, 5),
    "native info reflows into the available width"
  )
  local after = documentation_state(rpc)
  t.assert_eq(before.winnr, after.winnr, "native window is reused")
  t.assert_eq(before.view.topline, after.view.topline, "reading position is retained")
  t.assert_true(vim.deep_equal(before.content, after.content), "document text is retained")
  t.assert_true(after.position[2] + after.config.width + 2 <= 40, "border fits within the resized grid")
  rpc:lua([[vim.api.nvim_select_popupmenu_item(1,false,false,{})]])
  t.assert_true(
    Rpc.wait(1000, function()
      return not documentation_state(rpc).visible
    end, 5),
    "selection hides old info"
  )
  rpc:lua([[cmp_doc:show(cmp_doc_context,{label='alpine',documentation='short'},1)]])
  local short = documentation_state(rpc)
  t.assert_eq(1, short.config.height, "reused popup shrinks with content")
  t.assert_eq(1, short.view.topline, "new candidate begins at the top")
  rpc:lua([[vim.api.nvim_select_popupmenu_item(-1,false,true,{})]])
  t.assert_true(
    Rpc.wait(1000, function()
      local state = documentation_state(rpc)
      return not state.visible and state.native.preview_winid == nil and state.windows == 1
    end, 5),
    "native cancellation destroys its info window"
  )
end)

t:test("temporarily hidden native documentation retains its reading position", function()
  local Rpc = require("__test__.support.rpc")
  local rpc = documentation_editor()
  rpc:lua([[
    vim.fn.complete(1,{{word='alpha_'..('x'):rep(50)}})
    vim.api.nvim_select_popupmenu_item(0,false,false,{})
  ]])
  t.assert_true(
    Rpc.wait(1000, function()
      return rpc:lua([[return vim.fn.complete_info({'selected'}).selected==0]])
    end, 5),
    "wide menu selected"
  )
  rpc:lua([[
    cmp_doc:show(cmp_doc_context,{label='alpha',documentation=('Documentation line.\n'):rep(60)},0)
    cmp_doc:scroll(1);cmp_doc:scroll(1)
  ]])
  local before = documentation_state(rpc)
  t.assert_true(before.view.topline > 1, "document has been scrolled")
  rpc:request("nvim_ui_try_resize", { 60, 24 })
  t.assert_true(Rpc.wait(1000, function()
    return rpc:lua([[return vim.o.columns==60]])
  end, 5))
  rpc:lua([[cmp_doc:reposition(0)]])
  t.assert_false(documentation_state(rpc).visible, "native info has no room beside the menu")
  rpc:request("nvim_ui_try_resize", { 100, 35 })
  t.assert_true(Rpc.wait(1000, function()
    return rpc:lua([[return vim.o.columns==100]])
  end, 5))
  rpc:lua([[cmp_doc:reposition(0)]])
  local after = documentation_state(rpc)
  t.assert_true(after.visible, "native info is visible again")
  t.assert_eq(before.winnr, after.winnr, "native window retains its identity while hidden")
  t.assert_eq(before.view.topline, after.view.topline, "temporary hiding does not reset the reading position")
end)

t:test("native documentation scrolls inside a wrapped paragraph without moving the input cursor", function()
  local Rpc = require("__test__.support.rpc")
  local rpc = documentation_editor()
  rpc:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',documentation=('word '):rep(1000)},0)]])
  local cursor = rpc:request("nvim_win_get_cursor", { 0 })
  rpc:lua([[cmp_doc:scroll(1)]])
  t.assert_true(
    Rpc.wait(1000, function()
      local state = documentation_state(rpc)
      return state.visible and state.view.topline == 1 and state.view.skipcol > 0
    end, 5),
    "native smooth scrolling reveals the rest of a single long paragraph"
  )
  t.assert_true(vim.deep_equal(cursor, rpc:request("nvim_win_get_cursor", { 0 })), "input cursor is unchanged")
  t.assert_eq("ic", rpc:request("nvim_get_mode", {}).mode, "native completion remains active in Insert mode")
  rpc:lua([[cmp_doc:scroll(-1)]])
  t.assert_true(
    Rpc.wait(1000, function()
      return documentation_state(rpc).view.skipcol == 0
    end, 5),
    "scrolling back reaches the paragraph start"
  )
end)

t:test("empty documentation and disappearing sections leave no stale separator", function()
  local Rpc = require("__test__.support.rpc")
  local rpc = documentation_editor()
  for _, raw in ipairs({
    { label = "empty", detail = vim.NIL, documentation = vim.NIL },
    { label = "empty", documentation = { kind = "markdown", value = vim.NIL } },
  }) do
    rpc:lua([[cmp_doc:show(cmp_doc_context,...,0)]], raw)
    t.assert_false(documentation_state(rpc).visible)
  end
  for _, raw in ipairs({
    { label = "docs", documentation = "Documentation without a header." },
    { label = "detail", detail = "Header without documentation." },
    { label = "blank", detail = "Header with empty documentation.", documentation = " \n\t" },
    { label = "truncated", detail = ("header\n"):rep(1001), documentation = "Outside the line limit." },
  }) do
    rpc:lua([[cmp_doc:show(cmp_doc_context,{label='alpha',detail='header',documentation='description'},0)]])
    rpc:lua([[cmp_doc:show(cmp_doc_context,...,0)]], raw)
    t.assert_true(
      Rpc.wait(1000, function()
        local state = documentation_state(rpc)
        return state.visible and not vim.list_contains(state.screen, ("─"):rep(state.config.width))
      end, 5),
      "no stale separator for " .. raw.label
    )
    t.assert_true(#documentation_state(rpc).content <= 1000, "long content is bounded")
  end
  rpc:lua([[cmp_doc:show(cmp_doc_context,{label='empty'},0)]])
  t.assert_false(documentation_state(rpc).visible, "empty info hides the native window")
end)

t:test("native menu renders and scrolls without menu or scrollbar windows", function()
  local Rpc = require("__test__.support.rpc")
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
    local items = {}
    for index = 1, 40 do
      items[index] = {label=string.format('alpha_candidate_%02d',index),kind=6,sortText=string.format('%02d',index)}
    end
    require('__test__.fixtures.era.keystroke.cmp.behavior').setup({engine='era',items=items})
    vim.o.pumblend = 0
    for name, colors in pairs({
      Pmenu={fg=0xcccccc,bg=0x1f1f1f}, PmenuBorder={fg=0x2b2b2b,bg=0x1f1f1f},
      PmenuSel={fg=0xffffff,bg=0x0078d4}, PmenuThumb={bg=0x2b2b2b}, PmenuSbar={bg=0x101010},
    }) do vim.api.nvim_set_hl(0,name,colors) end
  ]],
    root
  )
  rpc:request("nvim_input", { "ial" })

  ---@return table
  local function screen()
    local state = rpc:lua([[
      local geometry = vim.fn.pum_getpos()
      local rows, cells = {}, {}
      if vim.fn.pumvisible() == 1 then
        for row = math.max(1, geometry.row), math.min(vim.o.lines, geometry.row + geometry.height + 3) do
          local text = {}
          for col = math.max(1, geometry.col), math.min(vim.o.columns, geometry.col + geometry.width + 4) do
            text[#text + 1] = vim.fn.screenstring(row,col)
            cells[#cells + 1] = {row=row,col=col,attribute=vim.fn.screenattr(row,col)}
          end
          rows[#rows + 1] = table.concat(text)
        end
      end
      return {geometry=geometry,rows=rows,cells=cells,selected=vim.fn.complete_info({'selected'}).selected,windows=#vim.api.nvim_list_wins()}
    ]])
    local attributes = {}
    for _, event in ipairs(rpc.notifications) do
      if event.method == "redraw" then
        for _, update in ipairs(event.args) do
          if update[1] == "hl_attr_define" then
            for index = 2, #update do
              attributes[update[index][1]] = update[index][2]
            end
          end
        end
      end
    end
    state.thumb = {}
    for _, cell in ipairs(state.cells) do
      if (attributes[cell.attribute] or {}).background == 0x2b2b2b then
        state.thumb[#state.thumb + 1] = cell
      end
    end
    return state
  end

  t.assert_true(
    Rpc.wait(1000, function()
      local state = screen()
      return state.selected == 0 and #state.thumb > 0 and table.concat(state.rows):find("alpha_candidate_01", 1, true)
    end, 5),
    "native text, selection and scrollbar reach the actual screen"
  )
  local first = screen()
  t.assert_eq(40, first.geometry.size, "native PUM owns the candidate list")
  t.assert_eq(10, first.geometry.height, "native height limit")
  t.assert_eq(1, first.windows, "menu and scrollbar need no floating windows")
  rpc:request("nvim_input", { ("<C-j>"):rep(39) })
  t.assert_true(
    Rpc.wait(1000, function()
      local state = screen()
      return state.selected == 39 and #state.thumb > 0 and state.thumb[1].row > first.thumb[1].row
    end, 5),
    "native thumb and viewport follow selection"
  )
  rpc:request("nvim_ui_try_resize", { 25, 25 })
  t.assert_true(
    Rpc.wait(1000, function()
      local state = screen()
      return state.geometry.width ~= nil and state.geometry.width < first.geometry.width and #state.thumb > 0
    end, 5),
    "native menu clips to the resized screen"
  )
  rpc:lua([[require('era.keystroke.cmp').cancel()]])
  t.assert_true(
    Rpc.wait(1000, function()
      return rpc:lua([[return vim.fn.pumvisible()==0 and vim.api.nvim_get_current_line()=='al']])
    end, 5),
    "native cancellation restores the typed prefix"
  )
  rpc:lua([[
    require('__test__.fixtures.era.keystroke.cmp.behavior').items = {{label='alpha_short',kind=6}}
    require('era.keystroke.cmp').show()
  ]])
  t.assert_true(
    Rpc.wait(1000, function()
      local state = screen()
      return state.geometry.size == 1 and state.geometry.scrollbar == false and #state.thumb == 0
    end, 5),
    "short lists have no scrollbar"
  )
  t.assert_eq(1, screen().windows, "window count remains stable")
  t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "no editor errors")
end)

t:test("external command lines anchor native menu text, selection and closure to the UI", function()
  local root = assert(vim.uv.cwd())
  local rpc = require("__test__.support.rpc").new(root)
  t:defer(function()
    rpc:close()
  end)
  rpc:request("nvim_ui_attach", {
    120,
    40,
    { ext_linegrid = true, ext_multigrid = true, ext_cmdline = true, rgb = true },
  })
  rpc:lua(
    [[
    local root = ...
    vim.opt.runtimepath:prepend(root)
    package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
    require('__test__.fixtures.era.keystroke.cmp.runtime').setup()
    vim.api.nvim_create_user_command('CmpScreen', function() end, {
      nargs = '*', complete = function()
        local items = { 'alpha', 'alpine' }
        for index = 3, 40 do items[index] = string.format('alzzz%02d', index) end
        return items
      end,
    })
    require('era.keystroke.cmp').setup()
    vim.api.nvim_set_hl(0, 'PmenuSel', { fg = '#ffffff', bg = '#0078d4' })
    vim.api.nvim_set_hl(0, 'CmpLabelMatch', { fg = '#0078d4', bold = true })
    vim.api.nvim_set_hl(0, 'PmenuThumb', { bg = '#2b2b2b' })
    -- An external command-line UI supplies the native renderer with its window anchor.
    vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
      relative='editor',row=5,col=10,width=90,height=1,style='minimal',border='none',
      focusable=false,zindex=200,_cmdline_offset=0,
    })
  ]],
    root
  )
  local menu_grid
  local attributes, lines, positioned, widths = {}, {}, {}, {}
  local seen, flushes = 0, 0

  ---@return nil
  local function receive()
    for index = seen + 1, #rpc.notifications do
      local event = rpc.notifications[index]
      if event.method == "redraw" then
        for _, update in ipairs(event.args) do
          for _, args in ipairs(vim.list_slice(update, 2)) do
            if update[1] == "hl_attr_define" then
              attributes[args[1]] = args[2]
            elseif update[1] == "grid_resize" then
              widths[args[1]] = args[2]
            elseif update[1] == "win_float_pos" then
              positioned[args[1]] = args
            elseif update[1] == "grid_destroy" or update[1] == "win_close" or update[1] == "win_hide" then
              positioned[args[1]] = nil
            elseif update[1] == "grid_line" then
              lines[args[1]] = lines[args[1]] or {}
              local row = lines[args[1]][args[2]] or {}
              lines[args[1]][args[2]] = row
              local col, highlight = args[3], 0
              for _, cell in ipairs(args[4]) do
                highlight = cell[2] or highlight
                for _ = 1, cell[3] or 1 do
                  row[col + 1] = { text = cell[1], highlight = highlight }
                  col = col + 1
                end
              end
            elseif update[1] == "flush" then
              flushes = flushes + 1
            end
          end
        end
      end
    end
    seen = #rpc.notifications
  end

  rpc:request("nvim_input", { ":CmpScreen al" })
  t.wait_until(function()
    receive()
    for grid, rows in pairs(lines) do
      for _, row in pairs(rows) do
        local text = {}
        for _, cell in ipairs(row) do
          text[#text + 1] = cell.text
        end
        if positioned[grid] and table.concat(text):find("alpha", 1, true) then
          menu_grid = grid
        end
      end
    end
    return menu_grid ~= nil and flushes > 0
  end, 1500, "menu reaches the UI without another key or forced redraw")
  local previous_flushes = flushes
  rpc:request("nvim_input", { "<Tab>" })
  t.wait_until(function()
    receive()
    if flushes <= previous_flushes then
      return false
    end
    for _, row in pairs(lines[menu_grid]) do
      for _, cell in ipairs(row) do
        local highlight = attributes[cell.highlight] or {}
        if cell.text == "a" and highlight.foreground == 0xffffff and highlight.background == 0x0078d4 then
          return true
        end
      end
    end
    return false
  end, 1500, "selection colors reach the UI")
  ---@return integer|nil
  local function thumb_row()
    local first
    for index, row in pairs(lines[menu_grid]) do
      for _, cell in pairs(row) do
        if (attributes[cell.highlight] or {}).background == 0x2b2b2b then
          first = math.min(first or index, index)
        end
      end
    end
    return first
  end
  local scrollbar_row = assert(thumb_row(), "native menu grid includes its scrollbar")
  rpc:request("nvim_input", { ("<Tab>"):rep(39) })
  t.wait_until(function()
    receive()
    local row = thumb_row()
    return row ~= nil and row > scrollbar_row
  end, 1500, "scrollbar moves inside the native command-line menu grid")
  rpc:request("nvim_input", { "<C-e>" })
  t.wait_until(function()
    receive()
    return not positioned[menu_grid]
  end, 1500, "native menu disappears from the UI")
  t.assert_eq("CmpScreen al", rpc:lua("return vim.fn.getcmdline()"), "cancel restores the query")
  t.assert_eq("c", rpc:request("nvim_get_mode", {}).mode, "command line remains active")
  t.assert_eq("", rpc:lua("return vim.v.errmsg"), "no editor errors")
end)

t:test("dressing registers native completion anchors on the first command and after a concealed prefix", function()
  local Rpc = require("__test__.support.rpc")
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
    package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
    require('__test__.fixtures.era.keystroke.cmp.runtime').setup()
    stl.string=require('stl.string')
    dot.var=require('dot.var')
    local cmdline=require('era.dressing.ui_attach.cmdline')
    vim.ui_attach(vim.api.nvim_create_namespace('cmp-native-anchor-test'),{ext_messages=true},function(event,...)
      local name=event:match('^cmdline_(.*)$')
      local handler=name and cmdline[name]
      if handler then
        local task={event=event,args={...}}
        if vim.in_fast_event() then vim.schedule(function() handler(task) end) else handler(task) end
        return true
      end
      if event:match('^msg_') then return true end
    end)
    require('era.keystroke.cmp').setup()
  ]],
    root
  )
  for _, query in ipairs({ "set nu", "lua vim.api.nvim_get_cu" }) do
    rpc:request("nvim_input", { ":" .. query })
    t.assert_true(
      Rpc.wait(1000, function()
        return rpc:lua([[return vim.fn.pumvisible()==1]])
      end, 5),
      "native popup appears after the real command-line renderer creates its anchor"
    )
    local state = rpc:lua([[
      local active=require('era.dressing.ui_attach.state').get_active_cmdline()
      local config=vim.api.nvim_win_get_config(active.winnr)
      local geometry=vim.fn.pum_getpos()
      return {config=config,geometry=geometry,text=vim.fn.screenstring(geometry.row+2,geometry.col+2)}
    ]])
    t.assert_eq(5, state.geometry.row, "popup follows the floating command line")
    t.assert_true(state.config.zindex < 250, "native command-line popup stays above its anchor")
    if query:sub(1, 3) == "lua" then
      t.assert_true(state.config._cmdline_offset < 0, "hidden command prefix is accounted for")
    end
    t.assert_true(state.text ~= "", "native popup reaches the screen")
    rpc:request("nvim_input", { "<C-e>" })
    t.assert_true(
      Rpc.wait(1000, function()
        return rpc:lua([[return vim.fn.pumvisible()==0]])
      end, 5),
      "cancel does not schedule another automatic completion"
    )
    t.assert_eq(query, rpc:lua([[return vim.fn.getcmdline()]]), "typed command is preserved")
    rpc:request("nvim_input", { "<Esc>" })
    t.assert_true(
      Rpc.wait(1000, function()
        return rpc:request("nvim_get_mode", {}).mode == "n"
      end, 5),
      "command line closes"
    )
  end
  t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "no editor errors")
end)

t:run()
