require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local file = require("era.m.nvimbar.component.file")

t:test("clicking the file path offers the copy choices above the status line at column 36", function()
  local clicked = nil ---@type function|nil
  local register = dot.G.register_anonymous_fn
  t:patch_table(dot.G, "register_anonymous_fn", function(fn, name)
    clicked = clicked or fn
    return register(fn, name)
  end)
  file.path("f_sl")

  t:buffer(nil, { name = t:tempdir() .. "/main.lua", listed = true, current = true })

  assert(clicked, "the path component registers its click handler")()
  local popup = vim.api.nvim_get_current_win() ---@type integer
  t:defer(function()
    if vim.api.nvim_win_is_valid(popup) then
      vim.api.nvim_win_close(popup, true)
    end
  end)

  t.assert_eq(stl.e.WinTypeEnum.SELECT, vim.w[popup].wintype, "the copy choices")
  local config = vim.api.nvim_win_get_config(popup)
  t.assert_eq("editor", config.relative, "relative to the editor")
  t.assert_eq("SW", config.anchor, "anchored at the bottom-left corner")
  t.assert_eq(vim.o.lines - 1, config.row, "above the status line")
  t.assert_eq(36, config.col, "at column 36")
end)

t:test("the file size refreshes when a write changes the buffer's changedtick", function()
  local size = file.size("f_sl")
  local shown = { filepath = "/project/main.lua", changedtick = 4 }
  t.assert_false(size.will_change(shown, shown), "nothing happened")
  t.assert_true(size.will_change({ filepath = "/project/main.lua", changedtick = 5 }, shown), "written")
end)

t:run()
