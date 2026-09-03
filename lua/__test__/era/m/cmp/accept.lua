---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.accept")

bootstrap.with_stl(t, {
  reporter = {
    error = function() end,
    warn = function() end,
  },
})

local resolve_callback
local resolve_snapshot = nil ---@type string[]|nil
local executed = {} ---@type lsp.Command[]
local bridge = {
  resolve = function(_, callback, text_snapshot)
    resolve_callback = callback
    resolve_snapshot = text_snapshot
    return function() end
  end,
  execute_command = function(command)
    executed[#executed + 1] = command
  end,
}
t:patch_table(package.loaded, "era.m.cmp.bridge", bridge)

local Accept = require("era.m.cmp.accept")

local function completed(item, word)
  return {
    word = word,
    user_data = { era_cmp = { item = item } },
  }
end

t:test("expands the primary snippet before delayed resolve", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "snippet(value)tail" })
  vim.api.nvim_win_set_cursor(0, { 1, 14 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  local sanitized
  t:patch_table(vim.api, "nvim_set_vvar", function(_, value)
    sanitized = value
  end)
  local expanded
  t:patch_table(vim.snippet, "expand", function(value)
    expanded = value
  end)
  executed = {}
  resolve_callback = nil

  local item = {
    label = "snippet",
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
    textEdit = {
      newText = "snippet(${1:value})",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 2 } },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = 4,
  }
  local records = 0
  t.assert_true(
    Accept.apply(completed(item, "snippet(value)"), function()
      records = records + 1
    end),
    "accepted item"
  )

  t.assert_eq("snippet(${1:value})", expanded, "synchronous snippet")
  t.assert_eq("", vim.api.nvim_get_current_line(), "preview and suffix cleared")
  t.assert_nil(sanitized.user_data.era_cmp, "internal acceptance data cleared")
  t.assert_eq(1, records, "frecency record")

  vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, { "x" })
  assert(resolve_callback)(nil, { command = { command = "late" } })
  t.assert_eq(0, #executed, "stale resolved command")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("accepting an existing preview does not delete its suffix twice", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "futontail" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  resolve_callback = nil

  local item = {
    label = "futon",
    textEdit = {
      newText = "futon",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = 3,
  }
  t.assert_true(Accept.apply(completed(item, "futon"), function() end, true), "accepted preview")
  t.assert_eq("futontail", vim.api.nvim_get_current_line(), "trailing text")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("rejects invalid snippets before mutating or recording usage", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "bad" })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  local sanitized
  t:patch_table(vim.api, "nvim_set_vvar", function(_, value)
    sanitized = value
  end)
  local expanded = false
  t:patch_table(vim.snippet, "expand", function()
    expanded = true
  end)
  resolve_callback = nil

  local item = {
    label = "bad",
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
    textEdit = {
      newText = "${1",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    _era_cmp_meta = { source = "lsp" },
  }
  local records = 0
  t.assert_false(
    Accept.apply(completed(item, "bad"), function()
      records = records + 1
    end),
    "invalid snippet"
  )

  t.assert_eq("bad", vim.api.nvim_get_current_line(), "buffer text")
  t.assert_false(expanded, "snippet expansion")
  t.assert_eq(0, records, "frecency record")
  t.assert_nil(resolve_callback, "resolve request")
  t.assert_nil(sanitized.user_data.era_cmp, "internal acceptance data cleared")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("rejects overlapping initial edits before mutating the primary text", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "foo" })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  t:patch_table(vim.api, "nvim_set_vvar", function() end)
  resolve_callback = nil

  local item = {
    label = "bar",
    textEdit = {
      newText = "bar",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    additionalTextEdits = {
      {
        newText = "x",
        range = { start = { line = 0, character = 1 }, ["end"] = { line = 0, character = 2 } },
      },
    },
    _era_cmp_meta = { source = "lsp" },
  }
  local records = 0
  t.assert_false(
    Accept.apply(completed(item, "foo"), function()
      records = records + 1
    end),
    "overlapping edit"
  )

  t.assert_eq("foo", vim.api.nvim_get_current_line(), "buffer text")
  t.assert_eq(0, records, "frecency record")
  t.assert_nil(resolve_callback, "resolve request")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("rejects mutually overlapping additional edits before mutation", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "foo tail" })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  t:patch_table(vim.api, "nvim_set_vvar", function() end)

  local item = {
    label = "bar",
    textEdit = {
      newText = "bar",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    additionalTextEdits = {
      {
        newText = "x",
        range = { start = { line = 0, character = 4 }, ["end"] = { line = 0, character = 7 } },
      },
      {
        newText = "y",
        range = { start = { line = 0, character = 6 }, ["end"] = { line = 0, character = 8 } },
      },
    },
    _era_cmp_meta = { source = "lsp" },
  }
  t.assert_false(Accept.apply(completed(item, "foo"), function() end), "overlapping edits")
  t.assert_eq("foo tail", vim.api.nvim_get_current_line(), "buffer text")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("applies initial edits and a resolve-only command", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "value " })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t:patch_table(vim.api, "nvim_set_vvar", function() end)
  executed = {}
  resolve_callback = nil

  local item = {
    label = "value",
    textEdit = {
      newText = "value",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 5 } },
    },
    additionalTextEdits = {
      {
        newText = "initial-",
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
      },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = 0,
  }
  Accept.apply(completed(item, "value"), function() end)
  t.assert_eq("initial-value ", vim.api.nvim_get_current_line(), "initial edits")

  assert(resolve_callback)(nil, { command = { command = "resolved" } })
  t.assert_eq(1, #executed, "resolved command count")
  t.assert_eq("resolved", executed[1].command, "resolved command")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("transforms same-line edits after a length-changing primary edit", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "longName X" })
  vim.api.nvim_win_set_cursor(0, { 1, 8 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t:patch_table(vim.api, "nvim_set_vvar", function() end)
  resolve_callback = nil

  local item = {
    label = "longName",
    textEdit = {
      newText = "longName",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    additionalTextEdits = {
      {
        newText = "Y",
        range = { start = { line = 0, character = 4 }, ["end"] = { line = 0, character = 5 } },
      },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = 0,
  }
  Accept.apply(completed(item, "longName"), function() end)
  t.assert_eq("longName Y", vim.api.nvim_get_current_line(), "transformed initial edit")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("transforms resolve-only edits after a length-changing primary edit", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "longName X" })
  vim.api.nvim_win_set_cursor(0, { 1, 8 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t:patch_table(vim.api, "nvim_set_vvar", function() end)
  resolve_callback = nil

  local item = {
    label = "longName",
    textEdit = {
      newText = "longName",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = 0,
  }
  Accept.apply(completed(item, "longName"), function() end)
  assert(resolve_callback)(nil, {
    additionalTextEdits = {
      {
        newText = "Y",
        range = { start = { line = 0, character = 4 }, ["end"] = { line = 0, character = 5 } },
      },
    },
  })
  t.assert_eq("longName Y", vim.api.nvim_get_current_line(), "transformed resolved edit")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("resolved multiline edits use the pre-accept text snapshot", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "foo ", "你x" })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t:patch_table(vim.api, "nvim_set_vvar", function() end)
  resolve_callback = nil
  resolve_snapshot = nil

  local item = {
    label = "foo bar",
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    textEdit = {
      newText = "foo\nbar",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_origin = {
      context = { row = 0, line = "f " },
    },
    _era_cmp_suffix_bytes = 0,
  }
  Accept.apply(completed(item, "foo bar"), function() end)
  t.assert_true(vim.deep_equal({ "f ", "你x" }, resolve_snapshot), "original text snapshot")

  assert(resolve_callback)(nil, {
    additionalTextEdits = {
      {
        newText = "Y",
        range = { start = { line = 1, character = 3 }, ["end"] = { line = 1, character = 4 } },
      },
    },
  })
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  t.assert_true(
    vim.deep_equal({ "foo", "bar ", "你Y" }, lines),
    "resolved edit after multiline primary: " .. vim.inspect(lines)
  )
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("replays complete multiline plain text before following edits", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "first X" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t:patch_table(vim.api, "nvim_set_vvar", function() end)
  resolve_callback = nil

  local item = {
    label = "first second",
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    textEdit = {
      newText = "first\r\nsecond\rthird",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    additionalTextEdits = {
      {
        newText = "Y",
        range = { start = { line = 0, character = 4 }, ["end"] = { line = 0, character = 5 } },
      },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = 0,
  }
  Accept.apply(completed(item, "first"), function() end)
  t.assert_true(
    vim.deep_equal({ "first", "second", "third Y" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)),
    "multiline primary"
  )
  t.assert_true(vim.deep_equal({ 3, 5 }, vim.api.nvim_win_get_cursor(0)), "multiline cursor")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("transforms edits around an expanded snippet", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_set_option_value("expandtab", true, { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", 4, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "preview X" })
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t:patch_table(vim.api, "nvim_set_vvar", function() end)
  resolve_callback = nil

  local item = {
    label = "foo bar",
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
    textEdit = {
      newText = "foo\r\n\tbar$0",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 2 } },
    },
    additionalTextEdits = {
      {
        newText = "Y",
        range = { start = { line = 0, character = 3 }, ["end"] = { line = 0, character = 4 } },
      },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = 0,
  }
  Accept.apply(completed(item, "preview"), function() end)
  local line = vim.api.nvim_get_current_line() ---@type string
  t.assert_eq(" Y", line:sub(-2), "transformed snippet tail")
  t.assert_false(line:find("YX", 1, true) ~= nil, "stale snippet coordinate")
  t.assert_false(
    vim.iter(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)):any(function(value)
      return value:find("\r", 1, true) ~= nil
    end),
    "snippet line endings"
  )
  vim.snippet.stop()
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("executes an initial command before delayed resolve", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "value " })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t:patch_table(vim.api, "nvim_set_vvar", function() end)
  executed = {}
  resolve_callback = nil

  local item = {
    label = "value",
    textEdit = {
      newText = "value",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 5 } },
    },
    command = { command = "initial" },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = 0,
  }
  Accept.apply(completed(item, "value"), function() end)
  t.assert_eq(1, #executed, "synchronous command count")
  t.assert_eq("initial", executed[1].command, "synchronous command")

  vim.api.nvim_buf_set_text(bufnr, 0, 5, 0, 5, { "x" })
  assert(resolve_callback)(nil, item)
  t.assert_eq(1, #executed, "initial command not repeated")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
