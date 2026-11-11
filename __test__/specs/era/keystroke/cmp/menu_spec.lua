local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")
local embedded = require("__test__.support.cmp.embedded")
local t = harness.new()

---@param ui                            __test__.support.UI
---@param grid                          table
---@param selected                      integer
---@param deprecated                    ?boolean
---@return nil
local function assert_matches(ui, grid, selected, deprecated)
  local matches = embedded.menu(ui, grid).matches
  t.assert_eq(4, #matches, "both displayed candidates highlight their nonadjacent a/p")
  embedded.assert_matches(t, matches, selected)
  if deprecated then
    for _, cell in ipairs(matches) do
      t.assert_true(cell.style.strikethrough, "deprecated markers retain their strike-through")
    end
  end
end

t:test("native menu highlights subsequences and scrolls without menu or scrollbar windows", function()
  local items = {} ---@type table[]
  for index = 1, 40 do
    items[index] =
      { label = string.format("alpha_candidate_%02d", index), kind = 6, sortText = string.format("%02d", index) }
  end
  local ui, grid = embedded.behavior_editor(t, { items = items })
  ui:lua([[
    vim.o.pumblend = 0
    for name, colors in pairs({
      Pmenu={fg=0xcccccc,bg=0x1f1f1f}, PmenuBorder={fg=0x2b2b2b,bg=0x1f1f1f},
      PmenuSel={fg=0xffffff,bg=0x0078d4}, PmenuThumb={bg=0x2b2b2b}, PmenuSbar={bg=0x101010},
      PmenuMatch={fg=0xf5a9b8,bold=true,italic=true}, PmenuMatchSel={link='PmenuMatch'},
    }) do vim.api.nvim_set_hl(0,name,colors) end
  ]])
  ui:rpc("nvim_input", "iap")

  ui:wait_until(function()
    local state = embedded.menu(ui, grid)
    return state.selected == 0 and #state.thumb > 0 and table.concat(state.rows):find("alpha_candidate_01", 1, true)
  end, 5000, "native text, selection and scrollbar reach the actual screen")
  local first = embedded.menu(ui, grid)
  t.assert_eq(40, first.geometry.size, "native PUM owns the candidate list")
  t.assert_eq(10, first.geometry.height, "native height limit")
  t.assert_eq(1, first.windows, "menu and scrollbar need no floating windows")
  t.assert_eq(20, #first.matches, "two nonadjacent matched letters on each visible row")
  embedded.assert_matches(t, first.matches, 0)
  for index = 2, #first.matches, 2 do
    t.assert_eq(2, first.matches[index].col - first.matches[index - 1].col, "the intervening letter is not highlighted")
  end
  ui:rpc("nvim_input", ("<C-j>"):rep(39))
  ui:wait_until(function()
    local state = embedded.menu(ui, grid)
    return state.selected == 39 and #state.thumb > 0 and state.thumb[1].row > first.thumb[1].row
  end, 5000, "native thumb and viewport follow selection")
  ui:rpc("nvim_ui_try_resize", 25, 25)
  ui:wait_until(function()
    local state = embedded.menu(ui, grid)
    return state.geometry.width ~= nil and state.geometry.width < first.geometry.width and #state.thumb > 0
  end, 5000, "native menu clips to the resized screen")
  ui:lua([[require('era.keystroke.cmp').cancel()]])
  ui:wait_until(function()
    return ui:lua([[return vim.fn.pumvisible()==0 and vim.api.nvim_get_current_line()=='ap']])
  end, 5000, "native cancellation restores the typed prefix")
  ui:lua([[
    require('__test__.support.cmp.behavior').items = {{label='alpha_short',kind=6}}
    require('era.keystroke.cmp').show()
  ]])
  ui:wait_until(function()
    local state = embedded.menu(ui, grid)
    return state.geometry.size == 1 and state.geometry.scrollbar == false and #state.thumb == 0
  end, 5000, "short lists have no scrollbar")
  t.assert_eq(1, embedded.menu(ui, grid).windows, "window count remains stable")
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
end)

for _, prefix in ipairs({ "obj.", "😀 obj." }) do
  t:test("wide LSP edits highlight and restore the keyword after " .. prefix, function()
    local items = {}
    for _, label in ipairs({ "alpha_one", "alpha_two" }) do
      items[#items + 1] = {
        label = label,
        textEdit = {
          range = {
            start = { line = 0, character = 0 },
            ["end"] = {
              line = 0,
              character = vim.str_utfindex(prefix .. "ap", "utf-16"),
            },
          },
          newText = prefix .. label,
        },
      }
    end
    local ui, grid = embedded.themed_editor(t, { lines = { prefix }, items = items })
    ui:rpc("nvim_input", "Aap")
    embedded.wait(t, ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "ranked menu")
    assert_matches(ui, grid, 0)
    ui:rpc("nvim_input", "<C-j>")
    embedded.wait(
      t,
      ui,
      "return vim.api.nvim_get_current_line() == " .. string.format("%q", prefix .. "alpha_two"),
      "wide edit previews its suffix without duplicating the namespace"
    )
    assert_matches(ui, grid, 1)
    ui:rpc("nvim_input", "<C-e>")
    embedded.wait(
      t,
      ui,
      "return vim.fn.pumvisible() == 0 and vim.api.nvim_get_current_line() == " .. string.format("%q", prefix .. "ap"),
      "cancellation restores the original keyword"
    )
    ui:rpc("nvim_input", "<C-Space>")
    embedded.wait(t, ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "reopened menu")
    if prefix == "obj." then
      ui:rpc("nvim_input", "<C-y>")
    else
      ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,true,{})]])
    end
    embedded.wait(
      t,
      ui,
      "return vim.fn.pumvisible() == 0 and vim.api.nvim_get_current_line() == "
        .. string.format("%q", prefix .. "alpha_one"),
      "acceptance applies the complete LSP edit"
    )
  end)
end

t:test("mixed LSP filter ranges share a highlighted query suffix", function()
  local range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 6 } }
  local ui, grid = embedded.themed_editor(t, {
    lines = { "obj." },
    items = {
      { label = "alpha_one", textEdit = { range = range, newText = "obj.alpha_one" } },
      { label = "obj.alpha_two", textEdit = { range = range, newText = "obj.alpha_two" } },
    },
  })
  ui:rpc("nvim_input", "Aap")
  embedded.wait(t, ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "mixed filter queries")
  assert_matches(ui, grid, 0)
end)

t:test("both deprecated markers keep pink matches on selected and unselected rows", function()
  local ui, grid = embedded.themed_editor(
    t,
    { items = { { label = "alpha_one", deprecated = true }, { label = "alpha_two", tags = { 1 } } } }
  )
  ui:rpc("nvim_input", "iap")
  embedded.wait(t, ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "deprecated menu")
  assert_matches(ui, grid, 0, true)
  ui:rpc("nvim_input", "<C-j>")
  embedded.wait(t, ui, [[return vim.fn.complete_info({'selected'}).selected == 1]], "selected tagged candidate")
  assert_matches(ui, grid, 1, true)
end)

t:test("external command lines anchor native menu text, selection and closure to the UI", function()
  local ui = UI.open(t)
  local grid = Grid.new(ui)
  ui:start({ width = 120, height = 40, ui = { ext_multigrid = true, ext_cmdline = true } })
  ui:lua([[
    require('__test__.support.cmp.runtime').setup()
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
  ]])
  local menu_grid

  ---@return integer|nil
  local function find_menu()
    for gridnr, screen in pairs(grid.grids) do
      if grid.floats[gridnr] then
        for _, cells in ipairs(screen.rows) do
          local text = {}
          for _, cell in ipairs(cells) do
            text[#text + 1] = cell[1]
          end
          if table.concat(text):find("alpha", 1, true) then
            return gridnr
          end
        end
      end
    end
  end

  ui:rpc("nvim_input", ":CmpScreen al")
  t.wait_until(function()
    menu_grid = find_menu()
    return menu_grid ~= nil and grid.flushes > 0
  end, 5000, "menu reaches the UI without another key or forced redraw")
  local previous_flushes = grid.flushes
  ui:rpc("nvim_input", "<Tab>")
  t.wait_until(function()
    if grid.flushes <= previous_flushes then
      return false
    end
    for _, cells in ipairs(grid.grids[menu_grid].rows) do
      for _, cell in ipairs(cells) do
        local highlight = grid.highlights[cell[2]] or {}
        if cell[1] == "a" and highlight.foreground == 0xffffff and highlight.background == 0x0078d4 then
          return true
        end
      end
    end
    return false
  end, 5000, "selection colors reach the UI")
  ---@return integer|nil
  local function thumb_row()
    for index, cells in ipairs(grid.grids[menu_grid].rows) do
      for _, cell in ipairs(cells) do
        if (grid.highlights[cell[2]] or {}).background == 0x2b2b2b then
          return index
        end
      end
    end
  end
  local scrollbar_row = assert(thumb_row(), "native menu grid includes its scrollbar")
  ui:rpc("nvim_input", ("<Tab>"):rep(39))
  t.wait_until(function()
    local row = thumb_row()
    return row ~= nil and row > scrollbar_row
  end, 5000, "scrollbar moves inside the native command-line menu grid")
  ui:rpc("nvim_input", "<C-e>")
  t.wait_until(function()
    return not grid.floats[menu_grid]
  end, 5000, "native menu disappears from the UI")
  t.assert_eq("CmpScreen al", ui:lua("return vim.fn.getcmdline()"), "cancel restores the query")
  t.assert_eq("c", ui:rpc("nvim_get_mode").mode, "command line remains active")
  t.assert_eq("", ui:lua("return vim.v.errmsg"), "no editor errors")
end)

t:test("dressing registers native completion anchors on the first command and after a concealed prefix", function()
  local ui = UI.open(t, { width = 100, height = 35 })
  ui:lua([[
    require('__test__.support.cmp.runtime').setup()
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
  ]])
  for _, query in ipairs({ "set nu", "lua vim.api.nvim_get_cu" }) do
    ui:rpc("nvim_input", ":" .. query)
    ui:wait_until(function()
      return ui:lua([[return vim.fn.pumvisible()==1]])
    end, 5000, "native popup appears after the real command-line renderer creates its anchor")
    local state = ui:lua([[
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
    ui:rpc("nvim_input", "<C-e>")
    ui:wait_until(function()
      return ui:lua([[return vim.fn.pumvisible()==0]])
    end, 5000, "cancel does not schedule another automatic completion")
    t.assert_eq(query, ui:lua([[return vim.fn.getcmdline()]]), "typed command is preserved")
    ui:rpc("nvim_input", "<Esc>")
    ui:wait_until(function()
      return ui:rpc("nvim_get_mode").mode == "n"
    end, 5000, "command line closes")
  end
  t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
end)

t:run()
