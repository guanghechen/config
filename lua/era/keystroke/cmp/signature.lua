---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.signature" ---@type string

local namespace = vim.api.nvim_create_namespace(__module_name__)
local Edit = require("era.keystroke.cmp.edit")

---@class era.keystroke.cmp.Signature
---@field public bufnr                  ?integer
---@field public winnr                  ?integer
---@field private _requests             { client: vim.lsp.Client, id: integer }[]
---@field private _generation           integer
---@field private _active               ?lsp.SignatureHelp
---@field private _width                integer
---@field private _label                ?string
local M = {}
M.__index = M

---@return era.keystroke.cmp.Signature
function M.new()
  return setmetatable({
    _requests = {},
    _generation = 0,
    _width = 1,
  }, M)
end

---@return nil
function M:cancel()
  self._generation = self._generation + 1
  for _, request in ipairs(self._requests) do
    request.client:cancel_request(request.id)
  end
  self._requests = {}
end

---@private
---@return nil
function M:_close()
  local winnr = self.winnr
  self.winnr = nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
end

---@return nil
function M:destroy()
  self:hide()
  if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
  self.bufnr = nil
  self._label = nil
end

---@return nil
function M:hide()
  self:cancel()
  self._active = nil
  self:_close()
end

---@param context                       era.keystroke.cmp.IContext
---@param result                        lsp.SignatureHelp
---@param triggers                      ?string[]
---@return nil
function M:render(context, result, triggers)
  local index = type(result.activeSignature) == "number" and result.activeSignature or 0
  local signature = type(result.signatures) == "table" and (result.signatures[index + 1] or result.signatures[1]) or nil
  if type(signature) ~= "table" or type(signature.label) ~= "string" then
    self:_close()
    self._active = nil
    return
  end
  self._active = result
  local lines = vim.split(signature.label, "\n", { plain = true })
  -- Explicit null means no active parameter, while a missing field inherits the response value.
  local active = signature.activeParameter or result.activeParameter
  local parameters = type(signature.parameters) == "table" and signature.parameters or {}
  local range
  if type(active) == "number" and parameters[active + 1] ~= nil then
    local offset ---@type integer|nil
    for _, trigger in ipairs(triggers or {}) do
      local found = signature.label:find(trigger, 1, true)
      if found ~= nil and (offset == nil or found < offset) then
        offset = found
      end
    end
    offset = offset or 1
    for parameter_index, parameter in ipairs(parameters) do
      local label = parameter.label
      local first, last
      if type(label) == "table" then
        first = vim.str_byteindex(signature.label, "utf-16", label[1], false) + 1
        last = vim.str_byteindex(signature.label, "utf-16", label[2], false)
      else
        first, last = signature.label:find(label, offset, true)
      end
      if first == nil then
        break
      end
      if parameter_index == active + 1 then
        local start = vim.split(signature.label:sub(1, first - 1), "\n", { plain = true })
        local finish = vim.split(signature.label:sub(1, last), "\n", { plain = true })
        range = { { #start - 1, #start[#start] }, { #finish - 1, #finish[#finish] } }
        break
      end
      offset = last + 1
    end
  end
  local bufnr = self.bufnr
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    self.bufnr = bufnr
    vim.api.nvim_set_option_value("filetype", "cmp-signature", { buf = bufnr })
    self._label = nil
  end
  if self._label ~= signature.label then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    self._label = signature.label
    local width = 1
    for _, line in ipairs(lines) do
      width = math.max(width, vim.fn.strdisplaywidth(line))
    end
    self._width = math.min(width, 88)
  end
  if self.winnr == nil or not vim.api.nvim_win_is_valid(self.winnr) then
    self.winnr = vim.api.nvim_open_win(bufnr, false, {
      relative = "editor",
      row = 0,
      col = 0,
      width = math.max(1, math.min(self._width, vim.o.columns - 4)),
      height = 1,
      style = "minimal",
      border = "rounded",
      focusable = false,
      zindex = dot.var.zindex.POPUPMENU + 3,
      noautocmd = true,
    })
    vim.w[self.winnr][dot.var.N_WINLINE_DISABLED] = true
    vim.w[self.winnr].wintype = stl.e.WinTypeEnum.POPUPMENU
    for name, value in pairs({
      wrap = true,
      signcolumn = "no",
      winblend = 0,
      scrolloff = 0,
      winhighlight = "Normal:CmpSignatureHelp,FloatBorder:CmpSignatureHelpBorder",
    }) do
      vim.api.nvim_set_option_value(name, value, { win = self.winnr, scope = "local" })
    end
  end
  self:reposition(context)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  if range ~= nil then
    vim.hl.range(bufnr, namespace, "CmpSignatureHelpActiveParameter", range[1], range[2])
  end
end

---@param context                       era.keystroke.cmp.IContext
---@return nil
function M:reposition(context)
  local winnr = self.winnr
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end
  local width = math.max(1, math.min(self._width, vim.o.columns - 4))
  vim.api.nvim_win_set_width(winnr, width)
  local maximum = math.max(1, math.min(8, vim.o.lines - 4))
  local height = math.max(1, math.min(maximum, vim.api.nvim_win_text_height(winnr, { max_height = maximum }).all))
  local position = vim.fn.screenpos(context.winnr, context.row + 1, context.col + 1)
  local row, col = position.row, position.col - 1
  row = row > height + 1 and row - height - 2 or row
  vim.api.nvim_win_set_config(winnr, {
    relative = "editor",
    row = math.max(0, math.min(row, vim.o.lines - height - 2)),
    col = math.max(0, math.min(col, vim.o.columns - width - 2)),
    height = height,
    noautocmd = true,
  })
end

---@param context                       era.keystroke.cmp.IContext
---@param force                         ?boolean
---@return boolean
function M:update(context, force)
  local clients = vim.lsp.get_clients({ bufnr = context.bufnr, method = "textDocument/signatureHelp" })
  if #clients == 0 then
    self:hide()
    return false
  end
  local character = context.line:sub(context.col, context.col)
  local active = self._active
  local requests = {}
  for _, client in ipairs(clients) do
    local provider = client.server_capabilities.signatureHelpProvider
    local triggers = type(provider) == "table"
        and type(provider.triggerCharacters) == "table"
        and provider.triggerCharacters
      or nil
    local triggered = (triggers ~= nil and vim.list_contains(triggers, character))
      or (
        active ~= nil
        and type(provider) == "table"
        and type(provider.retriggerCharacters) == "table"
        and vim.list_contains(provider.retriggerCharacters, character)
      )
    local kind = force and 1 or triggered and 2 or active ~= nil and 3 or nil
    if kind ~= nil then
      requests[#requests + 1] = { client = client, kind = kind, triggers = triggers }
    end
  end
  if #requests == 0 then
    return false
  end
  self:cancel()
  local generation = self._generation
  vim.defer_fn(function()
    if generation ~= self._generation or not Edit.is_current(context) then
      return
    end
    local pending = #requests
    local shown = false
    for _, request in ipairs(requests) do
      local client = request.client
      local params = {
        textDocument = { uri = vim.uri_from_bufnr(context.bufnr) },
        position = {
          line = context.row,
          character = client.offset_encoding == "utf-8" and context.col
            or vim.str_utfindex(context.line, client.offset_encoding, context.col, false),
        },
        context = {
          triggerKind = request.kind,
          triggerCharacter = request.kind == 2 and character or nil,
          isRetrigger = active ~= nil,
          activeSignatureHelp = active,
        },
      }
      local ok, request_id = client:request("textDocument/signatureHelp", params, function(err, result)
        if generation ~= self._generation or not Edit.is_current(context) then
          return
        end
        pending = pending - 1
        if
          not shown
          and err == nil
          and type(result) == "table"
          and type(result.signatures) == "table"
          and #result.signatures > 0
        then
          shown = true
          self:render(context, result, request.triggers)
        elseif pending == 0 and not shown then
          self:_close()
          self._active = nil
        end
      end, context.bufnr)
      if ok and request_id ~= nil then
        self._requests[#self._requests + 1] = { client = client, id = request_id }
      elseif not ok then
        pending = pending - 1
      end
    end
    if pending == 0 and not shown then
      self:_close()
      self._active = nil
    end
  end, force and 0 or 50)
  return true
end

return M
