---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.paste" ---@type string

---@class era.m.paste
local M = {}

local BATCH_BYTES = 1024 * 1024 ---@type integer
local IDLE_MS = 32 ---@type integer
local EVENT_PASTE_SETTLED = "EraPasteSettled" ---@type string

---@alias era.m.paste.State "buffering"|"cancelled"|"idle"|"passthrough"

local active_handler = nil ---@type function|nil

---@param bufnr                         integer
---@return nil
local function notify_settled(bufnr)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    vim.api.nvim_exec_autocmds("User", {
      pattern = EVENT_PASTE_SETTLED,
      modeline = false,
      data = { bufnr = bufnr },
    })
  end)
end

---@param lines                         string[]
---@return string
local function encode(lines)
  return table.concat(lines, "\n")
end

---@return boolean
local function should_buffer()
  if vim.fn.getcmdtype() ~= "" then
    return false
  end

  local mode = vim.api.nvim_get_mode().mode ---@type string
  if mode:find("^n?t") then
    return false
  end

  if not mode:find("^i") and not mode:find("^[nvV\22sS\19]") then
    return false
  end

  return vim.api.nvim_get_option_value("modifiable", { buf = 0 })
end

---@param lines                         string[]
---@return boolean
local function has_content(lines)
  return #lines > 1 or (#lines == 1 and lines[1] ~= "")
end

---@param chunks                        string[]
---@return string[]
local function decode(chunks)
  return vim.split(table.concat(chunks), "\n", { plain = true, trimempty = false })
end

---@return nil
function M.dressing()
  if vim.paste == active_handler then
    return
  end

  local default_paste = vim.paste
  local state = "idle" ---@type era.m.paste.State
  local buffered_chunks = {} ---@type string[]
  local buffered_bytes = 0 ---@type integer
  local downstream_started = false
  local pending_notify = false
  local paste_bufnr = nil ---@type integer|nil
  local idle_flush = nil ---@type stl.timer.IDisposableCallable|nil

  ---@param next_state                   era.m.paste.State|nil
  local function reset(next_state)
    if idle_flush ~= nil then
      idle_flush:cancel()
    end
    state = next_state or "idle"
    buffered_chunks = {}
    buffered_bytes = 0
    downstream_started = false
    pending_notify = false
    paste_bufnr = nil
  end

  ---@return boolean
  local function flush_stream()
    if state ~= "buffering" or buffered_bytes == 0 then
      buffered_chunks = {}
      return true
    end

    local lines_all = decode(buffered_chunks)
    buffered_chunks = {}
    buffered_bytes = 0
    local downstream_phase = downstream_started and 2 or 1
    downstream_started = true
    local result = default_paste(lines_all, downstream_phase)
    if result == true then
      pending_notify = true
    else
      reset("cancelled")
    end
    return result
  end

  local function notify_if_needed()
    if pending_notify and paste_bufnr ~= nil then
      local bufnr = paste_bufnr
      pending_notify = false
      notify_settled(bufnr)
    end
  end

  idle_flush = stl.timer.debounce(function()
    if flush_stream() == true then
      notify_if_needed()
    end
  end, IDLE_MS)

  active_handler = function(lines, phase)
    if phase == -1 then
      local notify = should_buffer()
      local bufnr = notify and vim.api.nvim_get_current_buf() or nil ---@type integer|nil
      reset()
      local result = default_paste(lines, phase)
      if result == true and bufnr ~= nil and has_content(lines) then
        notify_settled(bufnr)
      end
      return result
    end

    if phase == 1 then
      reset()
      if not should_buffer() then
        state = "passthrough"
        local result = default_paste(lines, phase)
        if result ~= true then
          reset("cancelled")
        end
        return result
      end
      state = "buffering"
      local chunk = encode(lines) ---@type string
      buffered_chunks = { chunk }
      buffered_bytes = #chunk
      paste_bufnr = vim.api.nvim_get_current_buf()

      if buffered_bytes >= BATCH_BYTES then
        local result = flush_stream()
        if result == true then
          idle_flush()
        end
        return result
      end
      idle_flush()
      return true
    end

    if state == "cancelled" then
      return false
    end

    if state == "passthrough" then
      local result = default_paste(lines, phase)
      if result ~= true then
        reset("cancelled")
      elseif phase == 3 then
        reset()
      end
      return result
    end

    if state ~= "buffering" then
      return default_paste(lines, phase)
    end

    local chunk = encode(lines) ---@type string
    buffered_chunks[#buffered_chunks + 1] = chunk
    buffered_bytes = buffered_bytes + #chunk

    if phase == 3 then
      idle_flush:cancel()
      local buffered = buffered_bytes > 0
      local lines_all = buffered and decode(buffered_chunks) or { "" }
      local downstream_phase = downstream_started and 3 or -1
      local bufnr = paste_bufnr or vim.api.nvim_get_current_buf() ---@type integer
      local notify = pending_notify or buffered
      reset()
      local result = default_paste(lines_all, downstream_phase)
      if result == true and notify then
        notify_settled(bufnr)
      end
      return result
    end

    if buffered_bytes < BATCH_BYTES then
      idle_flush()
      return true
    end

    local result = flush_stream()
    if result == true then
      idle_flush()
    end
    return result
  end
  vim.paste = active_handler
end

return M
