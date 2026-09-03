---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.cmp")

_G.yoz = require("yoz")

bootstrap.with_stl(t, {
  fs = {
    read_json = function()
      return {}
    end,
  },
  nvim = {
    fn = {
      augroup = function()
        return 1
      end,
    },
  },
  icon = {
    kind = { Function = "function" },
  },
  reporter = {
    error = function(value)
      error(vim.inspect(value), 0)
    end,
  },
})
bootstrap.with_dot(t, {
  path = {
    join = function(...)
      return table.concat({ ... }, "/")
    end,
  },
  var = {
    CMP_DOCUMENTATION_PREVIEW = "<preview>",
    CMP_DOCUMENTATION_SEPARATOR = "<separator>",
  },
})

local callbacks = {} ---@type table<string, function>
local completion_start_col = nil ---@type integer|nil
local completion_items = nil ---@type table[]|nil
t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
  local events = type(event) == "table" and event or { event }
  for _, name in ipairs(events) do
    callbacks[name] = opts.callback
  end
  return 1
end)
t:patch_table(vim.api, "nvim_list_bufs", function()
  return { vim.api.nvim_get_current_buf() }
end)
t:patch_table(vim.api, "nvim_get_mode", function()
  return { mode = "i" }
end)
t:patch_table(vim.lsp, "start", function()
  error("completion must not register a proxy LSP client", 0)
end)
t:patch_table(vim.lsp.completion, "enable", function()
  error("completion must not enable native LSP completion", 0)
end)
t:patch_table(vim.lsp.completion, "get", function()
  error("completion must request the bridge directly", 0)
end)
t:patch_table(vim.fn, "complete", function(start_col, items)
  completion_start_col = start_col
  completion_items = items
end)

local scheduled = {} ---@type fun()[]
t:patch_table(vim, "schedule", function(callback)
  scheduled[#scheduled + 1] = callback
end)

local timer_starts = 0 ---@type integer
local timer_delays = {} ---@type integer[]
local timer_callbacks = {} ---@type function[]
t:patch_table(vim.uv, "new_timer", function()
  return {
    stop = function() end,
    start = function(_, delay, _, callback)
      timer_starts = timer_starts + 1
      timer_delays[#timer_delays + 1] = delay
      timer_callbacks[#timer_callbacks + 1] = callback
    end,
    close = function() end,
  }
end)

t:patch_table(package.loaded, "era.m.cmp.keymap", {
  bind = function() end,
  bind_cmdline = function() end,
  release = function() end,
  reset = function() end,
  set_accept_intent = function(callback)
    callbacks.accept_intent = callback
  end,
  set_actions = function(value)
    callbacks.actions = value
  end,
  set_cmdline_actions = function(value)
    callbacks.cmdline_actions = value
  end,
  unbind = function() end,
})
t:patch_table(package.loaded, "era.m.cmp.cmdline", {
  accept = function()
    return false
  end,
  cancel = function()
    return false
  end,
  dressing = function() end,
  in_cmdwin = function()
    return false
  end,
  move = function()
    return false
  end,
  visible = function()
    return false
  end,
})
local accept_result = false
local accept_calls = 0
local accept_suffix_consumed = nil ---@type boolean|nil
t:patch_table(package.loaded, "era.m.cmp.accept", {
  apply = function(completed, record, suffix_consumed)
    accept_calls = accept_calls + 1
    accept_suffix_consumed = suffix_consumed
    if accept_result then
      record(completed)
    end
    return accept_result
  end,
})
local bridge_refresh = nil ---@type function|nil
local bridge_cancel_count = 0
local bridge_clear_count = 0
local bridge_resolve_request = nil ---@type { item: table, callback: function }|nil
local bridge_resolve_cancel_count = 0
local history_records = {} ---@type { key: string, now: integer }[]
local bridge_result = { isIncomplete = true, items = {} } ---@type lsp.CompletionList
local bridge_params = nil ---@type lsp.CompletionParams|nil
local bridge_request_count = 0 ---@type integer
t:patch_table(package.loaded, "era.m.cmp.bridge", {
  cancel = function()
    bridge_cancel_count = bridge_cancel_count + 1
  end,
  clear = function()
    bridge_clear_count = bridge_clear_count + 1
  end,
  get_usage_key = function(item)
    local meta = item._era_cmp_meta or (type(item.data) == "table" and item.data.era_cmp or nil)
    return meta and meta.usage_key or nil
  end,
  complete = function(params, callback)
    bridge_request_count = bridge_request_count + 1
    bridge_params = params
    callback(nil, bridge_result)
    return function() end
  end,
  register_commands = function() end,
  record_history = function(key, now)
    history_records[#history_records + 1] = { key = key, now = now }
  end,
  resolve = function(item, callback)
    bridge_resolve_request = { item = item, callback = callback }
    return function()
      bridge_resolve_cancel_count = bridge_resolve_cancel_count + 1
    end
  end,
  set_history = function() end,
  snapshot_history = function()
    return {}
  end,
  set_refresh = function(callback)
    bridge_refresh = callback
  end,
})
t:patch_table(package.loaded, "era.m.cmp.source", {
  clear_buffer = function() end,
  is_enabled = function()
    return true
  end,
})
local documentation_update = nil ---@type { selected: integer, word: string, text: string }|nil
local popup_visible = false
local popup_present = nil ---@type table|nil
local popup_dismissals = {} ---@type { owner: string, generation: integer|nil }[]
t:patch_table(package.loaded, "era.m.ui_attach.popupmenu", {
  dismiss = function(owner, generation)
    popup_visible = false
    popup_dismissals[#popup_dismissals + 1] = { owner = owner, generation = generation }
    return true
  end,
  present = function(owner, generation, items, selected, row, col, grid)
    popup_visible = true
    popup_present = {
      owner = owner,
      generation = generation,
      items = items,
      selected = selected,
      row = row,
      col = col,
      grid = grid,
    }
  end,
  select_owned = function(_, _, selected)
    if popup_present ~= nil then
      popup_present.selected = selected
    end
    return popup_visible
  end,
  update_owned_documentation = function(_, _, selected, word, text)
    documentation_update = { selected = selected, word = word, text = text }
  end,
  visible = function()
    return popup_visible
  end,
})
local trigger_kind = "keyword"
t:patch_table(package.loaded, "era.m.cmp.trigger", {
  characters = function()
    return {}
  end,
  classify = function()
    return trigger_kind
  end,
})
t:patch_table(package.loaded, "era.m.cmp.signature", {
  dressing = function() end,
  show = function()
    return true
  end,
  toggle = function()
    return true
  end,
})

local Cmp = require("era.m.cmp")
local Insert = require("era.m.cmp.insert")

---@param item                          era.m.cmp.ICompletionItem
---@return table
local function present(item)
  return Insert._to_completed_item(item)
end

---@param items                         era.m.cmp.ICompletionItem[]
---@return table
local function publish(items)
  popup_present = nil
  popup_visible = false
  bridge_result = { isIncomplete = true, items = items }
  Cmp.show()
  return assert(popup_present)
end

local function completion_item(label, suffix_bytes)
  return {
    label = label,
    textEdit = {
      newText = label,
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_suffix_bytes = suffix_bytes or 0,
  }
end

t:test("completion acceptance runs before queued user input", function()
  Cmp.dressing()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_set_current_line("vall")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  publish({ completion_item("value", 1) })

  accept_result = true
  t.assert_true(callbacks.actions.accept(bufnr), "accepted")
  callbacks.InsertCharPre({ buf = bufnr })
  callbacks.TextChangedI({ buf = bufnr })
  t.assert_eq(1, timer_starts, "queued user edit")
  accept_result = false
end)

t:test("ordinary typing commits preview without accepting it", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_set_current_line("vall")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  local presentation = publish({ completion_item("value", 1) })
  callbacks.actions.move(bufnr, 1)
  local before = accept_calls
  local dismissals_before = #popup_dismissals
  local scheduled_before = #scheduled

  t:patch_table(vim.v, "char", "s")
  callbacks.InsertCharPre({ buf = bufnr })

  t.assert_eq(before, accept_calls, "implicit acceptance")
  t.assert_eq("value", vim.api.nvim_get_current_line(), "committed preview")
  t.assert_eq(dismissals_before, #popup_dismissals, "no textlocked popup dismissal")
  t.assert_eq(scheduled_before + 1, #scheduled, "deferred popup dismissal")

  scheduled[scheduled_before + 1]()
  local dismissal = popup_dismissals[#popup_dismissals]
  t.assert_eq("era-cmp-insert", dismissal.owner, "dismiss owner")
  t.assert_eq(presentation.generation, dismissal.generation, "dismiss generation")
end)

t:test("explicit acceptance records the semantic usage identity", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_set_current_line("vall")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  local item = completion_item("value", 1)
  item._era_cmp_meta.usage_key = "buffer\0value"
  publish({ item })
  local before = #history_records
  accept_result = true

  t.assert_true(callbacks.actions.accept(bufnr), "accepted")
  accept_result = false

  t.assert_eq(before + 1, #history_records, "record count")
  t.assert_eq("buffer\0value", history_records[#history_records].key, "usage key")
end)

t:test("mid-token preview owns replacement suffix lifecycle", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local first = completion_item("futon", 3)
  local second = completion_item("futile", 3)

  local function begin_preview()
    vim.api.nvim_set_current_line("future")
    vim.api.nvim_win_set_cursor(0, { 1, 3 })
    publish({ first, second })
    callbacks.actions.move(bufnr, 1)
    t.assert_eq("futile", vim.api.nvim_get_current_line(), "selected preview")
  end

  begin_preview()
  callbacks.actions.move(bufnr, 1)
  t.assert_eq("future", vim.api.nvim_get_current_line(), "wrapped original")

  begin_preview()
  t.assert_true(callbacks.actions.cancel(bufnr), "cancel")
  t.assert_eq("future", vim.api.nvim_get_current_line(), "restored suffix")

  begin_preview()
  t:patch_table(vim.v, "char", "a")
  callbacks.InsertCharPre({ buf = bufnr })
  t.assert_eq("futile", vim.api.nvim_get_current_line(), "typed input commits preview")

  begin_preview()
  accept_result = true
  accept_suffix_consumed = nil
  callbacks.actions.accept(bufnr)
  t.assert_true(accept_suffix_consumed, "preview suffix consumed")
  t.assert_eq("futile", vim.api.nvim_get_current_line(), "accepted preview")
  accept_result = false
end)

t:test("steady-state selection replaces the preview with one buffer write", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_set_current_line("future")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  publish({ completion_item("futon", 3), completion_item("futile", 3), completion_item("fusion", 3) })
  callbacks.actions.move(bufnr, 1)

  local writes = 0
  local set_lines = vim.api.nvim_buf_set_lines
  t:patch_table(vim.api, "nvim_buf_set_lines", function(...)
    writes = writes + 1
    return set_lines(...)
  end)
  callbacks.actions.move(bufnr, 1)

  t.assert_eq(1, writes, "candidate-to-candidate writes")
  t.assert_eq("fusion", vim.api.nvim_get_current_line(), "replacement preview")
end)

t:test("explicit hide restores preview and clears owned state", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_set_current_line("future")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  publish({ completion_item("futile", 3) })
  callbacks.actions.move(bufnr, 1)
  local clears_before = bridge_clear_count

  Cmp.hide()

  t.assert_eq("future", vim.api.nvim_get_current_line(), "restored input")
  t.assert_false(popup_visible, "hidden popup")
  t.assert_eq(clears_before + 1, bridge_clear_count, "bridge clear")
end)

t:test("leaving insert mode restores an unaccepted preview", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_set_current_line("future")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  publish({ completion_item("futile", 3) })
  callbacks.actions.move(bufnr, 1)
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "n" }
  end)

  callbacks.InsertLeave({ buf = bufnr })

  t.assert_eq("future", vim.api.nvim_get_current_line(), "restored input")
  t.assert_false(popup_visible, "hidden popup")
end)

t:test("typing while visible requests incomplete completion", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_set_current_line("vall")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  publish({ completion_item("value", 1) })
  bridge_params = nil
  timer_callbacks = {}
  trigger_kind = "keyword"
  t:patch_table(vim.v, "char", "u")

  callbacks.InsertCharPre({ buf = bufnr })
  callbacks.TextChangedI({ buf = bufnr })
  local timer_callback = assert(timer_callbacks[#timer_callbacks])
  local scheduled_before = #scheduled
  timer_callback()
  assert(scheduled[scheduled_before + 1])()

  t.assert_eq(
    vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions,
    assert(bridge_params).context.triggerKind,
    "trigger kind"
  )
end)

t:test("backspace refresh waits for the resulting text change", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  vim.api.nvim_set_current_line("vall")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  publish({ completion_item("value", 1) })
  callbacks.actions.move(bufnr, 1)
  local starts_before = timer_starts
  trigger_kind = "keyword"

  callbacks.actions.backspace(bufnr)
  t.assert_eq(starts_before, timer_starts, "no pre-delete refresh")
  vim.api.nvim_set_current_line("val")
  callbacks.TextChangedI({ buf = bufnr })

  t.assert_eq(starts_before + 1, timer_starts, "post-delete refresh")
end)

t:test("selection documentation is generation guarded", function()
  local item = completion_item("value")
  item._era_cmp_origin = {
    client_id = 81,
    context = {},
    item = { label = "value" },
    start_col = 0,
    suffix_bytes = 0,
    target_start_col = 0,
  }
  vim.api.nvim_set_current_line("vall")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  local scheduled_before = #scheduled
  bridge_resolve_request = nil
  documentation_update = nil
  publish({ item })
  assert(scheduled[scheduled_before + 1])()
  local request = assert(bridge_resolve_request)

  publish({ completion_item("other") })
  local resolved = vim.deepcopy(item)
  resolved.detail = "resolved detail"
  request.callback(nil, resolved)

  t.assert_nil(documentation_update, "stale generation")
end)

t:test("accepted trigger character schedules chained completion", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local scheduled_before = #scheduled
  timer_starts = 0
  trigger_kind = "trigger_character"
  vim.api.nvim_set_current_line("dirx")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  publish({ completion_item("dir/", 1) })
  accept_result = true

  callbacks.actions.accept(bufnr)
  assert(scheduled[scheduled_before + 1])()

  t.assert_eq(1, timer_starts, "chained request")
  accept_result = false
  trigger_kind = "keyword"
end)

t:test("insert view projection and selection stay within the popup budget", function()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local items = {} ---@type era.m.cmp.ICompletionItem[]
  for index = 1, 200 do
    items[index] = completion_item(string.format("item_%03d", index), 1)
  end
  vim.api.nvim_set_current_line("itx")
  vim.api.nvim_win_set_cursor(0, { 1, 2 })
  local started = vim.uv.hrtime()
  publish(items)
  local publish_ms = (vim.uv.hrtime() - started) / 1000000
  started = vim.uv.hrtime()
  callbacks.actions.move(bufnr, 1)
  local select_ms = (vim.uv.hrtime() - started) / 1000000

  print(string.format("BENCH cmp insert publish200=%.3fms select=%.3fms", publish_ms, select_ms))
  t.assert_true(publish_ms < 10, string.format("insert publish %.3fms", publish_ms))
  t.assert_true(select_ms < 2, string.format("insert selection %.3fms", select_ms))
end)

t:test("insert rows carry query-relative fuzzy match highlights", function()
  local query = nil
  local labels = nil
  local matched_ranges = yoz.cmp.matched_ranges
  t:patch_table(yoz.cmp, "matched_ranges", function(value, values)
    query = value
    labels = values
    return matched_ranges(value, values)
  end)
  vim.api.nvim_set_current_line("cpx")
  vim.api.nvim_win_set_cursor(0, { 1, 2 })

  local presentation = publish({ completion_item("Com\npletion", 0) })

  t.assert_eq("cp", query, "query")
  t.assert_eq("Com↲pletion", labels[1], "display label")
  t.assert_eq("Com↲pletion", presentation.items[1][1], "popup label")
  t.assert_true(vim.deep_equal({ 0, 1, "PmenuMatch", 150 }, presentation.items[1][7][1]), "first match range")
  t.assert_true(vim.deep_equal({ 6, 7, "PmenuMatch", 150 }, presentation.items[1][7][2]), "second match range")
end)

t:test("auto brackets preserve an existing call delimiter", function()
  vim.api.nvim_set_current_line("old")
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  local item = {
    label = "newName",
    kind = vim.lsp.protocol.CompletionItemKind.Function,
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    textEdit = {
      newText = "newName",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 3 } },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_origin = {
      context = { line = "old(arg)", col = 3 },
      start_col = 0,
      suffix_bytes = 0,
      target_start_col = 0,
    },
  }
  present(item)
  t.assert_eq("newName", item.textEdit.newText, "existing parenthesis")
  t.assert_eq(vim.lsp.protocol.InsertTextFormat.PlainText, item.insertTextFormat, "plain insertion")

  item.insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet
  item.textEdit.newText = "newName(${1:value})"
  present(item)
  t.assert_eq("newName", item.textEdit.newText, "existing parenthesis with upstream snippet")

  item.textEdit.newText = "newName(${1:value})"
  item._era_cmp_origin.context.line = "old   (arg)"
  present(item)
  t.assert_eq("newName", item.textEdit.newText, "whitespace-delimited parenthesis")

  item.insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText
  item.textEdit.newText = "newName"
  item._era_cmp_origin.context.line = "old"
  local converted = present(item)
  t.assert_eq("newName($0)", item.textEdit.newText, "missing parenthesis")
  t.assert_eq(vim.lsp.protocol.InsertTextFormat.Snippet, item.insertTextFormat, "snippet insertion")
  t.assert_eq("newName", converted.word, "Blink-style LSP preview word")
  t.assert_eq(1, converted.equal, "bridge owns candidate filtering")
end)

t:test("auto brackets follow Blink filetype and kind policy", function()
  local function item(filetype, line, kind, format, new_text, col)
    col = col or #line
    return {
      label = new_text,
      kind = kind,
      insertTextFormat = format,
      textEdit = {
        newText = new_text,
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = col } },
      },
      _era_cmp_meta = { source = "lsp" },
      _era_cmp_origin = {
        context = { line = line, col = col, filetype = filetype },
        start_col = 0,
        suffix_bytes = 0,
        target_start_col = 0,
      },
    }
  end

  local constructor = item(
    "lua",
    "Thing",
    vim.lsp.protocol.CompletionItemKind.Constructor,
    vim.lsp.protocol.InsertTextFormat.PlainText,
    "Thing"
  )
  present(constructor)
  t.assert_eq("Thing", constructor.textEdit.newText, "constructor")

  local rust = item(
    "rust",
    "function",
    vim.lsp.protocol.CompletionItemKind.Function,
    vim.lsp.protocol.InsertTextFormat.PlainText,
    "function"
  )
  present(rust)
  t.assert_eq("function", rust.textEdit.newText, "blocked rust")

  local python_import = item(
    "python",
    "from module import function",
    vim.lsp.protocol.CompletionItemKind.Function,
    vim.lsp.protocol.InsertTextFormat.PlainText,
    "function"
  )
  present(python_import)
  t.assert_eq("function", python_import.textEdit.newText, "python import")

  local css_line = ".button:hov {}"
  local css = item(
    "css",
    css_line,
    vim.lsp.protocol.CompletionItemKind.Function,
    vim.lsp.protocol.InsertTextFormat.PlainText,
    "hover",
    #".button:hov"
  )
  present(css)
  t.assert_eq("hover", css.textEdit.newText, "CSS cursor prefix")

  for _, filetype in ipairs({ "javascriptreact", "typescriptreact", "vue" }) do
    local blocked = item(
      filetype,
      "component",
      vim.lsp.protocol.CompletionItemKind.Function,
      vim.lsp.protocol.InsertTextFormat.PlainText,
      "component"
    )
    present(blocked)
    t.assert_eq("component", blocked.textEdit.newText, "blocked " .. filetype)
  end

  local shell = item(
    "sh",
    "function",
    vim.lsp.protocol.CompletionItemKind.Function,
    vim.lsp.protocol.InsertTextFormat.PlainText,
    "function"
  )
  present(shell)
  t.assert_eq("function ", shell.textEdit.newText, "shell separator")
  t.assert_eq(vim.lsp.protocol.InsertTextFormat.PlainText, shell.insertTextFormat, "shell insertion")

  local snippet = item(
    "lua",
    "function",
    vim.lsp.protocol.CompletionItemKind.Function,
    vim.lsp.protocol.InsertTextFormat.Snippet,
    "function"
  )
  present(snippet)
  t.assert_eq("function($1)", snippet.textEdit.newText, "snippet function")

  for _, new_text in ipairs({ "function$0", "function${0}" }) do
    local final_tabstop = item(
      "lua",
      "function",
      vim.lsp.protocol.CompletionItemKind.Function,
      vim.lsp.protocol.InsertTextFormat.Snippet,
      new_text
    )
    present(final_tabstop)
    t.assert_eq(new_text, final_tabstop.textEdit.newText, "existing final tabstop")
  end
end)

t:test("LSP snippet previews preserve normalized missing prefixes", function()
  vim.api.nvim_set_current_line("object.met")
  vim.api.nvim_win_set_cursor(0, { 1, 10 })
  local item = {
    label = "method",
    kind = vim.lsp.protocol.CompletionItemKind.Text,
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
    textEdit = {
      newText = "object.method(${1:value})",
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 7 } },
    },
    _era_cmp_meta = { source = "lsp" },
    _era_cmp_origin = {
      context = { line = "object.met", col = 10 },
      start_col = 7,
      suffix_bytes = 0,
      target_start_col = 0,
    },
  }

  local converted = present(item)

  t.assert_eq("object.method", converted.word, "normalized preview")
end)

t:test("snippet previews preserve balanced leading delimiters", function()
  local cases = {
    {
      label = "hash",
      snippet = '"${1:sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=}";',
      preview = '"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="',
    },
    {
      label = "arrow",
      snippet = "(${1:arguments}) => ${2:statement}",
      preview = "(arguments)",
    },
  }

  for _, case in ipairs(cases) do
    vim.api.nvim_set_current_line(case.label)
    vim.api.nvim_win_set_cursor(0, { 1, #case.label })
    local item = {
      label = case.label,
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      textEdit = {
        newText = case.snippet,
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = #case.label } },
      },
      _era_cmp_meta = { source = "snippets" },
    }

    t.assert_eq(case.preview, present(item).word, case.label)
  end
end)

t:test("snippet documentation previews the accepted insertion snapshot", function()
  local uuid = "00010203-0405-4607-8809-0a0b0c0d0e0f"
  vim.api.nvim_set_current_line("uuid")
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  local item = {
    label = "uuid",
    kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
    documentation = { kind = "plaintext", value = "A Version 4 UUID" },
    textEdit = {
      newText = uuid,
      range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 4 } },
    },
    _era_cmp_meta = { source = "snippets" },
  }

  local converted = present(item)

  t.assert_eq("<preview>" .. uuid .. "<separator>A Version 4 UUID", converted.info, "snippet preview")
  t.assert_eq("Special", converted.source_hlgroup, "snippet source")
  t.assert_eq(uuid, converted.word, "native preview word")
  t.assert_eq(1, converted.equal, "bridge filtering")
  t.assert_eq(uuid, item.textEdit.newText, "accepted snapshot")
end)

t:test("local non-snippet documentation remains visible", function()
  local item = {
    label = "completion",
    kind = vim.lsp.protocol.CompletionItemKind.Text,
    documentation = { kind = "plaintext", value = "The act of completing something." },
    insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
    _era_cmp_meta = { source = "dict" },
  }

  local converted = present(item)

  t.assert_eq("The act of completing something.", converted.info, "local documentation")
  t.assert_eq("Constant", converted.source_hlgroup, "dictionary source")
end)

t:test("LSP label descriptions remain visible in the menu projection", function()
  local item = completion_item("map\nvalue", 0)
  item.kind = vim.lsp.protocol.CompletionItemKind.Method
  item.labelDetails = { detail = "\r\n()", description = "vim\riter" }

  local converted = present(item)

  t.assert_eq("map↲value↲()", converted.abbr, "label detail")
  t.assert_eq("vim↲iter", converted.label_description, "label description")
  t.assert_eq("Function", converted.kind_hlgroup, "kind highlight")
end)

t:run()
