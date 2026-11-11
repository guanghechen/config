local t = require("__test__.support.harness").new()

---@param permanent                     boolean
---@param refocus                       ?boolean Whether the confirm callback focuses the source window before closing.
---@return __test__.support.UI
local function session(permanent, refocus)
  local ui = require("__test__.support.ui").open(t, { width = 100, height = 32, runtime = "ark" })
  ui:lua(
    [[
    local permanent, refocus = ...
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = 1", "local other = 2" })
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    source_winnr = vim.api.nvim_get_current_win()
    confirmed = 0
    picker = era.m.picker.ListComposer.new({
      name = "mode list",
      title = "mode list",
      permanent = permanent,
      search_pattern = stl.c.Observable.from_value(""),
      flag_fuzzy = stl.c.Observable.from_value(false),
      flag_regex = stl.c.Observable.from_value(false),
      flag_case_sensitive = stl.c.Observable.from_value(false),
      on_confirm = function(composer)
        if refocus then
          vim.api.nvim_set_current_win(source_winnr)
        end
        composer:close()
        confirmed = confirmed + 1
      end,
    })
    picker:reset_data({ items = { { uuid = "one", text = "needle", text_lower = "needle", data = {} } } })
    vim.keymap.set({ "n", "i" }, "<F5>", function()
      picker:focus()
    end)
  ]],
    permanent,
    refocus == true
  )
  return ui
end

---@param ui                            __test__.support.UI
---@param keys                          string
---@param condition                     string Lua expression that holds once the keys took effect.
---@return nil
local function press(ui, keys, condition)
  ui:rpc("nvim_input", keys)
  ui:wait_lua("return " .. condition, 5000, keys .. " did not reach: " .. condition)
end

---Opens the picker, types a filter in its finder and confirms.
---@param ui                            __test__.support.UI
---@return { mode: string, source: boolean, cursor: integer[], lines: string[] }
local function after_confirm(ui)
  press(ui, "<F5>", "vim.api.nvim_get_current_win() ~= source_winnr")
  if ui:lua("return vim.api.nvim_get_mode().mode") ~= "i" then
    press(ui, "i", "vim.api.nvim_get_mode().mode == 'i'")
  end
  press(ui, "nee", "vim.api.nvim_buf_get_lines(picker.finder:get_bufnr(), 0, 1, false)[1]:find('nee') ~= nil")
  press(ui, "<CR>", "confirmed == 1")
  return ui:lua([[
    return {
      mode = vim.api.nvim_get_mode().mode,
      source = vim.api.nvim_get_current_win() == source_winnr,
      cursor = vim.api.nvim_win_get_cursor(source_winnr),
      lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(source_winnr), 0, -1, false),
    }
  ]])
end

for _, case in ipairs({
  { permanent = true, name = "a permanent picker" },
  { permanent = false, name = "a disposable picker" },
  -- vim.ui.select focuses the source window itself before it closes its picker.
  { permanent = false, refocus = true, name = "a disposable picker that refocuses the source window" },
}) do
  t:test(case.name .. " opened from Normal mode returns to Normal mode after a typed filter", function()
    local ui = session(case.permanent, case.refocus)

    local state = after_confirm(ui)

    t.assert_true(state.source, "focus returns to the source window")
    t.assert_eq("n", state.mode, "Insert mode from the filter does not carry over")
    t.assert_same({ 1, 6 }, state.cursor, "the cursor keeps its column")
    t.assert_same({ "local value = 1", "local other = 2" }, state.lines, "the source buffer is untouched")
  end)
end

t:test("a picker opened from Insert mode returns to Insert mode", function()
  local ui = session(true)
  press(ui, "i", "vim.api.nvim_get_mode().mode == 'i'")

  local state = after_confirm(ui)

  t.assert_true(state.source, "focus returns to the source window")
  t.assert_eq("i", state.mode, "Insert mode is resumed")
  t.assert_same({ 1, 6 }, state.cursor, "the cursor keeps its column")
end)

t:run()
