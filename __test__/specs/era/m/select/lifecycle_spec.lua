local bootstrap = require("__test__.support.bootstrap")
local t = require("__test__.support.harness").new()
local fixture = require("__test__.support.explorer").new(t)
local List = require("era.m.picker.composer.list")

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
