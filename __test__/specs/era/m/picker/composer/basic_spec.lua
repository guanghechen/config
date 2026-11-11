require("ark.bootstrap").setup()
local bootstrap = require("__test__.support.bootstrap")
local t = require("__test__.support.harness").new()
local List = require("era.m.picker.composer.list")

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

---Observables of the filter controls of a List, disposed when the case ends.
---@return table<string, stl.c.Observable>
local function controls()
  local observables = {} ---@type table<string, stl.c.Observable>
  for key, value in pairs({ search_pattern = "", flag_fuzzy = true, flag_regex = false, flag_case_sensitive = false }) do
    local observable = stl.c.Observable.from_value(value)
    t:defer(function()
      observable:dispose()
    end)
    observables[key] = observable
  end
  return observables
end

t:test("closing a preview picker before its first draw cancels queued lifecycle callbacks", function()
  t:patch_table(vim.o, "lines", 60)
  t:patch_table(vim.o, "columns", 142)
  for _, permanent in ipairs({ false, true }) do
    local errors = bootstrap.with_reporter(t).error
    local previous_error = vim.v.errmsg
    vim.v.errmsg = ""
    t:defer(function()
      vim.v.errmsg = previous_error
    end)
    local callbacks = 0
    local picker = List.new(vim.tbl_extend("force", controls(), {
      name = "preview-lifecycle",
      title = "Confirm",
      permanent = permanent,
      height = 40,
      render_preview = function(_, bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Captured target" })
        return { cursorline = false, number = false, title = "Targets", wrap = true, whitespaces = false }
      end,
      on_focused = function()
        callbacks = callbacks + 1
      end,
      on_closed = function()
        callbacks = callbacks + 1
      end,
      on_hidden = function()
        callbacks = callbacks + 1
      end,
    }))
    t:defer(function()
      picker:dispose()
    end)
    picker:reset_data({
      items = {
        { uuid = "1", text = "Cancel", text_lower = "cancel", highlights = {} },
        { uuid = "2", text = "Delete", text_lower = "delete", highlights = {} },
      },
    })
    picker:focus()
    if permanent then
      picker:hide()
    end
    picker:close()
    picker:dispose()
    vim.wait(150, function()
      return false
    end, 5)
    t.assert_eq(0, callbacks, "disposed pickers must not deliver pending focus/hide/close callbacks")
    t.assert_eq(0, #errors, vim.inspect(errors))
    t.assert_eq("", vim.v.errmsg)
  end
end)

t:test("disposing a picker cancels a preview task already queued for drawing", function()
  t:patch_table(vim.o, "lines", 60)
  t:patch_table(vim.o, "columns", 142)
  for _, permanent in ipairs({ false, true }) do
    local errors = bootstrap.with_reporter(t).error
    local draws = 0
    local picker = List.new(vim.tbl_extend("force", controls(), {
      name = "queued-preview-lifecycle",
      title = "Confirm",
      permanent = permanent,
      height = 40,
      render_preview = function(composer, bufnr)
        draws = draws + 1
        local row = composer.result.lnum_current:snapshot()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Target " .. row })
        return { cursorline = false, number = false, title = "Targets", wrap = true, whitespaces = false }
      end,
    }))
    t:defer(function()
      picker:dispose()
    end)
    picker:focus()
    picker.preview._scheduler_content:schedule({ immediate = true })
    picker:dispose()
    vim.wait(150, function()
      return false
    end, 5)
    t.assert_eq(0, draws, "a queued renderer must not receive a disposed composer")
    t.assert_eq(0, #errors, vim.inspect(errors))
  end
end)

t:run()
