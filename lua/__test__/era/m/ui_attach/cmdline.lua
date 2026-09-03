---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("era.m.ui_attach.cmdline")

---@return era.m.ui_attach.cmdline, era.m.ui_attach.state
local function setup()
  t:patch_global("dot", {
    var = {
      nsnr = {},
    },
  })
  t:patch_global("stl", {
    icon = {
      ui = {
        Cmdline = "C",
        Search = "S",
        SearchForward = "F",
        SearchBackward = "B",
      },
    },
  })
  t:patch_table(vim, "g", { ui_cmdline_pos = { 5, 7 } })

  local states = require("era.m.ui_attach.state")
  t:patch_table(states, "cmdline", {})
  t:patch_table(states, "cmdline_block", { lines = {}, highlights = {} })
  t:patch_table(states, "message", {
    confirming_task = { event = "msg_show", args = {} },
  })

  local cmdline = assert(loadfile("lua/era/m/ui_attach/cmdline.lua"))()
  return cmdline, states
end

---@param concealable                   boolean
---@param pos                           integer
---@return integer
local function resolve_popup_col(concealable, pos)
  local cmdline, states = setup()
  local strdisplaywidth = vim.fn.strdisplaywidth
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim, "fn", {
    screenpos = function(_, _, col)
      if concealable then
        t.assert_eq(3, col, "concealed buffer cursor column")
        return { row = 4, col = 8 }
      end
      t.assert_eq(7, col, "visible buffer cursor column")
      return { row = 4, col = 12 }
    end,
    strdisplaywidth = strdisplaywidth,
  })

  local state = {
    level = 1,
    pos = pos,
    first = "edit ",
    second = "foo",
    indent = 0,
    icon = "> ",
    concealable = concealable,
    winnr = 1,
  }
  states.cmdline[1] = state
  cmdline._update_cmdline_position(state, state.winnr)

  local popupmenu = assert(loadfile("lua/era/m/ui_attach/popupmenu.lua"))()
  local _, col = popupmenu._resolve_position({
    items = {},
    selected = -1,
    row = 0,
    col = 5,
    grid = -1,
  })
  return col
end

t:test("top-level hide clears cmdline position and pending confirmation", function()
  local cmdline, states = setup()

  cmdline.hide({ event = "cmdline_hide", args = { 1, false } })

  t.assert_nil(vim.g.ui_cmdline_pos, "cmdline position")
  t.assert_nil(states.message.confirming_task, "confirmation")
end)

t:test("nested hide restores the highest active cmdline position", function()
  local cmdline, states = setup()
  local confirming_task = states.message.confirming_task
  states.message.confirming_task = nil
  ---@diagnostic disable-next-line: missing-fields
  states.cmdline[1] = { level = 1, winnr = 11, type = "confirm", confirming_task = confirming_task }
  ---@diagnostic disable-next-line: missing-fields
  states.cmdline[2] = { level = 2, winnr = 22 }
  cmdline._update_cmdline_position = function(state, winnr)
    vim.g.ui_cmdline_pos = { state.level, winnr }
  end

  cmdline.hide({ event = "cmdline_hide", args = { 3, false } })

  t.assert_eq(2, vim.g.ui_cmdline_pos[1], "active level")
  t.assert_eq(22, vim.g.ui_cmdline_pos[2], "active window")
  t.assert_true(states.cmdline[1].confirming_task == confirming_task, "confirmation")
  t.assert_nil(states.message.confirming_task, "pending confirmation")
end)

t:test("cmdline position uses original content origin", function()
  local cmdline = setup()
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim, "fn", {
    screenpos = function(_, _, col)
      t.assert_eq(3, col, "buffer cursor column")
      return { row = 4, col = 8 }
    end,
    strdisplaywidth = vim.fn.strdisplaywidth,
  })

  ---@diagnostic disable-next-line: missing-fields
  cmdline._update_cmdline_position({
    pos = 5,
    first = "edit ",
    second = "",
    indent = 0,
    icon = "> ",
    concealable = true,
  }, 1)

  t.assert_eq(4, vim.g.ui_cmdline_pos[1], "cmdline row")
  t.assert_eq(2, vim.g.ui_cmdline_pos[2], "cmdline column")
end)

t:test("cmdline position follows a horizontally scrolled cursor", function()
  local cmdline = setup()
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim, "fn", {
    screenpos = function(_, _, col)
      t.assert_eq(82, col, "buffer cursor column")
      return { row = 5, col = 16 }
    end,
    strdisplaywidth = vim.fn.strdisplaywidth,
  })

  ---@diagnostic disable-next-line: missing-fields
  cmdline._update_cmdline_position({
    pos = 79,
    first = string.rep("a", 120),
    second = "",
    indent = 0,
    icon = "> ",
    concealable = false,
  }, 1)

  t.assert_eq(5, vim.g.ui_cmdline_pos[1], "cmdline row")
  t.assert_eq(-64, vim.g.ui_cmdline_pos[2], "scrolled cmdline origin")
end)

t:test("cmdline show preserves protocol content and indent", function()
  local cmdline, states = setup()
  states.message.confirming_task = nil
  local rendered = nil
  cmdline._show = function(state)
    rendered = state
  end
  local content = { { 0, "1+2", 17 } }

  cmdline.show({ event = "cmdline_show", args = { content, 3, "=", "Prompt:", 2, 1, 9 } })

  t.assert_true(rendered ~= nil, "rendered state")
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  t.assert_true(rendered.content == content, "content identity")
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  t.assert_eq("Prompt:", rendered.prompt, "prompt")
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  t.assert_eq(2, rendered.indent, "indent")
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  t.assert_nil(rendered.special, "special char")
end)

t:test("programmatic cmdline sync reuses the active render surface", function()
  local cmdline, states = setup()
  local rendered = nil ---@type era.m.ui_attach.cmdline.IState|nil
  states.cmdline[1] = {
    level = 1,
    firstc = ":",
    prompt = "",
    indent = 0,
    hlid = 9,
    icon = "C  ",
    first = "edit ",
    second = "source/",
    type = "command",
    language = "vim",
    concealable = false,
  }
  cmdline._sync = function(state)
    rendered = state
  end

  cmdline.sync("edit source/file.lua", 21)

  local synced = assert(rendered)
  t.assert_eq("edit ", synced.first, "command prefix")
  t.assert_eq("source/file.lua", synced.second, "command argument")
  t.assert_eq(20, synced.pos, "zero-based cursor")
end)

t:test("completion preview sync defers and coalesces its redraw", function()
  local cmdline, states = setup()
  local immediate = nil ---@type boolean|nil
  local scheduled = {} ---@type function[]
  local redraws = 0
  states.cmdline[1] = {
    level = 1,
    firstc = "@",
    prompt = "bench> ",
    indent = 0,
    hlid = 9,
    icon = "C  ",
    first = "item001",
    second = "",
    type = "command",
    language = nil,
    concealable = false,
    preview_redraw_pending = false,
  }
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.api, "nvim__redraw", function(opts)
    t.assert_true(opts.cursor, "cursor redraw")
    t.assert_true(opts.flush, "flushed redraw")
    redraws = redraws + 1
  end)
  cmdline._sync = function(_, value_immediate)
    immediate = value_immediate
  end

  cmdline.sync_preview("item002", 8)
  cmdline.sync_preview("item003", 8)

  t.assert_false(immediate, "deferred position and redraw")
  t.assert_eq("item003", states.cmdline[1].echo_text, "expected protocol echo")
  t.assert_eq(7, states.cmdline[1].echo_pos, "expected protocol cursor")
  t.assert_eq(1, #scheduled, "coalesced redraw")
  scheduled[1]()
  t.assert_eq(1, redraws, "deferred redraw")
end)

t:test("matching programmatic cmdline echo does not render twice", function()
  local cmdline, states = setup()
  states.message.confirming_task = nil
  local content = { { 0, "item002", 9 } }
  states.cmdline[1] = {
    level = 1,
    firstc = "@",
    prompt = "bench> ",
    indent = 0,
    hlid = 9,
    icon = "C  ",
    first = "item002",
    second = "",
    type = "command",
    language = nil,
    concealable = false,
    ghost = "tail",
    echo_text = "item002",
    echo_pos = 7,
  }
  cmdline._show = function()
    error("matching protocol echo must not render")
  end

  cmdline.show({ event = "cmdline_show", args = { content, 7, "@", "bench> ", 0, 1, 9 } })

  t.assert_true(states.cmdline[1].content == content, "protocol content")
  t.assert_eq("tail", states.cmdline[1].ghost, "preview ghost")
  t.assert_nil(states.cmdline[1].echo_text, "consumed echo text")
  t.assert_nil(states.cmdline[1].echo_pos, "consumed echo cursor")

  local rendered = false
  states.cmdline[1].echo_text = "item003"
  states.cmdline[1].echo_pos = 7
  cmdline._show = function()
    rendered = true
  end
  cmdline.show({ event = "cmdline_show", args = { { { 0, "user", 9 } }, 4, "@", "bench> ", 0, 1, 9 } })
  t.assert_true(rendered, "mismatched user input renders")
end)

t:test("programmatic cmdline sync falls back when display structure changes", function()
  local cmdline, states = setup()
  local rendered = nil ---@type era.m.ui_attach.cmdline.IState|nil
  states.cmdline[1] = {
    level = 1,
    firstc = ":",
    prompt = "",
    indent = 0,
    hlid = 9,
    icon = "C  ",
    first = "lu",
    second = "",
    type = "command",
    language = "vim",
    concealable = false,
  }
  cmdline._sync = function()
    error("fast path must not retain stale display structure")
  end
  cmdline._show = function(state)
    rendered = state
  end

  cmdline.sync("lua print('ok')", 16)

  local synced = assert(rendered)
  t.assert_eq("command_lua", synced.type, "display type")
  t.assert_eq("lua", synced.language, "display language")
  t.assert_true(synced.concealable, "concealed command prefix")
  t.assert_eq("lua ", synced.first, "command prefix")
  t.assert_eq("print('ok')", synced.second, "command argument")
end)

t:test("cmdline render keeps byte highlight offsets", function()
  local cmdline = setup()
  t:patch_table(vim.fn, "synIDattr", function(hlid)
    return "Group" .. hlid
  end)

  ---@diagnostic disable-next-line: missing-fields
  local render = cmdline._resolve_render({
    content = { { 0, "文", 11 }, { 0, "x", 12 } },
    pos = 4,
    first = "文x",
    second = "",
    indent = 2,
    icon = "> ",
    concealable = false,
    ghost = "yz",
  })

  t.assert_eq(">   文x ", render.line, "rendered line")
  t.assert_eq(8, render.cursor_col, "cursor byte column")
  t.assert_eq(8, render.ghost_col, "ghost byte column")
  t.assert_eq("yz", render.ghost, "ghost text")
  t.assert_eq(4, render.content_offset, "content offset")
  t.assert_false(render.concealed, "concealed content")
  t.assert_eq(4, render.highlights[1].coll, "first highlight start")
  t.assert_eq(7, render.highlights[1].colr, "first highlight end")
  t.assert_eq(7, render.highlights[2].coll, "second highlight start")
  t.assert_eq(8, render.highlights[2].colr, "second highlight end")
end)

t:test("cmdline ghost updates the active surface without changing content", function()
  local cmdline, states = setup()
  local rendered = nil ---@type era.m.ui_attach.cmdline.IState|nil
  states.cmdline[1] = {
    level = 1,
    firstc = ":",
    prompt = "",
    indent = 0,
    hlid = 9,
    icon = "C  ",
    first = "ed",
    second = "",
    type = "command",
    language = "vim",
    concealable = false,
    ghost = nil,
  }
  cmdline._sync = function(state)
    rendered = state
  end

  cmdline.set_ghost("it")

  local state = assert(rendered)
  t.assert_eq("ed", state.first, "content")
  t.assert_eq("it", state.ghost, "ghost")
end)

t:test("special char is retained until the next cmdline show", function()
  local cmdline, states = setup()
  ---@diagnostic disable-next-line: missing-fields
  states.cmdline[1] = { level = 1 }
  local rendered = nil
  cmdline._show = function(state)
    rendered = state
  end

  cmdline.special_char({ event = "cmdline_special_char", args = { '"', true, 1 } })

  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  t.assert_eq('"', rendered.special.c, "special char")
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  t.assert_true(rendered.special.shift, "special shift")
end)

t:test("cmdline block append accepts one line of chunks", function()
  local cmdline, states = setup()
  cmdline._render_block = function() end

  cmdline.block_show({ event = "cmdline_block_show", args = { { { { 0, "function Foo()", 0 } } } } })
  cmdline.block_append({ event = "cmdline_block_append", args = { { { 0, "  echo 'x'", 0 } } } })

  t.assert_eq("function Foo()", states.cmdline_block.lines[1], "block first line")
  t.assert_eq("  echo 'x'", states.cmdline_block.lines[2], "block appended line")
end)

t:test("cmdline block highlights use hl_id and byte columns", function()
  local cmdline, states = setup()
  cmdline._render_block = function() end
  t:patch_table(vim.fn, "synIDattr", function(hlid)
    return "Group" .. hlid
  end)

  cmdline.block_show({
    event = "cmdline_block_show",
    args = { { { { 99, "文", 11 }, { 98, "x", 12 } } } },
  })

  t.assert_eq("Group11", states.cmdline_block.highlights[1].hlname, "first highlight group")
  t.assert_eq(0, states.cmdline_block.highlights[1].coll, "first highlight start")
  t.assert_eq(3, states.cmdline_block.highlights[1].colr, "first highlight end")
  t.assert_eq("Group12", states.cmdline_block.highlights[2].hlname, "second highlight group")
  t.assert_eq(3, states.cmdline_block.highlights[2].coll, "second highlight start")
  t.assert_eq(4, states.cmdline_block.highlights[2].colr, "second highlight end")
end)

t:test("latest Neovim emits block events with one-line append payloads", function()
  local events = {
    append = {},
    show = {},
  }
  local nsnr = vim.api.nvim_create_namespace("era.m.ui_attach.cmdline.protocol")
  vim.ui_attach(nsnr, { ext_cmdline = true }, function(event, ...)
    if event == "cmdline_block_show" then
      events.show[#events.show + 1] = { ... }
    elseif event == "cmdline_block_append" then
      events.append[#events.append + 1] = { ... }
    end
  end)

  vim.api.nvim_feedkeys(vim.keycode(":function UiAttachProtocolProbe()<CR>echo 'x'<CR>endfunction<CR>"), "xt", false)
  vim.ui_detach(nsnr)
  vim.cmd("delfunction UiAttachProtocolProbe")

  t.assert_eq(1, #events.show, "block show events")
  t.assert_eq(2, #events.append, "block append events")
  t.assert_eq("function UiAttachProtocolProbe()", events.show[1][1][1][1][2], "block show content")
  t.assert_eq("  echo 'x'", events.append[1][1][1][2], "block append content")
end)

t:test("popup byte offset resolves against visible normal cmdline content", function()
  local col = resolve_popup_col(false, 4)

  -- screen col 5 + icon width 2 + "edit " width 5
  t.assert_eq(12, col, "popup column")
end)

t:test("popup byte offset compensates for a concealed command prefix", function()
  local col = resolve_popup_col(true, 5)

  -- screen col 5 + icon width 2; the concealed "edit " prefix contributes no width
  t.assert_eq(7, col, "popup column")
end)

t:test("confirm prompts keep their renderer while the user types", function()
  local cmdline, states = setup()
  local rendered = {} ---@type string[]
  cmdline._show = function()
    rendered[#rendered + 1] = "command"
  end
  cmdline._show_confirm = function()
    rendered[#rendered + 1] = "confirm"
  end

  local function show(text, pos)
    cmdline.show({
      event = "cmdline_show",
      args = { { { 0, text, 0 } }, pos, "", "Type number and <Enter>", 0, 1, 0 },
    })
  end

  show("", 0)
  show("1", 1)
  show("12", 2)

  t.assert_eq("confirm,confirm,confirm", table.concat(rendered, ","), "confirm renders")
  t.assert_true(states.cmdline[1].confirming_task ~= nil, "confirmation owner")
  t.assert_nil(states.message.confirming_task, "pending confirmation")
end)

t:test("real command lines clear pending confirmations", function()
  local cmdline, states = setup()
  local rendered
  cmdline._show = function()
    rendered = "command"
  end

  cmdline.show({ event = "cmdline_show", args = { { { 0, "set number", 0 } }, 10, ":", "", 0, 1, 0 } })

  t.assert_eq("command", rendered, "command renderer")
  t.assert_nil(states.message.confirming_task, "pending confirmation")
end)

t:test("cursor movement inside a confirm prompt keeps the confirm renderer", function()
  local cmdline, states = setup()
  local rendered
  cmdline._show = function()
    rendered = "command"
  end
  cmdline._show_confirm = function()
    rendered = "confirm"
  end
  ---@diagnostic disable-next-line: missing-fields
  states.cmdline[1] = {
    level = 1,
    pos = 0,
    type = "confirm",
    confirming_task = states.message.confirming_task,
  }
  states.message.confirming_task = nil

  cmdline.pos({ event = "cmdline_pos", args = { 3, 1 } })

  t.assert_eq("confirm", rendered, "confirm renderer")
end)

t:test("special chars inside a confirm prompt keep the confirm renderer", function()
  local cmdline, states = setup()
  local rendered
  ---@diagnostic disable-next-line: missing-fields
  states.cmdline[1] = {
    level = 1,
    type = "confirm",
    confirming_task = states.message.confirming_task,
  }
  states.message.confirming_task = nil
  cmdline._show = function()
    rendered = "command"
  end
  cmdline._show_confirm = function()
    rendered = "confirm"
  end

  cmdline.special_char({ event = "cmdline_special_char", args = { "x", false, 1 } })

  t.assert_eq("confirm", rendered, "special char renderer")
end)

t:test("nested expression cmdlines do not inherit an outer confirmation", function()
  local cmdline, states = setup()
  local rendered
  ---@diagnostic disable-next-line: missing-fields
  states.cmdline[1] = {
    level = 1,
    type = "confirm",
    confirming_task = states.message.confirming_task,
  }
  states.message.confirming_task = nil
  cmdline._show = function()
    rendered = "command"
  end
  cmdline._show_confirm = function()
    rendered = "confirm"
  end

  cmdline.show({ event = "cmdline_show", args = { { { 0, "1+1", 0 } }, 3, "=", "", 0, 2, 0 } })

  t.assert_eq("command", rendered, "nested renderer")
  t.assert_true(states.cmdline[1].confirming_task ~= nil, "outer confirmation")
end)

t:run()
