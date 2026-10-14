---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.keystroke.cmp.signature" ---@type string

local harness = require("__test__.support.harness")
local runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
runtime.setup()
local t = harness.new("era.keystroke.cmp.signature")
local Context = require("era.keystroke.cmp.context")
local Signature = require("era.keystroke.cmp.signature")

---@return table
local function fixture()
  local previous = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(bufnr)
  t:defer(function()
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  local state = {
    signature = Signature.new(),
    clients = {},
    requests = {},
    response = {
      activeParameter = 0,
      signatures = { { label = "foo(foo)", parameters = { { label = "foo" } }, documentation = "original docs" } },
    },
  }
  t:defer(function()
    state.signature:destroy()
  end)
  t:patch_table(Context, "capture", function()
    return state.context
  end)
  t:patch_table(vim.lsp, "get_clients", function()
    return state.clients
  end)

  ---@param provider                    lsp.SignatureHelpOptions
  ---@return nil
  function state:add_client(provider)
    local client = {
      id = #self.clients + 1,
      offset_encoding = "utf-16",
      server_capabilities = { signatureHelpProvider = provider },
      request = function(client, method, params, callback)
        t.assert_eq("textDocument/signatureHelp", method)
        self.requests[#self.requests + 1] = { client = client.id, params = params, callback = callback }
        if self.reject then
          return false
        end
        if not self.delay then
          callback(nil, self.response)
        end
        return true, #self.requests
      end,
      cancel_request = function() end,
    }
    self.clients[#self.clients + 1] = client
  end

  ---@param line                        string
  ---@param force                       ?boolean
  ---@return boolean
  function state:update(line, force)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { line })
    self.context = runtime.context(line)
    return self.signature:update(self.context, force)
  end

  ---@param count                       integer
  ---@return nil
  function state:wait(count)
    t.wait_until(function()
      return #self.requests == count
    end, 1000, "signature requests sent")
  end
  return state
end

t:test("manual signature requests omit the character and share the pre-request active state", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" } })
  state:add_client({ triggerCharacters = { "[" } })
  t.assert_true(state:update("foo(", true))
  state:wait(2)
  for _, request in ipairs(state.requests) do
    t.assert_eq(1, request.params.context.triggerKind, "Invoked")
    t.assert_nil(request.params.context.triggerCharacter)
    t.assert_eq(false, request.params.context.isRetrigger, "synchronous responses do not change later requests")
    t.assert_nil(request.params.context.activeSignatureHelp)
  end
end)

t:test("automatic signature triggers are per client and retrigger characters cannot open a signature", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" }, retriggerCharacters = { "," } })
  state:add_client({ triggerCharacters = { "[" }, retriggerCharacters = { ";" } })
  t.assert_eq(false, state:update("foo,"), "retrigger character alone does not open the window")
  t.assert_eq(false, state:update("foo;"), "other client's retrigger character also needs active help")
  t.assert_true(state:update("foo("))
  state:wait(1)
  local request = state.requests[1]
  t.assert_eq(1, request.client, "only the client advertising this trigger is queried")
  t.assert_eq(2, request.params.context.triggerKind)
  t.assert_eq("(", request.params.context.triggerCharacter)
  t.assert_eq(false, request.params.context.isRetrigger)
  local marks = vim.api.nvim_buf_get_extmarks(state.signature.bufnr, -1, 0, -1, { details = true })
  t.assert_eq(1, #marks, "response carries its client's trigger characters to rendering")
  t.assert_eq(4, marks[1][3], "parameter starts after the opening parenthesis")
  t.assert_eq(7, marks[1][4].end_col)
end)

t:test("active signatures use ContentChange for ordinary input and per-client retrigger characters", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" }, retriggerCharacters = { "," } })
  state:add_client({ triggerCharacters = { "[" }, retriggerCharacters = { ";" } })
  state:update("foo(", true)
  state:wait(2)
  local original = vim.deepcopy(state.response)
  state:update("foo(a")
  state:wait(4)
  for index = 3, 4 do
    local context = state.requests[index].params.context
    t.assert_eq(3, context.triggerKind, "ContentChange")
    t.assert_nil(context.triggerCharacter)
    t.assert_eq(true, context.isRetrigger)
    t.assert_true(vim.deep_equal(original, context.activeSignatureHelp), "complete response is preserved")
  end
  state:update("foo(a,")
  state:wait(6)
  t.assert_eq(2, state.requests[5].params.context.triggerKind)
  t.assert_eq(",", state.requests[5].params.context.triggerCharacter)
  t.assert_eq(3, state.requests[6].params.context.triggerKind, "unadvertised character is a content change")
  t.assert_nil(state.requests[6].params.context.triggerCharacter)
  state:update("foo(a,", true)
  state:wait(8)
  for index = 7, 8 do
    t.assert_eq(1, state.requests[index].params.context.triggerKind, "manual retrigger remains Invoked")
    t.assert_nil(state.requests[index].params.context.triggerCharacter)
  end
  t.assert_true(vim.deep_equal(original, state.response), "rendering never rewrites protocol fields")
end)

t:test("cancelled signature responses cannot reopen the window", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" } })
  state.delay = true
  state:update("foo(")
  state:wait(1)
  state.signature:hide()
  state.requests[1].callback(nil, state.response)
  t.assert_nil(state.signature.winnr)
end)

t:test("failed request submission clears stale signature help", function()
  local state = fixture()
  state:add_client({ triggerCharacters = { "(" } })
  state:update("foo(")
  state:wait(1)
  t.assert_true(vim.api.nvim_win_is_valid(assert(state.signature.winnr)))
  state.reject = true
  state:update("foo(a")
  state:wait(2)
  t.assert_nil(state.signature.winnr)
  t.assert_eq(false, state:update("foo(ab"), "failed refresh releases the active state")
end)

t:run()
