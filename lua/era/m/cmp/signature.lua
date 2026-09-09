---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.signature" ---@type string

local M = {}
local METHOD = "textDocument/signatureHelp"
local INVOKED = 1
local TRIGGER_CHARACTER = 2
local WINBLEND = 50
local namespace = vim.api.nvim_create_namespace(__module_name__)
local states = {} ---@type table<integer, era.m.cmp.signature.IState>
local pending = {} ---@type table<integer, era.m.cmp.signature.IPending|false>
local dressed = false

---@class era.m.cmp.signature.IRequest
---@field public client                 vim.lsp.Client
---@field public request_id             integer|nil

---@class era.m.cmp.signature.IState
---@field public generation             integer
---@field public requests               table<integer, era.m.cmp.signature.IRequest>
---@field public active                 table<integer, lsp.SignatureHelp>
---@field public popup_client_id        integer|nil
---@field public popup_bufnr            integer|nil
---@field public popup_winnr            integer|nil

---@class era.m.cmp.signature.IPending
---@field public generation             integer
---@field public char                   string
---@field public active                 table<integer, lsp.SignatureHelp>

---@param bufnr                         integer
---@return era.m.cmp.signature.IState
local function state_for(bufnr)
  local state = states[bufnr]
  if state == nil then
    state = { generation = 0, requests = {}, active = {} }
    states[bufnr] = state
  end
  return state
end

---@param state                         era.m.cmp.signature.IState
---@return boolean
local function popup_valid(state)
  return state.popup_winnr ~= nil and vim.api.nvim_win_is_valid(state.popup_winnr)
end

---@param state                         era.m.cmp.signature.IState
local function close_popup(state)
  if popup_valid(state) then
    pcall(vim.api.nvim_win_close, state.popup_winnr, true)
  end
  state.popup_client_id = nil
  state.popup_bufnr = nil
  state.popup_winnr = nil
end

---@param state                         era.m.cmp.signature.IState
local function cancel_requests(state)
  for _, request in pairs(state.requests) do
    if request.request_id ~= nil then
      pcall(request.client.cancel_request, request.client, request.request_id)
    end
  end
  state.requests = {}
end

---@param bufnr                         integer
---@param clear_active                  boolean
---@return integer
local function invalidate(bufnr, clear_active)
  local state = state_for(bufnr)
  state.generation = state.generation + 1
  cancel_requests(state)
  close_popup(state)
  if clear_active then
    state.active = {}
  end
  return state.generation
end

---@param bufnr                         integer
---@param char                          string|nil
---@return vim.lsp.Client[]
local function clients_for(bufnr, char)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = METHOD }) ---@type vim.lsp.Client[]
  if char == nil then
    return clients
  end
  return vim.tbl_filter(function(client)
    local provider = client.server_capabilities.signatureHelpProvider or {}
    return vim.list_contains(provider.triggerCharacters or {}, char)
      or vim.list_contains(provider.retriggerCharacters or {}, char)
  end, clients)
end

---@param bufnr                         integer
---@param client                       vim.lsp.Client
---@param result                       lsp.SignatureHelp
---@return integer|nil
---@return integer|nil
local function render(bufnr, client, result)
  local projected = vim.deepcopy(result) ---@type lsp.SignatureHelp
  for _, signature in ipairs(projected.signatures) do
    signature.documentation = nil
  end
  local provider = client.server_capabilities.signatureHelpProvider or {}
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  local lines, highlight =
    vim.lsp.util.convert_signature_help_to_markdown_lines(projected, filetype, provider.triggerCharacters)
  if lines == nil or #lines == 0 then
    return nil, nil
  end

  local popup_bufnr, popup_winnr = vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    close_events = { "CursorMoved", "CursorMovedI", "InsertLeave", "BufHidden" },
    focus = false,
    focusable = false,
  })
  vim.api.nvim_set_option_value("winblend", WINBLEND, { win = popup_winnr, scope = "local" })
  if highlight ~= nil then
    vim.api.nvim_buf_clear_namespace(popup_bufnr, namespace, 0, -1)
    vim.hl.range(
      popup_bufnr,
      namespace,
      "LspSignatureActiveParameter",
      { highlight[1], highlight[2] },
      { highlight[3], highlight[4] }
    )
  end
  return popup_bufnr, popup_winnr
end

---@param bufnr                         integer
---@param generation                   integer
---@param clients                      vim.lsp.Client[]
---@param trigger_kind                 1|2
---@param char                          string|nil
---@param active                       table<integer, lsp.SignatureHelp>
local function request(bufnr, generation, clients, trigger_kind, char, active)
  local state = state_for(bufnr)
  if state.generation ~= generation then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer

  for _, client in ipairs(clients) do
    local client_id = client.id ---@type integer
    local active_signature = active[client_id] ---@type lsp.SignatureHelp|nil
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding) ---@type lsp.SignatureHelpParams
    params.context = {
      triggerKind = trigger_kind,
      triggerCharacter = trigger_kind == TRIGGER_CHARACTER and char or nil,
      isRetrigger = active_signature ~= nil,
      activeSignatureHelp = active_signature,
    }

    local slot = { client = client, request_id = nil } ---@type era.m.cmp.signature.IRequest
    local settled = false
    state.requests[client_id] = slot
    local success, request_id = client:request(METHOD, params, function(err, result, ctx)
      settled = true
      local current = states[bufnr]
      if current == nil or current.generation ~= generation or current.requests[client_id] ~= slot then
        return
      end
      current.requests[client_id] = nil
      if
        err ~= nil
        or result == nil
        or result.signatures == nil
        or result.signatures[1] == nil
        or vim.api.nvim_get_current_buf() ~= bufnr
        or not vim.api.nvim_get_mode().mode:match("^[iR]")
        or not vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor)
        or vim.api.nvim_buf_get_changedtick(bufnr) ~= changedtick
      then
        current.active[client_id] = nil
        if current.popup_client_id == client_id then
          close_popup(current)
        end
        return
      end

      local popup_bufnr, popup_winnr = render(bufnr, client, result)
      if popup_winnr ~= nil and vim.api.nvim_win_is_valid(popup_winnr) then
        if
          current.popup_winnr ~= nil
          and current.popup_winnr ~= popup_winnr
          and vim.api.nvim_win_is_valid(current.popup_winnr)
        then
          pcall(vim.api.nvim_win_close, current.popup_winnr, true)
        end
        current.active[client_id] = result
        current.popup_client_id = client_id
        current.popup_bufnr = popup_bufnr
        current.popup_winnr = popup_winnr
      end
    end, bufnr)
    slot.request_id = request_id
    if not success or settled or states[bufnr] ~= state or state.generation ~= generation then
      if state.requests[client_id] == slot then
        state.requests[client_id] = nil
      end
      if success and not settled and request_id ~= nil then
        pcall(client.cancel_request, client, request_id)
      end
    end
  end
end

---@param bufnr                         integer
---@param value                         era.m.cmp.signature.IPending
local function schedule(bufnr, value)
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  local line = vim.api.nvim_get_current_line() ---@type string
  vim.schedule(function()
    if
      states[bufnr] == nil
      or states[bufnr].generation ~= value.generation
      or vim.api.nvim_get_current_buf() ~= bufnr
      or not vim.api.nvim_get_mode().mode:match("^[iR]")
      or not vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor)
      or vim.api.nvim_get_current_line() ~= line
    then
      return
    end
    request(bufnr, value.generation, clients_for(bufnr, value.char), TRIGGER_CHARACTER, value.char, value.active)
  end)
end

---@param bufnr                         integer
---@return string
local function character_before_cursor(bufnr)
  if vim.api.nvim_get_current_buf() ~= bufnr then
    return ""
  end
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  local line = vim.api.nvim_get_current_line() ---@type string
  local prefix = line:sub(1, cursor[2]) ---@type string
  local count = vim.fn.strchars(prefix) ---@type integer
  return count > 0 and vim.fn.strcharpart(prefix, count - 1, 1) or ""
end

---@param bufnr?                        integer
---@return boolean
function M.visible(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = states[bufnr]
  return state ~= nil and popup_valid(state)
end

---@param bufnr?                        integer
---@return boolean
function M.show(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.api.nvim_get_current_buf() ~= bufnr or not vim.api.nvim_get_mode().mode:match("^[iR]") then
    return false
  end
  local clients = clients_for(bufnr, nil)
  if #clients == 0 then
    return false
  end
  local state = state_for(bufnr)
  local active = popup_valid(state) and state.active or {}
  local generation = invalidate(bufnr, false)
  request(bufnr, generation, clients, INVOKED, nil, active)
  return true
end

---@param bufnr?                        integer
---@return boolean
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if M.visible(bufnr) then
    M.hide(bufnr)
    return true
  end
  return M.show(bufnr)
end

---@param bufnr?                        integer
function M.hide(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  pending[bufnr] = nil
  if states[bufnr] ~= nil then
    invalidate(bufnr, true)
  end
end

function M.dressing()
  if dressed then
    return
  end
  dressed = true

  local augroup = stl.nvim.fn.augroup(__module_name__ .. ".dressing")
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = augroup,
    callback = function(args)
      if vim.fn.win_gettype() == "command" then
        return
      end
      local char = vim.v.char ---@type string
      local clients = clients_for(args.buf, char)
      if #clients == 0 then
        if pending[args.buf] ~= nil then
          return
        end
        pending[args.buf] = false
        if states[args.buf] ~= nil then
          invalidate(args.buf, true)
        end
        return
      end
      local state = state_for(args.buf)
      local active = popup_valid(state) and state.active or {}
      pending[args.buf] = {
        char = char,
        generation = invalidate(args.buf, false),
        active = active,
      }
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    group = augroup,
    callback = function(args)
      local value = pending[args.buf]
      pending[args.buf] = nil
      if value == false then
        return
      end
      if value == nil and args.event == "TextChangedI" then
        local char = character_before_cursor(args.buf)
        if #clients_for(args.buf, char) == 0 then
          return
        end
        local state = state_for(args.buf)
        local active = popup_valid(state) and state.active or {}
        value = {
          char = char,
          generation = invalidate(args.buf, false),
          active = active,
        }
      end
      if value ~= nil then
        schedule(args.buf, value)
      end
    end,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = augroup,
    callback = function(args)
      local char = character_before_cursor(args.buf)
      if #clients_for(args.buf, char) == 0 then
        return
      end
      local state = state_for(args.buf)
      local active = popup_valid(state) and state.active or {}
      local value = {
        char = char,
        generation = invalidate(args.buf, false),
        active = active,
      } ---@type era.m.cmp.signature.IPending
      schedule(args.buf, value)
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function(args)
      M.hide(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = augroup,
    callback = function(args)
      pending[args.buf] = nil
      local state = states[args.buf]
      if state ~= nil then
        cancel_requests(state)
        close_popup(state)
        states[args.buf] = nil
      end
    end,
  })
end

return M
