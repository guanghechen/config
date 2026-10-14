---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.cmp.behavior" ---@type string

local M = {}

---@param options                       table
---@return nil
function M.setup(options)
  M.options = options
  require("__test__.fixtures.era.keystroke.cmp.runtime").setup(options.engine == "era" and options.baseline or nil)
  M.notices, M.requests, M.commands = {}, {}, {}
  M.inline_calls = 0
  M.fallback_calls = {}
  vim.notify = function(message, level)
    M.notices[#M.notices + 1] = { message = message, level = level }
  end
  vim.api.nvim_set_option_value("filetype", options.filetype or "lua", { buf = 0 })
  vim.api.nvim_set_option_value("swapfile", false, { buf = 0 })
  vim.api.nvim_set_option_value("shortmess", "filnxtToOFWIcC", {})
  vim.api.nvim_set_option_value("expandtab", false, { buf = 0 })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, options.lines or { "" })
  vim.api.nvim_win_set_cursor(0, options.cursor or { 1, 0 })
  M.bufnr, M.winnr = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  vim.lsp.inline_completion.get = function()
    M.inline_calls = M.inline_calls + 1
    return options.inline == true
  end
  for _, mapping in ipairs(options.mappings or {}) do
    vim.keymap.set(mapping.mode, mapping.key, function()
      M.fallback_calls[#M.fallback_calls + 1] = mapping.key
      return mapping.result
    end, { expr = true })
  end
  vim.api.nvim_create_user_command("CmpFixture", function(event)
    M.commands[#M.commands + 1] = "CmpFixture " .. event.args
  end, {
    nargs = "*",
    complete = function()
      return options.cmd_items or { "alpha", "alpine" }
    end,
  })
  M.items = options.items
    or {
      { label = "alpha", filterText = "al", sortText = "1", kind = 6 },
      { label = "alpine", filterText = "al", sortText = "2", kind = 6 },
    }
  local stopped = false
  local client = {
    id = 9001,
    name = "behavior-fixture",
    offset_encoding = "utf-16",
    requests = {},
    rpc = {
      is_closing = function()
        return stopped
      end,
    },
    stop = function()
      stopped = true
    end,
    server_capabilities = {
      completionProvider = { resolveProvider = true, triggerCharacters = options.triggers or { "." } },
      signatureHelpProvider = { triggerCharacters = { "(" }, retriggerCharacters = { "," } },
    },
    is_stopped = function()
      return stopped
    end,
    supports_method = function(_, method)
      return method == "textDocument/completion"
        or method == "completionItem/resolve"
        or (options.signature and method == "textDocument/signatureHelp")
    end,
    cancel_request = function() end,
    exec_cmd = function(_, command)
      M.commands[#M.commands + 1] = command.command
    end,
    request = function(self, method, params, callback)
      M.requests[#M.requests + 1] = { method = method, params = params }
      local id = #M.requests
      self.requests[id] = { type = "pending" }
      local result
      if method == "textDocument/completion" then
        result = { items = vim.deepcopy(M.items), isIncomplete = options.incomplete == true }
      elseif method == "completionItem/resolve" then
        result = vim.deepcopy(params)
        if options.documentation then
          result.documentation = {
            kind = "markdown",
            value = result.label
              .. "\n\n"
              .. (
                type(options.documentation) == "string" and options.documentation
                or "A stable completion description."
              ),
          }
        end
      elseif method == "textDocument/signatureHelp" then
        result = {
          signatures = { { label = "demo(first, second)", parameters = { { label = "first" }, { label = "second" } } } },
          activeSignature = 0,
          activeParameter = 0,
        }
      else
        error("unexpected request: " .. method)
      end
      vim.defer_fn(function()
        self.requests[id] = nil
        callback(nil, result, { client_id = self.id, bufnr = M.bufnr, method = method, params = params })
      end, options.delay_ms or 0)
      return true, id
    end,
  }
  vim.lsp.get_clients = function(filter)
    if filter == nil or filter.method == nil or client:supports_method(filter.method) then
      return { client }
    end
    return {}
  end
  vim.lsp.get_client_by_id = function(id)
    return id == client.id and client or nil
  end
  if options.engine == "era" then
    local session = require("era.keystroke.cmp.session")
    local new = session.new
    session.new = function(props)
      M.session = new(props)
      return M.session
    end
    local sources_for = require("era.keystroke.cmp.policy").sources_for
    require("era.keystroke.cmp.policy").sources_for = function(context, manual, previous)
      local sources = sources_for(context, manual, previous)
      return vim.list_contains(sources, "lsp") and (options.buffer and { "lsp", "buffer" } or { "lsp" }) or {}
    end
    M.cmp = require("era.keystroke.cmp")
    M.cmp.setup()
  else
    vim.opt.runtimepath:append(options.blink)
    local config = require("__test__.fixtures.era.keystroke.cmp.blink_options").opts()
    -- Keep interaction settings intact. Isolate only payloads and persistent frecency state.
    config.sources.default = options.buffer and { "lsp", "buffer" } or { "lsp" }
    config.sources.per_filetype = {}
    config.fuzzy.implementation = "rust"
    config.fuzzy.prebuilt_binaries = { download = false }
    config.fuzzy.frecency.path = options.output .. "/frecency-" .. vim.uv.os_getpid() .. ".dat"
    M.cmp = require("blink.cmp")
    M.cmp.setup(config)
  end
end

---@return table
function M.snapshot()
  local mode = vim.api.nvim_get_mode().mode
  local visible = M.cmp.is_menu_visible()
  local items, selected, documentation, signature, doc_winnr, ghost, menu_bufnr
  if M.options.engine == "era" then
    local session = M.session
    if mode == "c" then
      local info = vim.fn.cmdcomplete_info()
      items = {}
      for _, label in ipairs(info.matches or {}) do
        items[#items + 1] = { label = label }
      end
      selected = info.selected ~= nil and info.selected >= 0 and items[info.selected + 1] or nil
    else
      items = session and session.items or {}
      selected = session and session:current_item()
    end
    documentation = session ~= nil and session.documentation:is_visible()
    doc_winnr = documentation and session.documentation.winnr or nil
    signature = session ~= nil and session.signature.winnr ~= nil
    ghost = false
  else
    local list = package.loaded["blink.cmp.completion.list"]
    items = list and list.items or {}
    selected = list and list.get_selected_item()
    documentation = M.cmp.is_documentation_visible()
    local docs = package.loaded["blink.cmp.completion.windows.documentation"]
    doc_winnr = docs and docs.win:get_win()
    signature = M.cmp.is_signature_visible()
    local preview = package.loaded["blink.cmp.completion.windows.ghost_text"]
    ghost = preview ~= nil and preview.is_open()
    if M.options.menu_text and visible then
      menu_bufnr = require("blink.cmp.completion.windows.menu").win:get_buf()
    end
  end
  local labels = {}
  if visible then
    for _, item in ipairs(items) do
      labels[#labels + 1] = (item.raw or item).label
    end
  end
  local state = {
    mode = mode:sub(1, 1) == "i" and "i" or mode,
    lines = vim.api.nvim_buf_get_lines(M.bufnr, 0, -1, false),
    cursor = vim.api.nvim_win_get_cursor(M.winnr),
    cmdline = mode == "c" and vim.fn.getcmdline() or false,
    cmdpos = mode == "c" and vim.fn.getcmdpos() or false,
    menu = visible,
    native_menu = vim.fn.pumvisible() == 1,
    labels = labels,
    selected = visible and selected ~= nil and (selected.raw or selected).label or false,
    ghost = ghost,
    documentation = documentation,
    signature = signature,
    snippet = vim.snippet.active(),
    inline_calls = M.inline_calls,
    fallback_calls = M.fallback_calls,
    commands = M.commands,
    errmsg = vim.v.errmsg,
    notices = M.notices,
  }
  if M.options.documentation then
    state.documentation_lines = doc_winnr
        and vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(doc_winnr), 0, -1, false)
      or false
    state.documentation_topline = doc_winnr and vim.fn.line("w0", doc_winnr) or false
  end
  if M.options.menu_text then
    state.menu_text = {}
    if M.options.engine == "era" then
      for _, item in ipairs(visible and vim.fn.complete_info({ "items" }).items or {}) do
        state.menu_text[#state.menu_text + 1] = item.abbr
      end
    else
      for _, line in ipairs(visible and vim.api.nvim_buf_get_lines(assert(menu_bufnr), 0, -1, false) or {}) do
        -- Compare labels without the custom renderer's kind/source columns.
        state.menu_text[#state.menu_text + 1] = vim.trim(line):gsub("^%S+%s+", ""):gsub("%s+%[[^%]]+%]$", "")
      end
    end
  end
  return state
end

return M
