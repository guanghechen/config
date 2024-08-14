local constant = require("fml.constant")

---@class fml.std.util
local M = {}

---@param name                          string
---@return integer
function M.augroup(name)
  return vim.api.nvim_create_augroup("fml_" .. name, { clear = true })
end

---@param keymaps                       fml.types.IKeymap[]
---@param keymap_override               fml.types.IKeymapOverridable
function M.bind_keys(keymaps, keymap_override)
  for _, keymap in ipairs(keymaps) do
    vim.keymap.set(keymap.modes, keymap.key, keymap.callback, {
      buffer = keymap_override.bufnr or keymap.bufnr,
      nowait = keymap_override.nowait or keymap.nowait,
      noremap = keymap_override.noremap or keymap.noremap,
      silent = keymap_override.silent or keymap.silent,
    })
  end
end

---@param filename                      string
---@param filetype                      string|nil
---@return string
---@return string
function M.calc_fileicon(filename, filetype)
  local name = (not filename or filename == "") and constant.BUF_UNTITLED or filename
  local icons_present, icons = pcall(require, "mini.icons")
  if icons_present and name ~= constant.BUF_UNTITLED then
    if filetype ~= nil then
      local icon, icon_hl, is_default = icons.get("filetype", filetype)
      if not is_default then
        return icon, icon_hl
      end
    end

    local icon2, icon_hl2, is_default2 = icons.get("file", filename)
    if not is_default2 then
      return icon2, icon_hl2
    end
  end
  return "󰈚", "MiniIconsRed"
end

---@param ...                           any[]
---@return boolean
---@diagnostic disable-next-line: unused-vararg
function M.falsy(...)
  return false
end

---@return string
function M.get_selected_text()
  local saved_reg = vim.fn.getreg("v")
  vim.cmd([[noautocmd sil norm! "vy]])

  local selected_text = vim.fn.getreg("v")
  vim.fn.setreg("v", saved_reg)
  return selected_text or ""
end

---@param value                         any
---@return any
function M.identity(value)
  return value
end

---@param ...                           any[]
---@return any
function M.noop(...) end

---@param name                          string
---@param fn                            fun(): any
---@param callback                      ?fun(ok: boolean, result: any|nil): nil
---@return fun(): nil
function M.run_async(name, fn, callback)
  local handle
  local cancelled = false

  local function wrapped_fn()
    if cancelled then
      vim.notify('[fml.std.util] run_async: The "' .. name .. '" was cancelled.')
    else
      local ok, result = pcall(fn)
      if type(callback) == "function" then
        callback(ok, result)
      end
    end
    handle:close() -- Close the handle when done
  end

  ---@diagnostic disable-next-line: undefined-field
  handle = vim.uv.new_async(vim.schedule_wrap(wrapped_fn))
  handle:send()

  return function()
    cancelled = true
    handle:send() -- Ensure the async function checks the cancelled flag
  end
end

---@param name                          string
---@param fn                            fun(): any
---@param callback                      ?fun(ok: boolean, result: any|nil): nil
---@return fun(): nil
function M.run_async_by_thread(name, fn, callback)
  local cancelled = false ---@type boolean

  ---@param ok                          boolean
  ---@param result                      boolean
  local function wrapped(ok, result)
    if not cancelled then
      if type(callback) == "function" then
        callback(ok, result)
      end
    else
      vim.notify('[fml.std.util] run_async_by_thread: The "' .. name .. '" was cancelled.')
    end
  end

  ---@diagnostic disable-next-line: undefined-field
  local work_handle = vim.uv.new_work(function()
    if cancelled then
      return false, "Cancelled"
    end
    return pcall(fn)
  end, vim.schedule_wrap(wrapped))
  work_handle:queue()

  return function()
    cancelled = true
    ---@diagnostic disable-next-line: undefined-field
    vim.uv.cancel(work_handle)
  end
end

---@param name                          string
---@param fn                            fun(): nil
---@param timeout                       ?integer
---@return nil
function M.schedule(name, fn, timeout)
  local lock = false
  local dirty = true

  local wrapped ---@type fun(): nil
  wrapped = function()
    if lock then
      dirty = true
      return
    end

    lock = true
    dirty = false

    local function run()
      local ok, result = pcall(fn)
      if not ok then
        vim.notify(
          '[fml.std.util] schedule: Failed to run "' .. name .. '".\n' .. vim.inspect({ result = result or "nil" })
        )
      end

      lock = false
      if dirty then
        dirty = false
        wrapped()
      end
    end

    if timeout ~= nil and timeout > 0 then
      vim.defer_fn(run, timeout)
    else
      vim.schedule(run)
    end
  end
  return wrapped
end

---@param ...                           any[]
---@return boolean
---@diagnostic disable-next-line: unused-vararg
function M.truthy(...)
  return true
end

return M
