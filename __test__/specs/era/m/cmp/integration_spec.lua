local harness = require("__test__.support.harness")
local nvim = require("stl.nvim.fn")
local semantic_tokens = require("vim.lsp.semantic_tokens")
local suite = harness.new("era.m.cmp.integration")
local buffers = {}
local clients = {}
local reports = {}
local surface = nil
local publications = {}

suite:patch_global("yoz", require("yoz"))
suite:patch_global("stl", {
  nvim = { fn = nvim },
  icon = { kind = {} },
  fs = {
    read_json = function()
      return {}
    end,
    write_json = function() end,
  },
  reporter = {
    warn = function(value)
      reports[#reports + 1] = value
    end,
    error = function(value)
      reports[#reports + 1] = value
    end,
  },
})
suite:patch_global("dot", {
  path = {
    join = function(...)
      return table.concat({ ... }, "/")
    end,
  },
  var = {
    N_CMP_DOCUMENTATION = "cmp-test-doc",
    CMP_DOCUMENTATION_PREVIEW = "<preview>",
    CMP_DOCUMENTATION_SEPARATOR = "<separator>",
  },
})
suite:patch_table(vim.lsp, "get_clients", function(opts)
  local state = buffers[opts and opts.bufnr or vim.api.nvim_get_current_buf()]
  return state and state.client and { state.client } or {}
end)
suite:patch_table(vim.lsp, "get_client_by_id", function(client_id)
  return clients[client_id]
end)
suite:patch_table(package.loaded, "era.m.cmp.source.snippets", {
  trigger_characters = function()
    return {}
  end,
})
suite:patch_table(package.loaded, "era.m.cmp.source", {
  is_enabled = function(bufnr)
    return buffers[bufnr] ~= nil
  end,
  clear_buffer = function() end,
  complete = function(params, _, callback, bufnr)
    local state = buffers[bufnr]
    local items = {}
    for _, label in ipairs(state and state.labels or {}) do
      items[#items + 1] = {
        label = label,
        _era_cmp_path = state.paths[label],
        textEdit = {
          newText = label,
          range = { start = { line = params.position.line, character = 0 }, ["end"] = params.position },
        },
        _era_cmp_meta = {
          source = "buffer",
          priority = 100,
          score = 100,
          exact = false,
          usage_key = "buffer\0" .. label,
        },
      }
    end
    local result = { isIncomplete = false, items = items }
    callback(result)
    return function() end, function()
      return result
    end
  end,
})
suite:patch_table(package.loaded, "era.m.cmp.signature", {
  dressing = function() end,
  show = function()
    return false
  end,
  toggle = function()
    return false
  end,
})
suite:patch_table(package.loaded, "era.m.cmp.cmdline", {
  dressing = function() end,
  in_cmdwin = function()
    return false
  end,
  visible = function()
    return false
  end,
  accept = function()
    return false
  end,
  cancel = function()
    return false
  end,
  move = function()
    return false
  end,
  show = function()
    return false
  end,
})
suite:patch_table(package.loaded, "era.dressing.ui_attach.popupmenu", {
  present = function(owner, generation, rows, selected)
    surface = { owner = owner, generation = generation, rows = rows, selected = selected }
    publications[#publications + 1] = surface
  end,
  visible = function(owner, generation)
    return surface ~= nil and surface.owner == owner and surface.generation == generation
  end,
  dismiss = function(owner, generation)
    if surface ~= nil and surface.owner == owner and surface.generation == generation then
      surface = nil
    end
  end,
  select_owned = function(owner, generation, selected)
    if surface ~= nil and surface.owner == owner and surface.generation == generation then
      surface.selected = selected
      return true
    end
    return false
  end,
  update_owned_documentation = function(owner, generation, selected, _, text)
    if
      surface ~= nil
      and surface.owner == owner
      and surface.generation == generation
      and surface.selected == selected
    then
      surface.documentation = text
    end
  end,
})

local cmp = require("era.m.cmp")
local bridge = require("era.m.cmp.bridge")
cmp.dressing()
suite:defer(function()
  vim.api.nvim_del_augroup_by_name("guanghechen_era.m.cmp.insert.dressing")
end)

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
  publications = {}
  surface = nil
  local bufnr = vim.api.nvim_create_buf(true, false)
  local state = {
    bufnr = bufnr,
    labels = opts.labels or { "alpha" },
    paths = opts.paths or {},
    completions = {},
    resolves = {},
    cancellations = {},
  }
  buffers[bufnr] = state
  if opts.lsp_items ~= nil then
    state.client = {
      id = bufnr + 1000,
      name = "integration-lsp",
      offset_encoding = opts.encoding or "utf-8",
      server_capabilities = { completionProvider = { triggerCharacters = { "." } } },
      supports_method = function(_, method)
        return method == "completionItem/resolve" and opts.resolve == true
      end,
      request = function(_, method, item, callback)
        if method == "textDocument/completion" then
          state.completions[#state.completions + 1] = callback
          if not opts.defer_completion then
            callback(nil, { isIncomplete = false, items = vim.deepcopy(opts.lsp_items) })
          end
        else
          state.resolves[#state.resolves + 1] =
            { item = item, callback = callback, line = vim.api.nvim_get_current_line() }
        end
        return true, #state.completions + #state.resolves
      end,
      cancel_request = function(_, request_id)
        state.cancellations[#state.cancellations + 1] = request_id
      end,
    }
    clients[state.client.id] = state.client
  end
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_set_option_value("filetype", opts.filetype or "lua", { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, opts.lines or { "", "" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  suite:defer(function()
    input("<Esc>")
    require("era.m.cmp.accept").cancel(bufnr)
    bridge.dispose(bufnr)
    if state.client then
      clients[state.client.id] = nil
    end
    buffers[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i" },
      key = "<F12>",
      callback = function()
        cmp.show()
        state.shown = vim.wait(100, function()
          return surface ~= nil
        end, 1)
      end,
    },
    {
      modes = { "i" },
      key = "<F11>",
      callback = function()
        if state.respond then
          state.respond()
        end
      end,
    },
  }
  nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
  return state
end

suite:test("preview plus typing participates in native repeat", function()
  local state = fixture()
  input("ial<F12><Tab>z<Esc>")
  suite.assert_true(state.shown, "owned menu")
  suite.assert_eq("alphaz", vim.api.nvim_get_current_line(), "preview committed by typing")
  input("j0.")
  suite.assert_eq("alphaz", vim.api.nvim_get_current_line(), "native repeat includes preview")
  suite.assert_eq(0, #reports, "no controller errors")
end)

suite:test("cancel and cycling back restore the original native insertion", function()
  fixture()
  input("ial<F12><Tab><C-e>z<Esc>j0.")
  suite.assert_eq("alz", vim.api.nvim_get_current_line(), "cancel removed preview from redo")
end)

suite:test("Escape commits a preview without completing its LSP side effects", function()
  local state = fixture()
  input("ial<F12><Tab><Esc>")
  suite.assert_eq("alpha", vim.api.nvim_get_current_line(), "Escape keeps the Blink preview")
  input("j0.")
  suite.assert_eq("alpha", vim.api.nvim_get_current_line(), "preview repeat after Escape")
  suite.assert_eq(0, #state.resolves, "no implicit resolve acceptance")
end)

suite:test("acceptance after preview records only one replacement", function()
  fixture()
  input("ial<F12><Tab><CR>z<Esc>j0.")
  suite.assert_eq("alphaz", vim.api.nvim_get_current_line(), "one accepted insertion in repeat")
end)

suite:test("late LSP results preserve both the selected candidate and canonical input", function()
  local state = fixture({
    labels = { "alpha", "alphabet" },
    lsp_items = { { label = "algebra", kind = 6 } },
    defer_completion = true,
  })
  state.respond = function()
    local before = #publications
    state.completions[1](nil, { isIncomplete = false, items = { { label = "algebra", kind = 6 } } })
    state.updated = vim.wait(100, function()
      return #publications > before
    end, 1)
    state.selected = surface.rows[surface.selected + 1][1]
    state.count = #surface.rows
    state.preview = vim.api.nvim_get_current_line()
  end
  input("ial<F12><Tab><F11><C-e><Esc>")
  suite.assert_true(state.updated, "incremental publication during preview")
  suite.assert_eq(3, state.count, "late LSP candidate enters the menu")
  suite.assert_eq("alphabet", state.selected, "explicit selection survives new source ranking")
  suite.assert_eq("alphabet", state.preview, "selection preview is reapplied")
  suite.assert_eq("al", vim.api.nvim_get_current_line(), "cancel restores real input, not the old preview")
  suite.assert_eq(1, #state.completions, "publication does not pull a second completion request")
end)

suite:test("function acceptance advances into existing parentheses through the full controller", function()
  fixture({ labels = {}, lines = { "()", "()" }, lsp_items = { { label = "alpha", kind = 3 } } })
  input("ial<F12><CR>z<Esc>")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "final cursor plan reaches existing arguments")
  input("j0.")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "cursor plan survives native repeat")
end)

suite:test("pending imports survive queued typing without replaying the primary text", function()
  local state = fixture({ labels = {}, lsp_items = { { label = "alpha", kind = 6, data = 1 } }, resolve = true })
  state.respond = function()
    state.resolves[1].callback(nil, {
      additionalTextEdits = {
        {
          newText = "import alpha\n",
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
        },
      },
    })
  end
  input("ial<F12><CR>x<F11><Esc>")
  suite.assert_eq("al", state.resolves[1].line, "resolve starts before insertion")
  suite.assert_true(
    vim.deep_equal({ "import alpha", "alphax", "" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "import and queued input both survive"
  )
  input("u")
  suite.assert_true(
    vim.deep_equal({ "al", "" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "ordinary late imports stay in the insertion undo block"
  )
end)

suite:test("bounded resolve keeps the server document stable without consuming queued input", function()
  local state = fixture({ labels = {}, lsp_items = { { label = "alpha", kind = 6, data = 1 } }, resolve = true })
  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i" },
      key = "<F10>",
      callback = function()
        cmp.show()
        local timer = vim.defer_fn(function()
          state.resolve_line = vim.api.nvim_get_current_line()
          state.resolves[1].callback(nil, {
            additionalTextEdits = {
              {
                newText = "import alpha\n",
                range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
              },
            },
          })
        end, 20)
        suite:defer(function()
          if not timer:is_closing() then
            timer:stop()
            timer:close()
          end
        end)
        state.accepted = require("era.m.cmp.insert").accept(state.bufnr)
        state.accept_line = vim.api.nvim_get_current_line()
      end,
    },
  }
  nvim.bindkeys(keymaps, { bufnr = state.bufnr, noremap = true, silent = true })
  input("ial<F10>x<Esc>")
  suite.assert_true(state.accepted, "acceptance succeeds inside the resolve budget")
  suite.assert_eq("al", state.resolve_line, "resolve sees the original document")
  suite.assert_eq("alpha", state.accept_line, "queued user input is not processed inside vim.wait")
  suite.assert_true(
    vim.deep_equal({ "import alpha", "alphax", "" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "queued input follows the accepted body exactly once"
  )
  suite.assert_eq(0, #reports, "no acceptance errors: " .. vim.inspect(reports))
end)

suite:test("UTF-16 late edits use the original document before rebasing multiline Unicode input", function()
  local state = fixture({
    labels = {},
    lines = { "", "你😀x" },
    encoding = "utf-16",
    resolve = true,
    lsp_items = { { label = "alpha", kind = 6, insertText = "alpha\nbeta" } },
  })
  state.respond = function()
    state.resolves[1].callback(nil, {
      additionalTextEdits = {
        { newText = "Y", range = { start = { line = 1, character = 3 }, ["end"] = { line = 1, character = 4 } } },
      },
    })
  end
  input("ial<F12><CR>你<CR>😀<F11><Esc>")
  suite.assert_true(
    vim.deep_equal({ "alpha", "beta你", "😀", "你😀Y" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "UTF-16 projection and UTF-8 journal preserve the original target"
  )
  suite.assert_eq(0, #reports, "no encoding or rebase errors")
end)

suite:test("InsertLeave retires pending acceptance before late side effects arrive", function()
  local state = fixture({ labels = {}, lsp_items = { { label = "alpha", kind = 6 } }, resolve = true })
  input("ial<F12><CR><Esc>")
  state.resolves[1].callback(nil, {
    additionalTextEdits = {
      {
        newText = "obsolete\n",
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
      },
    },
  })
  suite.assert_true(
    vim.deep_equal({ "alpha", "" }, vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)),
    "late callback cannot outlive insert acceptance"
  )
  suite.assert_true(#state.cancellations > 0, "last resolve subscription cancels the RPC")
end)

suite:test("resolved imports before the redo gate preserve multiline and cursor bookkeeping", function()
  for _, text in ipairs({ "alpha($0)", "alpha\nbeta" }) do
    local snippet = text:find("$0", 1, true) ~= nil
    local state = fixture({
      labels = {},
      lsp_items = {
        { label = "alpha", kind = 6, insertTextFormat = snippet and 2 or 1, insertText = text },
      },
      resolve = true,
    })
    ---@type stl.t.IKeymap[]
    local keymaps = {
      {
        modes = { "i" },
        key = "<F10>",
        callback = function()
          cmp.show()
          require("era.m.cmp.insert").accept(state.bufnr)
          state.resolves[1].callback(nil, {
            additionalTextEdits = {
              {
                newText = "import alpha\n",
                range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
              },
            },
          })
        end,
      },
    }
    nvim.bindkeys(keymaps, { bufnr = state.bufnr, noremap = true, silent = true })
    input("ial<F10>z<Esc>G0.")
    suite.assert_eq(
      snippet and "alpha(z)" or "betaz",
      vim.api.nvim_get_current_line(),
      "late import did not invalidate native redo"
    )
    suite.assert_eq(0, #reports, "recorder handles coordinate changes")
  end
end)

suite:test("path metadata survives the bridge and acceptance performs no documentation IO", function()
  local directory = vim.fn.tempname()
  vim.fn.mkdir(directory, "p")
  directory = assert(vim.uv.fs_realpath(directory))
  suite:defer(function()
    vim.fn.delete(directory, "rf")
  end)
  local filepath = directory .. "/alpha.lua"
  vim.fn.writefile({ "return 42" }, filepath)
  local state = fixture({ labels = { "alpha.lua" }, paths = { ["alpha.lua"] = filepath } })
  local path_documentation = require("era.m.cmp.path_documentation")
  local original = path_documentation.request
  local reads = 0
  suite:patch_table(path_documentation, "request", function(...)
    reads = reads + 1
    return original(...)
  end)
  state.respond = function()
    state.documented = vim.wait(250, function()
      return surface ~= nil and surface.documentation ~= nil and surface.documentation:find("return 42", 1, true) ~= nil
    end, 1)
  end
  input("ial<F12><F11><CR><Esc>")
  suite.assert_true(state.documented, "real file contents reach the active candidate")
  suite.assert_eq("alpha.lua", vim.api.nvim_get_current_line(), "path acceptance remains synchronous")
  suite.assert_eq(1, reads, "acceptance does not reread documentation or wait for file IO")
  suite.assert_eq(0, #reports, "path documentation errors: " .. vim.inspect(reports))
end)

---@param opts                          ?table
---@return table
local function semantic_fixture(opts)
  opts = opts or {}
  opts.labels = {}
  opts.lsp_items = opts.lsp_items or { { label = "alpha", kind = 6 } }
  local state = fixture(opts)
  state.semantic_requests = 0
  state.highlighter = {
    client_state = { [state.client.id] = { current_result = {} } },
    send_request = function()
      state.semantic_requests = state.semantic_requests + 1
    end,
    on_win = function() end,
  }
  suite:patch_table(semantic_tokens.__STHighlighter.active, state.bufnr, state.highlighter)
  suite:patch_table(vim.lsp.util.buf_versions, state.bufnr, vim.api.nvim_buf_get_changedtick(state.bufnr))
  state.emit = function(token_type, version, client_id)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local token = {
      line = cursor[1] - 1,
      end_line = cursor[1] - 1,
      start_col = 0,
      end_col = cursor[2],
      type = token_type or "function",
      modifiers = {},
    }
    local changedtick = vim.api.nvim_buf_get_changedtick(state.bufnr)
    vim.lsp.util.buf_versions[state.bufnr] = changedtick
    state.highlighter.client_state[state.client.id].current_result = {
      version = version or changedtick,
      highlights = { token },
    }
    vim.api.nvim_exec_autocmds("LspTokenUpdate", {
      buffer = state.bufnr,
      modeline = false,
      data = { client_id = client_id or state.client.id, token = token },
    })
    vim.wait(20, function()
      return vim.api.nvim_get_current_line():find("(", 1, true) ~= nil
    end, 1)
  end
  state.respond = function()
    state.emit()
  end
  return state
end

suite:test("semantic function brackets join native undo and repeat without a second primary insertion", function()
  local state = semantic_fixture()
  input("ial<F12><CR><F11>z<Esc>")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "semantic brackets put following input inside")
  suite.assert_eq(1, state.semantic_requests, "one shared highlighter request")
  input("u")
  suite.assert_eq("al", vim.api.nvim_get_current_line(), "primary and semantic suffix undo together")
  input("<C-r>j0.")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "native repeat includes the semantic suffix once")
  suite.assert_eq(0, #reports, "semantic acceptance errors: " .. vim.inspect(reports))
end)

suite:test("semantic fallback handles Unicode methods and kind-blocked TSX functions", function()
  local unicode = semantic_fixture({ lsp_items = { { label = "άλφα", kind = 6 } } })
  unicode.respond = function()
    unicode.emit("method")
  end
  input("iάλ<F12><CR><F11>z<Esc>")
  suite.assert_eq("άλφα(z)", vim.api.nvim_get_current_line(), "semantic token columns are UTF-8 bytes")
  local jsx = semantic_fixture({ filetype = "typescriptreact", lsp_items = { { label = "alpha", kind = 3 } } })
  input("ial<F12><CR><F11>z<Esc>")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "semantic evidence replaces the blocked kind heuristic")
  suite.assert_eq(1, jsx.semantic_requests, "TSX uses semantic fallback")
end)

suite:test("settling resolve does not cancel the independent semantic continuation", function()
  local state = semantic_fixture({ resolve = true })
  state.respond = function()
    state.resolves[1].callback(nil, { detail = "resolved documentation" })
    state.emit()
  end
  input("ial<F12><CR><F11>z<Esc>")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "resolve completion preserves semantic ownership")
  suite.assert_eq(0, #reports, "independent continuation errors: " .. vim.inspect(reports))
end)

suite:test("freshness, token kind, and client ownership gate semantic bracket insertion", function()
  for _, invalid in ipairs({ "version", "kind", "client" }) do
    local state = semantic_fixture()
    state.respond = function()
      state.emit(
        invalid == "kind" and "variable" or "function",
        invalid == "version" and 0 or nil,
        invalid == "client" and state.client.id + 1 or nil
      )
      state.before = vim.api.nvim_get_current_line()
      state.emit()
    end
    input("ial<F12><CR><F11><Esc>")
    suite.assert_eq("alpha", state.before, invalid .. " cannot append brackets")
    suite.assert_eq("alpha()", vim.api.nvim_get_current_line(), "fresh owning function token still succeeds")
  end
end)

suite:test("typing, cursor movement, cancellation, and timeout discard pending semantic edits", function()
  for _, change in ipairs({ "typing", "cursor", "filetype", "cancel", "timeout" }) do
    local state = semantic_fixture()
    state.respond = function()
      if change == "cursor" then
        vim.api.nvim_win_set_cursor(0, { 1, 1 })
      elseif change == "filetype" then
        vim.api.nvim_set_option_value("filetype", "java", { buf = state.bufnr })
      elseif change == "cancel" then
        require("era.m.cmp.accept").cancel(state.bufnr)
      elseif change == "timeout" then
        vim.wait(430, function()
          return false
        end, 5)
      end
      state.emit()
    end
    input("ial<F12><CR>" .. (change == "typing" and "x" or "") .. "<F11><Esc>")
    suite.assert_eq(
      change == "typing" and "alphax" or "alpha",
      vim.api.nvim_get_current_line(),
      change .. " prevents late mutation"
    )
    suite.assert_eq(
      0,
      #vim.api.nvim_get_autocmds({ event = "LspTokenUpdate", buffer = state.bufnr }),
      "request listener retired"
    )
  end
end)

suite:test("semantic request failure does not reject accepted text or leave a listener", function()
  local state = semantic_fixture()
  state.highlighter.send_request = function()
    error("transport unavailable")
  end
  input("ial<F12><CR>z<Esc>")
  suite.assert_eq("alphaz", vim.api.nvim_get_current_line(), "primary and following input survive optional failure")
  suite.assert_eq(1, #reports, "optional failure reported once")
  suite.assert_eq(
    0,
    #vim.api.nvim_get_autocmds({ event = "LspTokenUpdate", buffer = state.bufnr }),
    "failed request listener retired"
  )
end)

suite:test("semantic filetype policy skips blocked buffers without requesting tokens", function()
  for _, filetype in ipairs({ "java", "rust", "cpp" }) do
    local state = semantic_fixture({ filetype = filetype })
    input("ial<F12><CR><F11><Esc>")
    suite.assert_eq("alpha", vim.api.nvim_get_current_line(), filetype .. " remains unmodified")
    suite.assert_eq(0, state.semantic_requests, "blocked filetype does not start semantic work")
  end
end)

suite:test("fresh semantic cache appends only the redo delta before initial bookkeeping finishes", function()
  local state =
    semantic_fixture({ lsp_items = { { label = "alpha", kind = 6, command = { command = "cache-ready" } } } })
  suite:patch_table(bridge, "execute_command", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local version = vim.api.nvim_buf_get_changedtick(state.bufnr)
    vim.lsp.util.buf_versions[state.bufnr] = version
    state.highlighter.client_state[state.client.id].current_result = {
      version = version,
      highlights = {
        {
          line = cursor[1] - 1,
          end_line = cursor[1] - 1,
          start_col = 0,
          end_col = cursor[2],
          type = "function",
          modifiers = {},
        },
      },
    }
  end)
  input("ial<F12><CR>z<Esc>j0.")
  suite.assert_eq("alpha(z)", vim.api.nvim_get_current_line(), "cached semantic suffix is repeated once")
  suite.assert_eq(0, state.semantic_requests, "fresh cache requires no token request")
  suite.assert_eq(0, #reports, "cached semantic errors: " .. vim.inspect(reports))
end)

suite:run()
