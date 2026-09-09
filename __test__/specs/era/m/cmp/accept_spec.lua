---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.cmp.accept")

bootstrap.with_stl(t, {
  reporter = {
    error = function() end,
    warn = function() end,
  },
})

local resolve_callback
local resolve_snapshot = nil ---@type (fun(): string[]|nil)|nil
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

---@param item                          table
---@param word                          string
---@return table
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
  t.assert_true(
    Accept.apply(completed(item, "futon"), function() end, {
      bufnr = bufnr,
      row = 0,
      col = 3,
      line = "futXYZtail",
    }),
    "accepted preview"
  )
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
  t.assert_nil(sanitized, "failed preflight leaves completed_item unchanged")
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
  t.assert_true(vim.deep_equal({ "f ", "你x" }, resolve_snapshot()), "original text snapshot")

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

---@return integer, table
local function ready_item()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "al " })
  vim.api.nvim_win_set_cursor(0, { 1, 2 })
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  return bufnr,
    {
      label = "alpha",
      textEdit = {
        newText = "alpha",
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 2 } },
      },
      _era_cmp_meta = { source = "lsp" },
    }
end

t:test("ready resolve starts on restored input and applies imports without changing the selected insertion", function()
  local bufnr, item = ready_item()
  vim.api.nvim_set_current_line("alpha ")
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  local requested_line
  local resolved = vim.deepcopy(item)
  resolved.textEdit.newText = "different server text"
  resolved.additionalTextEdits = {
    {
      newText = "import alpha\n",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
    },
  }
  t:patch_table(bridge, "resolve", function(_, callback)
    requested_line = vim.api.nvim_get_current_line()
    callback(nil, resolved)
    return function() end
  end)
  t.assert_true(
    Accept.apply(completed(item, "alpha"), function() end, { bufnr = bufnr, row = 0, col = 2, line = "al " }),
    "accepted cached item"
  )
  t.assert_eq("al ", requested_line, "resolve sees the request text, not its preview")
  t.assert_true(
    vim.deep_equal({ "import alpha", "alpha " }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)),
    "ready imports and stable primary text"
  )
end)

t:test("invalid ready side effects fail before the primary edit and cancel their subscription", function()
  local bufnr, item = ready_item()
  local cancelled = 0
  local records = 0
  local resolved = vim.deepcopy(item)
  resolved.additionalTextEdits = {
    { newText = "overlap", range = { start = { line = 0, character = 1 }, ["end"] = { line = 0, character = 2 } } },
  }
  t:patch_table(bridge, "resolve", function(_, callback)
    callback(nil, resolved)
    return function()
      cancelled = cancelled + 1
    end
  end)
  t.assert_false(
    Accept.apply(completed(item, "alpha"), function()
      records = records + 1
    end),
    "invalid cached side effects"
  )
  t.assert_eq("al ", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "original text remains")
  t.assert_eq(0, records, "no usage record on failure")
  t.assert_eq(1, cancelled, "subscription cleanup")
end)

t:test("safe late imports survive typing while stale commands and conflicting edits are rejected", function()
  for _, change in ipairs({ "typing", "cursor", "overlap", "mode", "wipe" }) do
    local bufnr, item = ready_item()
    local mode = "i"
    t:patch_table(vim.api, "nvim_get_mode", function()
      return { mode = mode }
    end)
    executed = {}
    t.assert_true(Accept.apply(completed(item, "alpha"), function() end), "primary acceptance")
    if change == "typing" then
      vim.api.nvim_buf_set_text(bufnr, 0, 5, 0, 5, { "z" })
    elseif change == "cursor" then
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    elseif change == "overlap" then
      vim.api.nvim_buf_set_text(bufnr, 0, 1, 0, 2, { "x" })
    elseif change == "mode" then
      mode = "n"
    else
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    assert(resolve_callback)(nil, {
      additionalTextEdits = {
        {
          newText = "import alpha\n",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
        },
      },
      command = { command = "late" },
    })
    t.assert_eq(0, #executed, change .. " suppresses stale commands")
    if vim.api.nvim_buf_is_valid(bufnr) then
      local safe = change == "typing" or change == "cursor"
      t.assert_eq(safe and 2 or 1, vim.api.nvim_buf_line_count(bufnr), change .. " respects edit-level validity")
      if change == "typing" then
        t.assert_eq("alphaz ", vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1], "new input survives the import")
      end
    end
  end
end)

t:test("late edits rebase past multiline input and preserve their original target", function()
  local bufnr, item = ready_item()
  vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { "target" })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  t.assert_true(Accept.apply(completed(item, "alpha"), function() end), "primary acceptance")
  vim.api.nvim_buf_set_text(bufnr, 0, 5, 0, 5, { "(", "value", ")" })
  resolve_callback(nil, {
    additionalTextEdits = {
      { newText = "updated", range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 6 } } },
    },
  })
  t.assert_true(
    vim.deep_equal({ "alpha(", "value", ") ", "updated" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)),
    "rebased edit preserves intervening input"
  )
end)

t:test("an overlap with one late target rejects the entire edit batch", function()
  local bufnr, item = ready_item()
  vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { "target" })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  Accept.apply(completed(item, "alpha"), function() end)
  vim.api.nvim_buf_set_text(bufnr, 1, 1, 1, 2, { "X" })
  resolve_callback(nil, {
    additionalTextEdits = {
      {
        newText = "import alpha\n",
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
      },
      { newText = "updated", range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 6 } } },
    },
  })
  t.assert_true(
    vim.deep_equal({ "alpha ", "tXrget" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)),
    "no partial late batch"
  )
end)

t:test("mutually overlapping late edits cannot partially modify the buffer", function()
  local bufnr, item = ready_item()
  vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, { "target" })
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  Accept.apply(completed(item, "alpha"), function() end)
  resolve_callback(nil, {
    additionalTextEdits = {
      {
        newText = "import alpha\n",
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
      },
      { newText = "updated", range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 6 } } },
      { newText = "overlap", range = { start = { line = 1, character = 1 }, ["end"] = { line = 1, character = 3 } } },
    },
  })
  t.assert_true(
    vim.deep_equal({ "alpha ", "target" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)),
    "invalid late batch leaves all targets intact"
  )
end)

t:test("a new acceptance retires older resolve subscriptions", function()
  local bufnr, item = ready_item()
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  Accept.apply(completed(item, "alpha"), function() end)
  local previous = resolve_callback
  local next_item = vim.deepcopy(item)
  next_item.label = "beta"
  next_item.textEdit.newText = "beta"
  next_item.textEdit.range["end"].character = 5
  Accept.apply(completed(next_item, "beta"), function() end)
  previous(nil, {
    additionalTextEdits = {
      {
        newText = "obsolete\n",
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
      },
    },
  })
  t.assert_eq("beta ", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "older acceptance cannot publish")
  Accept.cancel(bufnr)
end)

t:test("resolve completion inside an initial command waits for the primary transaction to commit", function()
  local bufnr, item = ready_item()
  item.command = { command = "initial" }
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i" }
  end)
  local calls = 0
  t:patch_table(bridge, "execute_command", function()
    calls = calls + 1
    resolve_callback(nil, {
      additionalTextEdits = {
        {
          newText = "import alpha\n",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
        },
      },
    })
    t.assert_eq("alpha ", vim.api.nvim_get_current_line(), "no reentrant body mutation")
  end)
  t.assert_true(Accept.apply(completed(item, "alpha"), function() end), "primary acceptance")
  t.assert_true(
    vim.deep_equal({ "import alpha", "alpha " }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)),
    "queued resolution settles after commit"
  )
  t.assert_eq(1, calls, "initial command runs once")
end)

t:test("ready resolve avoids copying the complete buffer snapshot", function()
  local _, item = ready_item()
  t:patch_table(bridge, "resolve", function(_, callback, snapshot)
    t.assert_nil(snapshot(), "ready resolution reads the unmodified buffer")
    callback(nil, item)
    return function() end
  end)
  local reads = 0
  local get_lines = vim.api.nvim_buf_get_lines
  t:patch_table(vim.api, "nvim_buf_get_lines", function(bufnr, first, last, ...)
    if first == 0 and last == -1 then
      reads = reads + 1
    end
    return get_lines(bufnr, first, last, ...)
  end)
  Accept.apply(completed(item, "alpha"), function() end)
  t.assert_eq(0, reads, "no whole-buffer copy on the ready path")
end)

t:test("cold resolve waits at most the acceptance budget and preserves the original input", function()
  local _, item = ready_item()
  local waits = 0
  t:patch_table(vim, "wait", function(timeout, condition)
    waits = waits + 1
    t.assert_eq(100, timeout, "bounded resolve budget")
    t.assert_false(condition(), "pending request")
    t.assert_eq("al ", vim.api.nvim_get_current_line(), "server observes the original document")
    resolve_callback(nil, {
      additionalTextEdits = {
        {
          newText = "import alpha\n",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
        },
      },
    })
    t.assert_true(condition(), "ready resolve ends the wait")
    return true, nil
  end)
  t.assert_true(Accept.apply(completed(item, "alpha"), function() end), "accepted after bounded wait")
  t.assert_eq(1, waits, "one acceptance wait")
  t.assert_true(
    vim.deep_equal({ "import alpha", "alpha " }, vim.api.nvim_buf_get_lines(0, 0, -1, false)),
    "resolved edits share the primary transaction"
  )
end)

t:test("cached resolve never enters the acceptance wait", function()
  local _, item = ready_item()
  t:patch_table(bridge, "resolve", function(_, callback)
    callback(nil, item)
    return function() end
  end)
  t:patch_table(vim, "wait", function()
    error("ready resolve must not wait")
  end)
  t.assert_true(Accept.apply(completed(item, "alpha"), function() end), "zero-wait acceptance")
end)

t:test("invalidated input or an interrupted wait cannot apply the primary edit", function()
  for _, change in ipairs({ "text", "cursor", "mode", "buffer", "cancel", "interrupt" }) do
    local bufnr, item = ready_item()
    local mode = "i"
    t:patch_table(vim.api, "nvim_get_mode", function()
      return { mode = mode }
    end)
    local cancelled = 0
    t:patch_table(bridge, "resolve", function(_, callback)
      resolve_callback = callback
      return function()
        cancelled = cancelled + 1
      end
    end)
    t:patch_table(vim, "wait", function(_, condition)
      if change == "text" then
        vim.api.nvim_buf_set_text(bufnr, 0, 2, 0, 2, { "z" })
      elseif change == "cursor" then
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
      elseif change == "mode" then
        mode = "n"
      elseif change == "buffer" then
        local other = vim.api.nvim_create_buf(false, true)
        t:defer(function()
          vim.api.nvim_buf_delete(other, { force = true })
        end)
        vim.api.nvim_set_current_buf(other)
      elseif change == "cancel" then
        Accept.cancel(bufnr)
      else
        return false, -2
      end
      t.assert_true(condition(), change .. " ends the wait")
      resolve_callback(nil, { command = { command = "obsolete" } })
      return true, nil
    end)
    local records = 0
    t.assert_false(
      Accept.apply(completed(item, "alpha"), function()
        records = records + 1
      end),
      change .. " prevents acceptance"
    )
    t.assert_eq(
      change == "text" and "alz " or "al ",
      vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1],
      "newer context is untouched"
    )
    t.assert_eq(0, records, "no usage recorded for rejected acceptance")
    t.assert_eq(1, cancelled, "resolve subscription released")
  end
end)

t:run()
