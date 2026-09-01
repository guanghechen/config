---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.im" ---@type string

---@alias era.m.im.Snapshot string

---@class era.m.im.IBackend
---@field public capture                fun(): era.m.im.Snapshot|nil, string|nil
---@field public capture_and_select_english fun(): era.m.im.Snapshot|nil, boolean, string|nil
---@field public restore                fun(snapshot: era.m.im.Snapshot): boolean|nil, string|nil
---@field public is_english             fun(snapshot: era.m.im.Snapshot): boolean

---@class era.m.im
---@field public dressing               fun(): nil
local M = {}

local FOCUS_SESSION_LIMIT_NS = 60 * 1e9

local auto_im_subscription = nil ---@type stl.c.IUnsubscribable|nil
local generation = 0 ---@type integer
local insert_snapshot = nil ---@type era.m.im.Snapshot|nil
local focus_session = nil ---@type { entry: era.m.im.Snapshot|nil, editing: era.m.im.Snapshot|nil, started_at: number }|nil

---@param subject                       string
---@param message                       string
---@param err                           string|nil
---@return nil
local function report_error(subject, message, err)
  stl.reporter.error({
    from = __module_name__,
    subject = subject,
    message = message,
    details = { error = err },
  })
end

local backend = nil ---@type era.m.im.IBackend|nil
if stl.env.IS_OSX or stl.env.IS_WIN then
  backend = yoz.im
elseif stl.env.IS_WSL then
  local im = yoz.im
  if im == nil then
    report_error("setup", "WSL IM backend is unavailable.", "Rebuild yoz for the current WSL runtime.")
  elseif im.setup == nil then
    report_error("setup", "WSL IM backend cannot be configured.", "yoz.im.setup is unavailable.")
  else
    local executable = dot.path.locate_config_filepath("bin/wsl.yoz-im.exe")
    local configured, err = im.setup({ executable = executable })
    if configured then
      backend = im
    else
      report_error("setup", "Failed to configure the WSL IM backend.", err)
    end
  end
end

---@param subject                       string
---@return era.m.im.Snapshot|nil
local function capture_snapshot(subject)
  local snapshot, err = backend.capture()
  if snapshot == nil then
    report_error(subject, "Failed to capture the current input-source ID.", err)
  end
  return snapshot
end

---@param subject                       string
---@return era.m.im.Snapshot|nil
local function capture_and_select_english(subject)
  local snapshot, ready, err = backend.capture_and_select_english()
  if not ready then
    report_error(subject, "Failed to capture and select an English input source.", err)
  end
  return snapshot
end

---@param snapshot                      era.m.im.Snapshot
---@param subject                       string
---@return boolean
local function restore_snapshot(snapshot, subject)
  local ok, err = backend.restore(snapshot)
  if not ok then
    report_error(subject, "Failed to restore the input-source ID.", err)
    return false
  end
  return true
end

---@param mode                          string
---@return boolean
local function is_command_mode(mode)
  return mode == "n" or mode:match("^no") ~= nil or mode == "v" or mode == "V" or mode == string.char(22)
end

---@param mode                          string
---@return boolean
local function is_insert_mode(mode)
  return mode:match("^[iR]") ~= nil
end

---@return nil
function M.dressing()
  if backend == nil then
    return
  end

  generation = generation + 1
  local augroup = stl.nvim.fn.augroup("era.im_auto_toggle")

  ---@param subject                     string
  ---@param force_restore               boolean|nil
  local function restore_insert_snapshot(subject, force_restore)
    generation = generation + 1
    local current_generation = generation ---@type integer
    local snapshot = insert_snapshot ---@type era.m.im.Snapshot|nil
    if not dot.context.behavior.auto_im:snapshot() or snapshot == nil then
      return
    end
    if not force_restore and backend.is_english(snapshot) then
      if focus_session ~= nil then
        focus_session.editing = snapshot
      end
      return
    end

    -- Restore after synchronous mode/focus handlers have observed a stable editor context.
    vim.schedule(function()
      local mode = vim.api.nvim_get_mode().mode ---@type string
      if current_generation ~= generation or not is_insert_mode(mode) then
        return
      end
      if not dot.context.behavior.auto_im:snapshot() then
        return
      end
      if restore_snapshot(snapshot, subject) and focus_session ~= nil then
        focus_session.editing = snapshot
      end
    end)
  end

  local function on_focus_gained()
    if focus_session ~= nil or not dot.context.behavior.auto_im:snapshot() or #vim.api.nvim_list_uis() == 0 then
      return
    end

    generation = generation + 1
    local started_at = vim.uv.hrtime() ---@type number
    local mode = vim.api.nvim_get_mode().mode ---@type string
    local entry = nil ---@type era.m.im.Snapshot|nil
    if is_command_mode(mode) then
      entry = capture_and_select_english("FocusGained")
    else
      entry = capture_snapshot("FocusGained")
    end
    focus_session = { entry = entry, editing = nil, started_at = started_at }

    if is_insert_mode(mode) then
      restore_insert_snapshot("FocusGained", true)
    end
  end

  local function on_focus_lost()
    local session = focus_session
    if session == nil then
      return
    end

    generation = generation + 1
    focus_session = nil
    local snapshot = session.entry ---@type era.m.im.Snapshot|nil
    if vim.uv.hrtime() - session.started_at > FOCUS_SESSION_LIMIT_NS and session.editing ~= nil then
      snapshot = session.editing
    end

    if not dot.context.behavior.auto_im:snapshot() or snapshot == nil then
      return
    end
    restore_snapshot(snapshot, "FocusLost")
  end

  if auto_im_subscription ~= nil then
    auto_im_subscription.unsubscribe()
  end
  auto_im_subscription = dot.context.behavior.auto_im:subscribe(
    stl.c.Subscriber.new({
      on_next = function(enabled)
        generation = generation + 1
        if not enabled then
          insert_snapshot = nil
          focus_session = nil
          return
        end
        on_focus_gained()
      end,
    }),
    true
  )

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function()
      generation = generation + 1
      if not dot.context.behavior.auto_im:snapshot() then
        insert_snapshot = nil
        focus_session = nil
        return
      end

      local snapshot = capture_and_select_english("InsertLeave")
      insert_snapshot = snapshot
      if focus_session ~= nil and snapshot ~= nil then
        focus_session.editing = snapshot
      end
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = augroup,
    callback = function()
      restore_insert_snapshot("InsertEnter")
    end,
  })

  vim.api.nvim_create_autocmd({ "UIEnter", "FocusGained", "VimResume" }, {
    group = augroup,
    callback = on_focus_gained,
  })

  vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend", "VimLeavePre" }, {
    group = augroup,
    callback = on_focus_lost,
  })

  vim.api.nvim_create_autocmd("UILeave", {
    group = augroup,
    callback = function()
      if #vim.api.nvim_list_uis() == 0 then
        on_focus_lost()
      end
    end,
  })
end

return M
