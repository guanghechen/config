local __module_name__ = "dot.module.lsp.diagnostic" ---@type string

local DEBOUNCE_MS = 50 ---@type integer

---@param a                             dot.module.lsp.diagnostic.IBufferDiagnostics|nil
---@param b                             dot.module.lsp.diagnostic.IBufferDiagnostics|nil
---@return boolean
local function equals_buffer(a, b)
  if a == nil and b == nil then
    return true
  end
  if a == nil or b == nil then
    return false
  end
  return a.bufnr == b.bufnr
    and a.error == b.error
    and a.warn == b.warn
    and a.info == b.info
    and a.hint == b.hint
end

---@param a                             dot.module.lsp.diagnostic.IAllDiagnostics
---@param b                             dot.module.lsp.diagnostic.IAllDiagnostics
---@return boolean
local function equals_all(a, b)
  if a.error ~= b.error or a.warn ~= b.warn or a.info ~= b.info or a.hint ~= b.hint or a.total ~= b.total then
    return false
  end

  local a_buffers = a.buffers ---@type table<integer, dot.module.lsp.diagnostic.IBufferDiagnostics>
  local b_buffers = b.buffers ---@type table<integer, dot.module.lsp.diagnostic.IBufferDiagnostics>

  for bufnr, a_buf in pairs(a_buffers) do
    if not equals_buffer(a_buf, b_buffers[bufnr]) then
      return false
    end
  end

  for bufnr, _ in pairs(b_buffers) do
    if a_buffers[bufnr] == nil then
      return false
    end
  end

  return true
end

---@return dot.module.lsp.diagnostic.IAllDiagnostics
local function create_empty_all()
  ---@type dot.module.lsp.diagnostic.IAllDiagnostics
  return {
    error = 0,
    warn = 0,
    info = 0,
    hint = 0,
    total = 0,
    buffers = {},
  }
end

---@param bufnr                         integer
---@return dot.module.lsp.diagnostic.IBufferDiagnostics
local function create_empty_buffer(bufnr)
  ---@type dot.module.lsp.diagnostic.IBufferDiagnostics
  return {
    bufnr = bufnr,
    error = 0,
    warn = 0,
    info = 0,
    hint = 0,
    total = 0,
  }
end

---@class dot.module.lsp.diagnostic
local M = {}

---@type ark.c.Observable<dot.module.lsp.diagnostic.IAllDiagnostics>
M.o_all = ark.c.Observable.from_value(create_empty_all(), equals_all)

---@type table<integer, ark.c.Observable<dot.module.lsp.diagnostic.IBufferDiagnostics>>
M._buffer_observables = {}

---@type ark.timer.IDisposableCallable
local refresh_debounced

---@return dot.module.lsp.diagnostic.IAllDiagnostics
local function collect()
  local diagnostics = vim.diagnostic.get() ---@type vim.Diagnostic[]

  ---@type dot.module.lsp.diagnostic.IAllDiagnostics
  local result = create_empty_all()

  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr ---@type integer|nil
    if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
      local severity = diagnostic.severity ---@type vim.diagnostic.Severity

      local buf_data = result.buffers[bufnr] ---@type dot.module.lsp.diagnostic.IBufferDiagnostics|nil
      if buf_data == nil then
        buf_data = create_empty_buffer(bufnr)
        result.buffers[bufnr] = buf_data
      end

      if severity == vim.diagnostic.severity.ERROR then
        buf_data.error = buf_data.error + 1
        result.error = result.error + 1
      elseif severity == vim.diagnostic.severity.WARN then
        buf_data.warn = buf_data.warn + 1
        result.warn = result.warn + 1
      elseif severity == vim.diagnostic.severity.INFO then
        buf_data.info = buf_data.info + 1
        result.info = result.info + 1
      elseif severity == vim.diagnostic.severity.HINT then
        buf_data.hint = buf_data.hint + 1
        result.hint = result.hint + 1
      end

      buf_data.total = buf_data.total + 1
      result.total = result.total + 1
    end
  end

  return result
end

local function do_refresh()
  local prev_all = M.o_all:snapshot() ---@type dot.module.lsp.diagnostic.IAllDiagnostics
  local next_all = collect() ---@type dot.module.lsp.diagnostic.IAllDiagnostics

  local prev_buffers = prev_all.buffers ---@type table<integer, dot.module.lsp.diagnostic.IBufferDiagnostics>
  local next_buffers = next_all.buffers ---@type table<integer, dot.module.lsp.diagnostic.IBufferDiagnostics>

  local changed_bufnrs = {} ---@type table<integer, boolean>

  for bufnr, next_buf in pairs(next_buffers) do
    local prev_buf = prev_buffers[bufnr] ---@type dot.module.lsp.diagnostic.IBufferDiagnostics|nil
    if not equals_buffer(prev_buf, next_buf) then
      changed_bufnrs[bufnr] = true
    end
  end

  for bufnr, _ in pairs(prev_buffers) do
    if next_buffers[bufnr] == nil then
      changed_bufnrs[bufnr] = true
    end
  end

  for bufnr, _ in pairs(changed_bufnrs) do
    local observable = M._buffer_observables[bufnr] ---@type ark.c.Observable<dot.module.lsp.diagnostic.IBufferDiagnostics>|nil
    if observable ~= nil and not observable:isdisposed() then
      local next_buf = next_buffers[bufnr] or create_empty_buffer(bufnr) ---@type dot.module.lsp.diagnostic.IBufferDiagnostics
      observable:next(next_buf)
    end
  end

  M.o_all:next(next_all)
end

refresh_debounced = ark.timer.debounce(do_refresh, DEBOUNCE_MS)

---@param filepath                      string
---@param offset                        integer
---@param highlights                    ark.t.IHighlightInline[]
---@return string
function M.render(filepath, offset, highlights)
  local bufnr = ark.nvim.locate_bufnr(filepath) ---@type integer|nil
  if bufnr == nil or bufnr < 1 then
    return ""
  end

  local data = M.o_all:snapshot().buffers[bufnr] ---@type dot.module.lsp.diagnostic.IBufferDiagnostics|nil
  if data == nil then
    return ""
  end

  local text = "" ---@type string

  if data.error > 0 then
    local part = " " .. ark.icon.diagnostic.Error_alt .. " " .. data.error ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_error" }
    offset = offset_next
  end

  if data.warn > 0 then
    local part = " " .. ark.icon.diagnostic.Warning_alt .. " " .. data.warn ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_warn" }
    offset = offset_next
  end

  if data.hint > 0 then
    local part = " " .. ark.icon.diagnostic.Hint_alt .. " " .. data.hint ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_hint" }
    offset = offset_next
  end

  if data.info > 0 then
    local part = " " .. ark.icon.diagnostic.Information_alt .. " " .. data.info ---@type string
    local offset_next = offset + #part ---@type integer
    text = text .. part ---@type string
    highlights[#highlights + 1] = { coll = offset, colr = offset_next, hlname = "f_lsp_diagnostic_info" }
    offset = offset_next
  end

  return text
end

---@return dot.module.lsp.diagnostic.IAllDiagnostics
function M.get_all()
  return M.o_all:snapshot()
end

---@param bufnr                         integer
---@return dot.module.lsp.diagnostic.IBufferDiagnostics|nil
function M.get_by_bufnr(bufnr)
  local all = M.o_all:snapshot() ---@type dot.module.lsp.diagnostic.IAllDiagnostics
  return all.buffers[bufnr]
end

---@return nil
function M.refresh()
  refresh_debounced()
end

---@param subscriber                    ark.c.ISubscriber
---@param ignore_initial                ?boolean
---@return ark.c.IUnsubscribable
function M.subscribe_all(subscriber, ignore_initial)
  return M.o_all:subscribe(subscriber, ignore_initial)
end

---@param bufnr                         integer
---@param subscriber                    ark.c.ISubscriber
---@param ignore_initial                ?boolean
---@return ark.c.IUnsubscribable
function M.subscribe_bufnr(bufnr, subscriber, ignore_initial)
  local observable = M._buffer_observables[bufnr] ---@type ark.c.Observable<dot.module.lsp.diagnostic.IBufferDiagnostics>|nil

  if observable == nil or observable:isdisposed() then
    local all = M.o_all:snapshot() ---@type dot.module.lsp.diagnostic.IAllDiagnostics
    local initial = all.buffers[bufnr] or create_empty_buffer(bufnr) ---@type dot.module.lsp.diagnostic.IBufferDiagnostics
    observable = ark.c.Observable.from_value(initial, equals_buffer)
    M._buffer_observables[bufnr] = observable
  end

  return observable:subscribe(subscriber, ignore_initial)
end

---@return nil
function M.setup()
  local augroup = ark.nvim.augroup(__module_name__) ---@type integer

  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = augroup,
    callback = function()
      M.refresh()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = augroup,
    callback = function(args)
      local bufnr = args.buf ---@type integer
      local observable = M._buffer_observables[bufnr] ---@type ark.c.Observable<dot.module.lsp.diagnostic.IBufferDiagnostics>|nil
      if observable ~= nil then
        observable:dispose()
        M._buffer_observables[bufnr] = nil
      end
    end,
  })

  do_refresh()
end

return M
