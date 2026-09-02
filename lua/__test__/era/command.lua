---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/command.lua

local harness = require("__test__.harness")
local Future = require("stl.c.future")

local t = harness.new("era.command")

t:test("command definitions and implementations stay symmetric", function()
  local next_info_calls = 0
  local prev_info_calls = 0
  local explorer_reveal_calls = 0
  local diffview_reveal_calls = 0
  local maximize_close_calls = 0
  local tab_close_calls = 0
  local resolve_stage = nil ---@type (fun(result: table): nil)|nil
  local stage_range = nil ---@type integer[]|nil
  local enums = assert(loadfile("lua/stl/e.lua"))()

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
            diffview_reveal_calls = diffview_reveal_calls + 1
          end,
        },
      },
      git = {
        hunk = {
          stage = function(range)
            stage_range = range
            local future, resolve = Future.new_with_resolver()
            resolve_stage = resolve
            return future
          end,
        },
      },
      lsp = {
        diagnostic = {
          goto_next_info = function()
            next_info_calls = next_info_calls + 1
          end,
          goto_prev_info = function()
            prev_info_calls = prev_info_calls + 1
          end,
        },
      },
      maximize = {
        close = function()
          maximize_close_calls = maximize_close_calls + 1
        end,
      },
    },
    nvim = {
      tab = {
        close = function()
          tab_close_calls = tab_close_calls + 1
        end,
      },
    },
    widget = {
      explorer = {
        reveal = function()
          explorer_reveal_calls = explorer_reveal_calls + 1
        end,
      },
    },
  })
  t:patch_table(vim.api, "nvim_create_user_command", function() end)

  local Command = assert(loadfile("lua/dot/command.lua"))()
  dot.command = Command
  assert(loadfile("lua/era/command.lua"))()

  Command.definitions.diagnostic.goto_next_info:execute()
  Command.definitions.diagnostic.goto_prev_info:execute()

  t.assert_eq(1, next_info_calls, "next info implementation")
  t.assert_eq(1, prev_info_calls, "previous info implementation")

  local tabnr = vim.api.nvim_get_current_tabpage()
  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL
  Command.definitions.explorer.reveal:execute()
  for _, tabtype in ipairs({ enums.TabTypeEnum.DIFFVIEW_WORKSPACE, enums.TabTypeEnum.DIFFVIEW_COMMITS }) do
    vim.t[tabnr].tabtype = tabtype
    Command.definitions.explorer.reveal:execute()
  end
  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL

  Command.definitions.tab.close:execute()
  vim.t[tabnr].tabtype = enums.TabTypeEnum.MAXIMIZE
  Command.definitions.tab.close:execute()
  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL

  t.assert_eq(1, tab_close_calls, "normal tab close")
  t.assert_eq(1, maximize_close_calls, "maximize tab close")

  local focus_uuid = Command.definitions.tab.focus.uuid ---@type string
  local new_uuid = Command.definitions.tab.new.uuid ---@type string
  local split_uuid = Command.definitions.win.split_right.uuid ---@type string
  t.assert_true(Command.__command_map__[focus_uuid .. ":" .. enums.TabTypeEnum.NORMAL] ~= nil, "normal tab focus")
  t.assert_nil(Command.__command_map__[focus_uuid .. ":" .. enums.TabTypeEnum.MAXIMIZE], "maximize tab focus")
  t.assert_true(Command.__command_map__[new_uuid .. ":" .. enums.TabTypeEnum.NORMAL] ~= nil, "normal tab new")
  t.assert_nil(Command.__command_map__[new_uuid .. ":" .. enums.TabTypeEnum.MAXIMIZE], "maximize tab new")
  t.assert_nil(Command.__command_map__[split_uuid .. ":" .. enums.TabTypeEnum.MAXIMIZE], "maximize window split")

  t.assert_eq(1, explorer_reveal_calls, "normal explorer reveal")
  t.assert_eq(2, diffview_reveal_calls, "Diffview navigation reveal")

  local test_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(test_bufnr, 0, -1, false, { "one", "two" })
  vim.api.nvim_win_set_buf(0, test_bufnr)

  vim.cmd("normal! V")
  Command.definitions.git.hunk_stage_visual:execute()
  local captured_stage_range = assert(stage_range)
  t.assert_eq(2, captured_stage_range[1], "visual stage start")
  t.assert_eq(4, captured_stage_range[2], "visual stage end")
  t.assert_eq("V", vim.fn.mode(), "selection while pending")
  assert(resolve_stage)({ ok = true })
  t.assert_eq("n", vim.fn.mode(), "selection cleared after success")

  vim.cmd("normal! V")
  Command.definitions.git.hunk_stage_visual:execute()
  assert(resolve_stage)({ ok = false, err = "failed" })
  t.assert_eq("V", vim.fn.mode(), "selection retained after failure")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

  vim.cmd("normal! ggV")
  Command.definitions.git.hunk_stage_visual:execute()
  vim.cmd("normal! j")
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = test_bufnr })
  vim.cmd("normal! k")
  assert(resolve_stage)({ ok = true })
  t.assert_eq("V", vim.fn.mode(), "changed then restored selection retained after success")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

  vim.cmd("normal! V")
  Command.definitions.git.hunk_stage_visual:execute()
  local resolve_older_stage = assert(resolve_stage)
  Command.definitions.git.hunk_stage_visual:execute()
  local resolve_newer_stage = assert(resolve_stage)
  resolve_older_stage({ ok = true })
  t.assert_eq("V", vim.fn.mode(), "older stage keeps newer selection")
  resolve_newer_stage({ ok = true })
  t.assert_eq("n", vim.fn.mode(), "newer stage clears unchanged selection")
  vim.api.nvim_buf_delete(test_bufnr, { force = true })
end)

t:run()
