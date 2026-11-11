local harness = require("__test__.support.harness")
local Future = require("stl.c.future")

local t = harness.new()

---Loads the command definitions and `era.command` over doubles that count their calls. A visual hunk stage stays
---pending until the case calls `resolve_stage` with its result.
---@return table
local function setup()
  local enums = assert(loadfile("lua/stl/e.lua"))()
  local state = {
    enums = enums,
    calls = {
      next_info = 0,
      prev_info = 0,
      explorer_reveal = 0,
      diffview_reveal = 0,
      maximize_close = 0,
      tab_close = 0,
    },
    resolve_stage = nil, ---@type (fun(result: table): nil)|nil
    stage_range = nil, ---@type integer[]|nil
  }
  local calls = state.calls

  t:patch_global("stl", {
    e = enums,
    nvim = { buf = {
      retrieve_visual_lnum_range = function()
        return 2, 4
      end,
    } },
    reporter = {
      error = function() end,
      warn = function() end,
    },
  })
  t:patch_global("dot", {
    state = { status = { set_winnr_command = function() end } },
    var = { themes = {}, toggler = {} },
  })
  t:patch_global("era", {
    m = {
      diffview = {
        fn = {
          reveal = function()
            calls.diffview_reveal = calls.diffview_reveal + 1
          end,
        },
      },
      git = {
        hunk = {
          stage = function(range)
            state.stage_range = range
            local future, resolve = Future.new_with_resolver()
            state.resolve_stage = resolve
            return future
          end,
        },
      },
      lsp = {
        diagnostic = {
          goto_next_info = function()
            calls.next_info = calls.next_info + 1
          end,
          goto_prev_info = function()
            calls.prev_info = calls.prev_info + 1
          end,
        },
      },
      maximize = {
        close = function()
          calls.maximize_close = calls.maximize_close + 1
        end,
      },
    },
    nvim = {
      tab = {
        close = function()
          calls.tab_close = calls.tab_close + 1
        end,
      },
    },
    widget = {
      explorer = {
        reveal = function()
          calls.explorer_reveal = calls.explorer_reveal + 1
        end,
      },
    },
  })
  t:patch_table(vim.api, "nvim_create_user_command", function() end)

  state.Command = assert(loadfile("lua/dot/command.lua"))()
  dot.command = state.Command
  assert(loadfile("lua/era/command.lua"))()
  return state
end

---Gives the current tab back its tab type when the case ends.
---@return integer
local function current_tab()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local previous_tabtype = vim.t[tabnr].tabtype ---@type string|nil
  t:defer(function()
    vim.t[tabnr].tabtype = previous_tabtype
  end)
  return tabnr
end

t:test("next and previous info diagnostics run their own implementations", function()
  local state = setup()

  state.Command.definitions.diagnostic.goto_next_info:execute()
  state.Command.definitions.diagnostic.goto_prev_info:execute()

  t.assert_eq(1, state.calls.next_info, "next info implementation")
  t.assert_eq(1, state.calls.prev_info, "previous info implementation")
end)

t:test("explorer reveal delegates to Diffview in Diffview tabs", function()
  local state = setup()
  local enums = state.enums
  local tabnr = current_tab()

  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL
  state.Command.definitions.explorer.reveal:execute()
  for _, tabtype in ipairs({ enums.TabTypeEnum.DIFFVIEW_WORKSPACE, enums.TabTypeEnum.DIFFVIEW_COMMITS }) do
    vim.t[tabnr].tabtype = tabtype
    state.Command.definitions.explorer.reveal:execute()
  end

  t.assert_eq(1, state.calls.explorer_reveal, "normal explorer reveal")
  t.assert_eq(2, state.calls.diffview_reveal, "Diffview navigation reveal")
end)

t:test("a maximized tab closes through maximize and has no tab focus, new or split commands", function()
  local state = setup()
  local Command, enums = state.Command, state.enums
  local tabnr = current_tab()

  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL
  Command.definitions.tab.close:execute()
  vim.t[tabnr].tabtype = enums.TabTypeEnum.MAXIMIZE
  Command.definitions.tab.close:execute()

  t.assert_eq(1, state.calls.tab_close, "normal tab close")
  t.assert_eq(1, state.calls.maximize_close, "maximize tab close")

  local focus_uuid = Command.definitions.tab.focus.uuid ---@type string
  local new_uuid = Command.definitions.tab.new.uuid ---@type string
  local split_uuid = Command.definitions.win.split_right.uuid ---@type string
  t.assert_true(Command.__command_map__[focus_uuid .. ":" .. enums.TabTypeEnum.NORMAL] ~= nil, "normal tab focus")
  t.assert_nil(Command.__command_map__[focus_uuid .. ":" .. enums.TabTypeEnum.MAXIMIZE], "maximize tab focus")
  t.assert_true(Command.__command_map__[new_uuid .. ":" .. enums.TabTypeEnum.NORMAL] ~= nil, "normal tab new")
  t.assert_nil(Command.__command_map__[new_uuid .. ":" .. enums.TabTypeEnum.MAXIMIZE], "maximize tab new")
  t.assert_nil(Command.__command_map__[split_uuid .. ":" .. enums.TabTypeEnum.MAXIMIZE], "maximize window split")
end)

t:test(
  "visual hunk staging clears the selection only after its latest stage succeeds on an unchanged selection",
  function()
    local state = setup()
    local stage_visual = state.Command.definitions.git.hunk_stage_visual
    local test_bufnr = t:buffer({ "one", "two" }, { current = true }) ---@type integer

    vim.cmd("normal! V")
    stage_visual:execute()
    local captured_stage_range = assert(state.stage_range)
    t.assert_eq(2, captured_stage_range[1], "visual stage start")
    t.assert_eq(4, captured_stage_range[2], "visual stage end")
    t.assert_eq("V", vim.fn.mode(), "selection while pending")
    assert(state.resolve_stage)({ ok = true })
    t.assert_eq("n", vim.fn.mode(), "selection cleared after success")

    vim.cmd("normal! V")
    stage_visual:execute()
    assert(state.resolve_stage)({ ok = false, err = "failed" })
    t.assert_eq("V", vim.fn.mode(), "selection retained after failure")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

    vim.cmd("normal! ggV")
    stage_visual:execute()
    vim.cmd("normal! j")
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = test_bufnr })
    vim.cmd("normal! k")
    assert(state.resolve_stage)({ ok = true })
    t.assert_eq("V", vim.fn.mode(), "changed then restored selection retained after success")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

    vim.cmd("normal! V")
    stage_visual:execute()
    local resolve_older_stage = assert(state.resolve_stage)
    stage_visual:execute()
    local resolve_newer_stage = assert(state.resolve_stage)
    resolve_older_stage({ ok = true })
    t.assert_eq("V", vim.fn.mode(), "older stage keeps newer selection")
    resolve_newer_stage({ ok = true })
    t.assert_eq("n", vim.fn.mode(), "newer stage clears unchanged selection")
  end
)

t:run()
