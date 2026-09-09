local harness = require("__test__.support.harness")
local nvim = require("stl.nvim.fn")
local suite = harness.new("era.m.cmp.editor")
local reports = {}
suite:patch_global("stl", {
  reporter = {
    error = function(value)
      reports[#reports + 1] = value
    end,
    warn = function(value)
      reports[#reports + 1] = value
    end,
  },
})
suite:patch_table(package.loaded, "era.m.cmp.bridge", {
  resolve = function(item, callback)
    callback(nil, item)
    return function() end
  end,
  execute_command = function() end,
})
local accept = require("era.m.cmp.accept")

---@param keys                          string
---@return nil
local function input(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
end

---@param opts                          ?table
---@return table
local function fixture(opts)
  opts = opts or {}
  reports = {}
  vim.snippet.stop()
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, opts.lines or { "", "" })
  vim.api.nvim_win_set_cursor(0, { 1, opts.col or 0 })
  suite:defer(function()
    input("<Esc>")
    vim.snippet.stop()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  local state = { bufnr = bufnr, records = 0 }
  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i" },
      key = "<F12>",
      callback = function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local base = { bufnr = bufnr, row = cursor[1] - 1, col = cursor[2], line = vim.api.nvim_get_current_line() }
        local item = {
          label = "alpha",
          textEdit = {
            newText = opts.text or "alpha",
            range = { start = { line = base.row, character = 0 }, ["end"] = { line = base.row, character = base.col } },
          },
          insertTextFormat = opts.snippet and vim.lsp.protocol.InsertTextFormat.Snippet or nil,
          additionalTextEdits = opts.edits,
          command = opts.command,
          _era_cmp_meta = { source = "test" },
          _era_cmp_suffix_bytes = opts.suffix or 0,
          _era_cmp_cursor_offset = opts.cursor_offset,
        }
        if opts.preview then
          vim.api.nvim_buf_set_lines(bufnr, base.row, base.row + 1, false, { opts.preview })
          vim.api.nvim_win_set_cursor(0, { base.row + 1, #opts.preview })
        end
        state.accepted = accept.apply(
          { word = item.textEdit.newText, user_data = { era_cmp = { item = item } } },
          function()
            state.records = state.records + 1
          end,
          base
        )
        state.immediate = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        state.cursor = vim.api.nvim_win_get_cursor(0)
        if opts.after_accept then
          opts.after_accept()
        end
      end,
    },
  }
  nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
  return state
end

suite:test("native repeat records the accepted text instead of the typed prefix", function()
  local state = fixture()
  input("ial<F12><Esc>")
  suite.assert_true(state.accepted, "acceptance")
  suite.assert_eq("alpha", state.immediate[1], "synchronous insertion")
  input("j0.")
  suite.assert_eq("alpha", vim.api.nvim_get_current_line(), "dot repeat")
  suite.assert_eq(1, state.records, "only explicit acceptance records usage")
  suite.assert_eq(0, #reports, "editor diagnostics")
end)

suite:test("acceptance creates one undo boundary after the original input", function()
  fixture()
  input("ial<F12><Esc>u")
  suite.assert_eq("al", vim.api.nvim_get_current_line(), "undo restores typed prefix")
  input("u")
  suite.assert_eq("", vim.api.nvim_get_current_line(), "second undo restores pre-insert text")
end)

suite:test("queued typing remains in both the real edit and native repeat", function()
  local state = fixture()
  input("ial<F12>z<Esc>")
  suite.assert_eq("alpha", state.immediate[1], "primary edit precedes queued input")
  suite.assert_eq("alphaz", vim.api.nvim_get_current_line(), "queued input")
  input("j0.")
  suite.assert_eq("alphaz", vim.api.nvim_get_current_line(), "repeat includes queued input")
end)

suite:test("repeat preserves Unicode prefixes and insertion commands", function()
  fixture({ text = "άλφα", lines = { "before", "after" } })
  input("ciwάλ<F12>z<Esc>")
  suite.assert_eq("άλφαz", vim.api.nvim_get_current_line(), "Unicode completion")
  input("j0.")
  suite.assert_eq("άλφαz", vim.api.nvim_get_current_line(), "ciw repeats as a change instead of an insertion")
end)

suite:test("an existing preview restores its original text before acceptance and undo", function()
  local state = fixture({ text = "futile", lines = { "future", "" }, col = 3, suffix = 3, preview = "futile" })
  input("i<F12><Esc>")
  suite.assert_eq("futile", state.immediate[1], "accepted preview")
  input("u")
  suite.assert_eq("future", vim.api.nvim_get_current_line(), "undo restores original suffix")
end)

suite:test("final snippet tabstops preserve the cursor and following input in repeat", function()
  local state = fixture({ text = "alpha($0)", snippet = true })
  input("ial<F12>z<Esc>")
  suite.assert_eq("alpha()", state.immediate[1], "synchronous bracket insertion")
  suite.assert_eq(6, state.cursor[2], "synchronous cursor inside brackets")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "typing inside brackets")
  input("j0.")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "repeat keeps bracket cursor movement")
end)

suite:test("multiline completion uses literal paste recording without replaying body edits", function()
  local state = fixture({ text = "alpha\nbeta" })
  input("ial<F12>z<Esc>")
  suite.assert_eq("alpha", state.immediate[1], "first line synchronous")
  suite.assert_eq("beta", state.immediate[2], "second line synchronous")
  suite.assert_eq("betaz", vim.api.nvim_get_current_line(), "queued multiline input")
  input("G0.")
  local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
  suite.assert_true(vim.deep_equal({ "alpha", "betaz", "alpha", "betaz" }, lines), "multiline native repeat")
end)

suite:test("repeat bookkeeping releases shadow resources and restores native completed_item", function()
  fixture()
  local buffers = vim.api.nvim_list_bufs()
  local winnrs = vim.api.nvim_list_wins()
  local completeopt = vim.api.nvim_get_option_value("completeopt", { buf = 0 })
  local eventignore = vim.api.nvim_get_option_value("eventignore", { scope = "global" })
  input("ial<F12><Esc>")
  suite.assert_eq(#buffers, #vim.api.nvim_list_bufs(), "no retained shadow buffer")
  suite.assert_eq(#winnrs, #vim.api.nvim_list_wins(), "no retained shadow window")
  suite.assert_eq(completeopt, vim.api.nvim_get_option_value("completeopt", { buf = 0 }), "completeopt restored")
  suite.assert_eq(
    eventignore,
    vim.api.nvim_get_option_value("eventignore", { scope = "global" }),
    "eventignore restored"
  )
  suite.assert_eq("alpha", vim.v.completed_item.word, "public completion value")
  suite.assert_nil(vim.v.completed_item.user_data.era_cmp, "private acceptance data removed")
  suite.assert_nil(vim.v.completed_item.user_data.era_cmp_repeat, "private recorder data removed")
end)

suite:test("mode changes ahead of bookkeeping cannot turn control keys into normal commands", function()
  local state = fixture({
    text = "alpha\nbeta",
    after_accept = function()
      vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "in", false)
    end,
  })
  input("ial<F12>")
  suite.assert_true(state.accepted, "primary edit still succeeds")
  suite.assert_eq("n", vim.fn.mode(), "normal mode retained")
  suite.assert_true(
    vim.deep_equal({ "alpha", "beta", "" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "no delayed body edit"
  )
  suite.assert_nil(vim.v.completed_item.user_data.era_cmp_repeat, "recorder ownership released")
end)

suite:test("recording failures restore editor globals without rejecting the accepted edit", function()
  local state = fixture()
  local buffers = vim.api.nvim_list_bufs()
  local eventignore = vim.api.nvim_get_option_value("eventignore", { scope = "global" })
  suite:patch_table(vim.fn, "complete", function()
    error("synthetic native completion failure")
  end)
  input("ial<F12><Esc>")
  suite.assert_true(state.accepted, "primary acceptance survives optional repeat failure")
  suite.assert_eq("alpha", vim.api.nvim_get_current_line(), "accepted text")
  suite.assert_eq(#buffers, #vim.api.nvim_list_bufs(), "shadow cleanup on failure")
  suite.assert_eq(
    eventignore,
    vim.api.nvim_get_option_value("eventignore", { scope = "global" }),
    "autocmd suppression restored"
  )
  suite.assert_eq(1, #reports, "one actionable diagnostic")
end)

suite:test("ready imports share the acceptance undo boundary but are not dot-repeated", function()
  local state = fixture({
    edits = {
      {
        newText = "import alpha\n",
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
      },
    },
  })
  input("ial<F12><Esc>u")
  suite.assert_true(
    vim.deep_equal({ "al", "" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "primary and imports undo together"
  )
  input("<C-r>G0.")
  suite.assert_true(
    vim.deep_equal({ "import alpha", "alpha", "alpha" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "only the insertion is repeated"
  )
end)

suite:test("native input ahead of bookkeeping invalidates its queued tail recording", function()
  local state = fixture({
    text = "alpha\nbeta",
    after_accept = function()
      vim.api.nvim_feedkeys("x", "in", false)
    end,
  })
  local calls = 0
  local paste = vim.api.nvim_paste
  suite:patch_table(vim.api, "nvim_paste", function(...)
    calls = calls + 1
    return paste(...)
  end)
  input("ial<F12><Esc>")
  suite.assert_true(state.accepted, "primary acceptance")
  suite.assert_eq(0, calls, "intervening input rejects stale tail recording")
  suite.assert_true(
    vim.deep_equal({ "alpha", "betax", "" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "external edit preserved"
  )
end)

suite:test("a completion command moving away from the inserted body cannot record an unrelated span", function()
  local state = fixture({ lines = { "", "other", "target" }, text = "alpha\nbeta", command = { command = "move" } })
  suite:patch_table(require("era.m.cmp.bridge"), "execute_command", function()
    vim.api.nvim_win_set_cursor(0, { 4, 4 })
  end)
  local calls = 0
  local complete = vim.fn.complete
  suite:patch_table(vim.fn, "complete", function(...)
    calls = calls + 1
    return complete(...)
  end)
  input("ial<F12>z<Esc>")
  suite.assert_true(state.accepted, "command remains part of acceptance")
  suite.assert_true(
    vim.deep_equal({ "alpha", "beta", "other", "targzet" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "command cursor and queued input are preserved"
  )
  suite.assert_eq(0, calls, "a different body cannot seed native redo")
  suite.assert_eq(0, #reports, "normal context invalidation is silent")
end)

suite:test("an existing call delimiter receives the cursor and participates in repeat", function()
  local state = fixture({ lines = { "()", "()" }, cursor_offset = 1 })
  input("ial<F12>z<Esc>")
  suite.assert_eq("alpha()", state.immediate[1], "existing delimiters preserved")
  suite.assert_eq(6, state.cursor[2], "cursor inside existing call")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "following argument input")
  input("j0.")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "repeat advances over the existing opening delimiter")
end)

suite:test("change tracking releases retired listeners and caps pending journals", function()
  local state = fixture({ lines = { "alpha tail" } })
  local editor = require("era.m.cmp.editor")
  local protected = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 5 } }
  local retired = editor.track(state.bufnr, protected)
  retired.close()
  local current = editor.track(state.bufnr, protected)
  for _ = 1, 257 do
    vim.api.nvim_buf_set_text(state.bufnr, 0, 5, 0, 5, { "x" })
  end
  local edits =
    { { newText = "import\n", range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } } } }
  suite.assert_nil(retired.rebase(edits), "retired tracker stays closed")
  suite.assert_nil(current.rebase(edits), "journal overflow cannot publish stale edits")
  current.close()
end)

suite:run()
