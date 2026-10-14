---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.keystroke.cmp.viewport" ---@type string

local harness = require("__test__.support.harness")
local Rpc = require("__test__.support.rpc")
local t = harness.new("era.keystroke.cmp.viewport")

---@param predicate                     fun(): boolean
---@param timeout                       integer
---@param message                       string
---@return nil
local function wait(predicate, timeout, message)
  local deadline = vim.uv.hrtime() + timeout * 1000000
  -- RPC pumps its own event loop; keep the deadline outside nested vim.wait predicates.
  repeat
    if predicate() then
      return
    end
    vim.wait(5)
  until vim.uv.hrtime() >= deadline
  error(message, 2)
end

---@param signature                     ?boolean
---@param layout                        ?"split"|"three"
---@param horizontal                    ?boolean
---@return table
local function editor(signature, layout, horizontal)
  local root = assert(vim.uv.cwd())
  local rpc = Rpc.new(root)
  t:defer(function()
    rpc:close()
  end)
  rpc:request(
    "nvim_ui_attach",
    { 120, layout == "three" and 60 or 40, { ext_linegrid = true, ext_multigrid = true, rgb = true } }
  )
  rpc:lua(
    [[
    local root, signature, layout, horizontal = ...
    vim.opt.runtimepath:prepend(root)
    package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
    if layout ~= '' then
      local source = vim.api.nvim_get_current_win()
      vim.cmd(layout == 'three' and 'aboveleft 12split' or 'aboveleft 8split')
      _G.viewport_other = vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_win(source)
      if layout == 'three' then
        vim.cmd('belowright 12split')
        vim.api.nvim_set_current_win(source)
      end
    end
    local lines = {}
    for index = 1, 100 do lines[index] = '' end
    if horizontal then lines[50] = (' '):rep(150) .. ('x'):rep(200) end
    require('__test__.fixtures.era.keystroke.cmp.behavior').setup({
      engine = 'era', lines = lines, cursor = {50, horizontal and 150 or 0}, signature = signature,
      documentation = ('A long documentation line with enough words to wrap after resizing the editor.\n'):rep(60),
    })
    vim.wo.wrap = not horizontal
    vim.fn.winrestview({ topline = 40, leftcol = horizontal and 100 or 0 })
    vim.o.mouse = 'a'
    _G.viewport_calls = {query=0, prepare=0, rank=0}
    for _, entry in ipairs({
      {'era.keystroke.cmp.source.lsp', 'complete', 'query'},
      {'era.keystroke.cmp.rank', 'prepare', 'prepare'},
      {'era.keystroke.cmp.rank', 'filter', 'rank'},
    }) do
      local module, name, key = require(entry[1]), entry[2], entry[3]
      local original = module[name]
      module[name] = function(...)
        viewport_calls[key] = viewport_calls[key] + 1
        return original(...)
      end
    end
    _G.viewport_snapshot = function()
      local fixture = require('__test__.fixtures.era.keystroke.cmp.behavior')
      local session = fixture.session
      local windows = {}
      if session then
        for _, name in ipairs({'documentation', 'signature'}) do
          local window = session[name]
          if window.winnr and vim.api.nvim_win_is_valid(window.winnr) then
            windows[name] = {
              position=vim.api.nvim_win_get_position(window.winnr),
              config=vim.api.nvim_win_get_config(window.winnr),
              view=vim.api.nvim_win_call(window.winnr, vim.fn.winsaveview),
              tick=vim.api.nvim_buf_get_changedtick(window.bufnr),
              text=table.concat(vim.api.nvim_buf_get_lines(window.bufnr,0,-1,false),'\n'),
            }
          end
        end
      end
      if session and session:is_visible() then
        local geometry = vim.fn.pum_getpos()
        windows.menu = {
          position = { geometry.row, geometry.col }, config = geometry,
          items = vim.fn.complete_info({'items'}).items,
        }
      end
      local cursor = vim.api.nvim_win_get_cursor(fixture.winnr)
      local start_col = session and session.context and session.context.start_col or cursor[2]
      return {
        cursor=cursor, anchor=vim.fn.screenpos(fixture.winnr, cursor[1], start_col + 1),
        windows=windows, calls=viewport_calls, requests=#fixture.requests,
        source_position=vim.api.nvim_win_get_position(fixture.winnr),
        source_height=vim.api.nvim_win_get_height(fixture.winnr),
        columns=vim.o.columns, lines=vim.o.lines, state=fixture.snapshot(),
      }
    end
  ]],
    root,
    signature == true,
    layout or "",
    horizontal == true
  )
  rpc:request("nvim_input", { signature and "idemo(" or "ial" })
  wait(function()
    local state = rpc:lua("return viewport_snapshot()")
    return signature and state.windows.signature ~= nil or not signature and state.windows.documentation ~= nil
  end, 2000, "completion presentation is visible")
  t:defer(function()
    local state = rpc:lua("return viewport_snapshot().state")
    t.assert_eq("", state.errmsg, "no editor error")
    t.assert_eq(0, #state.notices, "no completion diagnostic")
  end)
  return rpc
end

---@param rpc                           table
---@return table
local function snapshot(rpc)
  return rpc:lua("return viewport_snapshot()")
end

---@param before                        table
---@param after                         table
---@return nil
local function unchanged_completion(before, after)
  t.assert_true(vim.deep_equal(before.cursor, after.cursor), "source cursor is unchanged")
  t.assert_true(vim.deep_equal(before.calls, after.calls), "viewport changes do not query, prepare or rank")
  t.assert_eq(before.requests, after.requests, "no completion, resolve or signature request")
  t.assert_true(vim.deep_equal(before.state.labels, after.state.labels), "candidate order is preserved")
  t.assert_eq(before.state.selected, after.state.selected, "selection is preserved")
end

t:test("source viewport changes move native completion and preserve the documentation view", function()
  local rpc = editor()
  rpc:request("nvim_input", { "<Tab>" })
  wait(function()
    local lines = snapshot(rpc).state.documentation_lines
    return type(lines) == "table" and lines[1] == "alpine"
  end, 1000, "the previewed candidate's documentation is ready")
  rpc:request("nvim_input", { "<C-f>" })
  wait(function()
    return snapshot(rpc).windows.documentation.view.topline > 1
  end, 1000, "documentation is scrolled")
  local before = snapshot(rpc)
  rpc:lua([[vim.fn.winrestview({ topline = vim.fn.line("w0") + 3 })]])
  wait(function()
    local after = snapshot(rpc)
    return after.anchor.row ~= before.anchor.row and after.windows.menu.position[1] == after.anchor.row
  end, 1000, "menu follows the source viewport without another key")
  local after = snapshot(rpc)
  local delta = after.anchor.row - before.anchor.row
  t.assert_eq(before.windows.documentation.position[1] + delta, after.windows.documentation.position[1])
  t.assert_eq(before.windows.documentation.view.topline, after.windows.documentation.view.topline)
  t.assert_eq(before.windows.documentation.view.skipcol, after.windows.documentation.view.skipcol)
  t.assert_eq(before.windows.documentation.text, after.windows.documentation.text, "documentation text is untouched")
  t.assert_true(vim.deep_equal(before.windows.menu.items, after.windows.menu.items), "native candidates are untouched")
  unchanged_completion(before, after)
end)

t:test("signature follows scrolling while the completion menu is closed", function()
  local rpc = editor(true)
  local before = snapshot(rpc)
  t.assert_nil(before.windows.menu)
  rpc:request("nvim_input_mouse", { "wheel", "down", "", 0, 35, 115 })
  wait(function()
    local after = snapshot(rpc)
    return after.anchor.row ~= before.anchor.row
      and after.windows.signature.position[1] ~= before.windows.signature.position[1]
  end, 1000, "signature follows the source viewport independently")
  local after = snapshot(rpc)
  t.assert_eq(
    before.windows.signature.position[1] + after.anchor.row - before.anchor.row,
    after.windows.signature.position[1]
  )
  t.assert_eq(before.windows.signature.tick, after.windows.signature.tick)
  unchanged_completion(before, after)
end)

t:test("horizontal scrolling follows the completion anchor without changing its byte range", function()
  local rpc = editor(false, nil, true)
  local before = snapshot(rpc)
  rpc:lua([[vim.fn.winrestview({ leftcol = vim.fn.winsaveview().leftcol + 6 })]])
  wait(function()
    local after = snapshot(rpc)
    return after.anchor.col ~= before.anchor.col and after.windows.menu.position[2] ~= before.windows.menu.position[2]
  end, 1000, "menu follows horizontal source scrolling")
  local after = snapshot(rpc)
  t.assert_eq(before.windows.menu.position[2] + after.anchor.col - before.anchor.col, after.windows.menu.position[2])
  t.assert_eq(before.windows.menu.position[1], after.windows.menu.position[1])
  t.assert_true(vim.deep_equal(before.windows.menu.items, after.windows.menu.items), "native candidates are untouched")
  unchanged_completion(before, after)
end)

t:test("editor resize reflows documentation without resetting its view or refreshing candidates", function()
  local rpc = editor()
  rpc:request("nvim_input", { "<C-f>" })
  wait(function()
    return snapshot(rpc).windows.documentation.view.topline > 1
  end, 1000, "documentation is scrolled")
  local before = snapshot(rpc)
  rpc:request("nvim_ui_try_resize", { 70, 35 })
  wait(function()
    local after = snapshot(rpc)
    return after.columns == 70
      and after.lines == 35
      and after.windows.documentation.config.width < before.windows.documentation.config.width
  end, 1000, "documentation width follows the resized editor")
  local after = snapshot(rpc)
  for _, window in pairs(after.windows) do
    t.assert_true(window.position[1] + window.config.height + 2 <= after.lines, "window fits vertically")
    t.assert_true(window.position[2] + window.config.width + 2 <= after.columns, "window fits horizontally")
  end
  t.assert_eq(before.windows.documentation.view.topline, after.windows.documentation.view.topline)
  t.assert_eq(before.windows.documentation.text, after.windows.documentation.text)
  unchanged_completion(before, after)
end)

t:test("split resize moves the menu without changing the editor grid or rebuilding its contents", function()
  local rpc = editor(false, "split")
  local before = snapshot(rpc)
  rpc:lua("vim.api.nvim_win_set_height(viewport_other, 12)")
  wait(function()
    local after = snapshot(rpc)
    return after.anchor.row ~= before.anchor.row and after.windows.menu.position[1] == after.anchor.row
  end, 1000, "menu follows the resized source window")
  local after = snapshot(rpc)
  t.assert_eq(before.lines, after.lines)
  t.assert_eq(before.columns, after.columns)
  t.assert_true(vim.deep_equal(before.windows.menu.items, after.windows.menu.items), "native candidates are untouched")
  unchanged_completion(before, after)
end)

t:test("neighboring splits reposition completion when the source retains its height", function()
  local rpc = editor(false, "three")
  rpc:request("nvim_input", { "<Tab>" })
  wait(function()
    local lines = snapshot(rpc).state.documentation_lines
    return type(lines) == "table" and lines[1] == "alpine"
  end, 1000, "preview documentation is ready")
  rpc:request("nvim_input", { "<C-f>" })
  wait(function()
    return snapshot(rpc).windows.documentation.view.topline > 1
  end, 1000, "documentation is scrolled")
  local before = snapshot(rpc)
  rpc:lua([[
    local source = require('__test__.fixtures.era.keystroke.cmp.behavior').winnr
    local height = vim.api.nvim_win_get_height(source)
    vim.api.nvim_win_set_height(viewport_other, vim.api.nvim_win_get_height(viewport_other) + 4)
    vim.api.nvim_win_set_height(source, height)
  ]])
  wait(function()
    local after = snapshot(rpc)
    return after.anchor.row ~= before.anchor.row and after.windows.menu.position[1] == after.anchor.row
  end, 1000, "menu follows the layout even when the source is absent from WinResized.windows")
  local after = snapshot(rpc)
  t.assert_eq(before.source_height, after.source_height, "source height is unchanged")
  t.assert_eq(before.source_position[1] + 4, after.source_position[1], "neighboring splits moved the source")
  t.assert_eq(before.windows.documentation.position[1] + 4, after.windows.documentation.position[1])
  t.assert_eq(before.windows.documentation.view.topline, after.windows.documentation.view.topline)
  t.assert_true(vim.deep_equal(before.windows.menu.items, after.windows.menu.items), "native candidates are untouched")
  t.assert_eq(before.windows.documentation.text, after.windows.documentation.text)
  unchanged_completion(before, after)
end)

t:test("editor resize reflows signature help without an open completion menu", function()
  local rpc = editor(true)
  local before = snapshot(rpc)
  t.assert_nil(before.windows.menu)
  rpc:request("nvim_ui_try_resize", { 20, 20 })
  wait(function()
    local after = snapshot(rpc)
    return after.columns == 20 and after.windows.signature.config.width < before.windows.signature.config.width
  end, 1000, "standalone signature follows the resized editor")
  local after = snapshot(rpc)
  local window = after.windows.signature
  t.assert_true(window.config.height > before.windows.signature.config.height, "signature wraps at the narrower width")
  t.assert_true(window.position[1] + window.config.height + 2 <= after.lines)
  t.assert_true(window.position[2] + window.config.width + 2 <= after.columns)
  t.assert_eq(before.windows.signature.tick, window.tick)
  unchanged_completion(before, after)
end)

t:run()
