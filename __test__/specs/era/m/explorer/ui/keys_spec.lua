local t = require("__test__.support.harness").new()
local explorer = require("__test__.support.explorer")

t:test("fold keys coexist with which-key and publish names and status together", function()
  local path = t:tempdir()
  vim.fn.mkdir(path .. "/branch/nested", "p")
  for _, name in ipairs({ "keep-a.lua", "keep-b.lua", "branch/inside.lua", "branch/nested/leaf.lua" }) do
    vim.fn.writefile({ "content" }, path .. "/" .. name)
  end
  local tracking, failures, observed = false, {}, 0
  local expected = {
    ["branch"] = { color = 0xFFFF00, status = "W:1" },
    ["keep-a.lua"] = { color = 0xFF0000, status = "E:1" },
    ["keep-b.lua"] = { color = 0xFFFF00, status = "W:1" },
    ["inside.lua"] = { color = 0xFFFF00, status = "W:1", optional = true },
    ["nested"] = { color = 0x808080, status = "", optional = true },
    ["leaf.lua"] = { color = 0x808080, status = "", optional = true },
  }
  local ui, grid = explorer.open_ui(t, {
    width = 100,
    height = 30,
    path = path,
    on_flush = function(screen)
      if not tracking then
        return
      end
      observed = observed + 1
      for name, value in pairs(expected) do
        local cell = screen:find(name)
        if cell then
          if cell.highlight.foreground ~= value.color or not screen:row_text(cell):find(value.status, 1, true) then
            failures[#failures + 1] = { flush = screen.flushes, name = name, color = cell.highlight.foreground }
          end
        elseif not value.optional then
          failures[#failures + 1] = { flush = screen.flushes, name = name, missing = true }
        end
      end
    end,
  })
  ui:lua(
    [=[
    local path = ...
    vim.api.nvim_set_hl(0, "DiagnosticError", { fg = 0xFF0000 })
    vim.api.nvim_set_hl(0, "DiagnosticWarn", { fg = 0xFFFF00 })
    vim.api.nvim_set_hl(0, "m_ft_filename", { fg = 0x808080 })
    whichkey = era.dressing.whichkey
    whichkey.state.setup()
    whichkey.state.enable()
    popups, navigations = 0, 0
    local render = whichkey.view.render
    whichkey.view.render = function(...)
      popups = popups + 1
      return render(...)
    end
    local keymaps = require("era.m.explorer.keymaps")
    local bind = keymaps.bind
    keymaps.bind = function(widget, view)
      vim.api.nvim_buf_call(view.bufnr, function()
        whichkey.state.__attach__(view.bufnr)
        assert(vim.fn.maparg("z", "n", false, true).desc == "wk-trigger")
      end)
      bind(widget, view)
    end
    widget = require("era.m.explorer.widget").new({ name = "fold-test", root = path })
    local navigate = widget:action().navigate
    widget:action().navigate = function(self, direction)
      navigations = navigations + 1
      return navigate(self, direction)
    end
    widget:focus()
    session, view = shown(widget, 3)
    for index, name in ipairs({ "keep-a.lua", "keep-b.lua", "branch/inside.lua" }) do
      local counts = index == 1 and { 1, 0, 0, 0 } or { 0, 1, 0, 0 }
      await(session.data:set_diagnostics(1, index, 1, path .. "/" .. name, counts))
    end
    local on_frame = view._options.on_frame
    view._options.on_frame = function(frame)
      on_frame(frame)
      -- Observers may redraw immediately after a frame is published.
      vim.cmd("redraw")
    end
  ]=],
    path
  )
  t.wait_until(function()
    for name, value in pairs(expected) do
      local cell = grid:find(name)
      if not value.optional and (not cell or cell.highlight.foreground ~= value.color) then
        return false
      end
    end
    return true
  end, 10000)
  ui:rpc("nvim_input", "[")
  ui:wait_lua("return whichkey.state.keys == '['", 10000, "the prefix must enter which-key before its child is typed")
  ui:rpc("nvim_input", "i")
  ui:wait_lua(
    "return navigations == 1 and not whichkey.state.is_suspended(view.bufnr, 'n')",
    10000,
    "a which-key prefix must execute and restore its triggers"
  )
  t.assert_eq(
    "Explorer: recursive expansion",
    ui:lua("return vim.fn.maparg('z', 'n', false, true).desc"),
    "which-key must preserve Explorer's replacement mapping"
  )
  ui:lua("popups = 0")
  tracking = true
  for step = 1, 8 do
    local expanded = step % 2 == 1
    local recursive = step > 4
    ui:rpc("nvim_input", recursive and "z" or expanded and "l" or "h")
    ui:wait_lua(
      [[
      local expanded, recursive = ...
      local frame = view:frame()
      return frame:header().row_count == (expanded and (recursive and 6 or 5) or 3)
        and frame:rows(1, 1).expanded[1] == expanded
    ]],
      10000,
      nil,
      expanded,
      recursive
    )
  end
  tracking = false
  t.assert_true(observed >= 8, "fold transitions must reach the UI")
  t.assert_eq(0, #failures, "fold/expand lost decorations: " .. vim.inspect(failures[1]))
  t.assert_eq(0, ui:lua("return popups"), "fold keys must not open which-key")
  t.assert_eq(0, ui:lua("return #errors"))
  ui:lua("widget:dispose(); whichkey.state.disable()")
end)

t:run()
