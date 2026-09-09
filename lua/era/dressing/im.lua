---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.im" ---@type string

---@alias era.dressing.im.Snapshot string

---@class era.dressing.im
---@field public dressing               fun(): nil
local M = {}

---@param subject                       string
---@param message                       string
---@param err                           string|nil
---@param retry_after_ms                ?integer
---@return nil
local function report_error(subject, message, err, retry_after_ms)
  stl.reporter.error({
    from = __module_name__,
    subject = subject,
    message = message,
    details = { error = err, retry_after_ms = retry_after_ms },
  })
end

---@return yoz.im|nil
local function setup_backend()
  if stl.env.IS_OSX or stl.env.IS_WIN then
    return yoz.im
  end
  if not stl.env.IS_WSL then
    return nil
  end

  local im = yoz.im
  if im == nil then
    report_error("setup", "WSL IM backend is unavailable.", "Rebuild yoz for the current WSL runtime.")
    return nil
  end
  if im.setup == nil then
    report_error("setup", "WSL IM backend cannot be configured.", "yoz.im.setup is unavailable.")
    return nil
  end

  local executable = dot.path.locate_config_filepath("bin/wsl.yoz-im.exe")
  local configured, err = im.setup({ executable = executable })
  if not configured then
    report_error("setup", "Failed to configure the WSL IM backend.", err)
    return nil
  end
  return im
end

local backend = setup_backend()
local auto_im_subscription = nil ---@type stl.c.IUnsubscribable|nil
local focused = false ---@type boolean
local focus_generation = 0 ---@type integer
local insert_snapshot = nil ---@type era.dressing.im.Snapshot|nil
-- This permits a local shortcut; it does not acknowledge completion inside the OS IME.
local can_skip_english_restore = false ---@type boolean

---@class era.dressing.im.RetryState
---@field delay_ms                      integer
---@field retry_at_ns                   integer

local capture_retry = { delay_ms = 0, retry_at_ns = 0 } ---@type era.dressing.im.RetryState
local selection_retry = { delay_ms = 0, retry_at_ns = 0 } ---@type era.dressing.im.RetryState
local restore_retry = { delay_ms = 0, retry_at_ns = 0 } ---@type era.dressing.im.RetryState
local restore_target = nil ---@type era.dressing.im.Snapshot|nil
-- WSL can block for the helper's one-second deadline; native failures use a fixed short cooldown.
local MAX_RETRY_DELAY_MS = stl.env.IS_WSL and 8000 or 1000 ---@type integer

---@param retry                         era.dressing.im.RetryState
---@return nil
local function reset_retry(retry)
  retry.delay_ms = 0
  retry.retry_at_ns = 0
end

---@param retry                         era.dressing.im.RetryState
---@return nil
local function postpone_retry(retry)
  retry.delay_ms = math.min(retry.delay_ms == 0 and 1000 or retry.delay_ms * 2, MAX_RETRY_DELAY_MS)
  -- Start the cooldown after the synchronous backend call has returned.
  retry.retry_at_ns = vim.uv.hrtime() + retry.delay_ms * 1e6
end

---@param retry                         era.dressing.im.RetryState
---@return boolean
local function can_retry(retry)
  return retry.retry_at_ns == 0 or vim.uv.hrtime() >= retry.retry_at_ns
end

---@param subject                       string
---@return era.dressing.im.Snapshot|nil
local function capture_and_select_english(subject)
  local im = backend
  can_skip_english_restore = false
  if im == nil or not can_retry(capture_retry) then
    return nil
  end

  if not can_retry(selection_retry) then
    -- Selection can fail while capture remains healthy; keep observing the Insert source.
    local snapshot, err = im.capture()
    if snapshot ~= nil then
      reset_retry(capture_retry)
    else
      postpone_retry(capture_retry)
      report_error(subject, "Failed to capture the input-source ID.", err, capture_retry.delay_ms)
    end
    return snapshot
  end

  local snapshot, ok, err = im.capture_and_select_english()
  if snapshot == nil then
    postpone_retry(capture_retry)
    report_error(subject, "Failed to capture and select an English input source.", err, capture_retry.delay_ms)
    return nil
  end

  reset_retry(capture_retry)
  if ok then
    reset_retry(selection_retry)
    can_skip_english_restore = true
  else
    postpone_retry(selection_retry)
    report_error(subject, "Failed to capture and select an English input source.", err, selection_retry.delay_ms)
  end
  return snapshot
end

---@param snapshot                      era.dressing.im.Snapshot
---@param subject                       string
---@return nil
local function restore_snapshot(snapshot, subject)
  local im = backend
  can_skip_english_restore = false
  if im == nil then
    return
  end

  if restore_target ~= snapshot then
    restore_target = snapshot
    reset_retry(restore_retry)
  end
  if not can_retry(restore_retry) then
    return
  end

  local restored, err = im.restore(snapshot)
  if restored then
    reset_retry(restore_retry)
    can_skip_english_restore = im.is_english(snapshot)
  else
    postpone_retry(restore_retry)
    report_error(subject, "Failed to restore the input-source ID.", err, restore_retry.delay_ms)
  end
end

---@param subject                       string
---@return nil
local function restore_insert_snapshot_if_needed(subject)
  local im = backend
  if not dot.context.behavior.auto_im:snapshot() or insert_snapshot == nil or im == nil then
    return
  end
  -- A read-only capture does not rule out an earlier conflicting selection still taking effect.
  if can_skip_english_restore and im.is_english(insert_snapshot) then
    return
  end
  restore_snapshot(insert_snapshot, subject)
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

---@param subject                       string
---@return nil
local function reconcile_focused_source(subject)
  if not focused or not dot.context.behavior.auto_im:snapshot() then
    return
  end

  local mode = vim.api.nvim_get_mode().mode ---@type string
  if is_command_mode(mode) then
    capture_and_select_english(subject)
  elseif is_insert_mode(mode) and insert_snapshot ~= nil then
    restore_snapshot(insert_snapshot, subject)
  end
end

---@param enabled                       boolean
---@return nil
local function on_auto_im_changed(enabled)
  reset_retry(capture_retry)
  reset_retry(selection_retry)
  reset_retry(restore_retry)
  restore_target = nil
  can_skip_english_restore = false
  if not enabled then
    insert_snapshot = nil
    return
  end
  reconcile_focused_source("auto_im")
end

---@return nil
local function on_insert_leave()
  if not dot.context.behavior.auto_im:snapshot() then
    insert_snapshot = nil
    can_skip_english_restore = false
    return
  end
  -- A failed or cooled-down query cannot identify this Insert session's source.
  insert_snapshot = capture_and_select_english("InsertLeave")
end

---@return nil
local function on_insert_enter()
  -- InsertEnter fires before nvim_get_mode() reports Insert, so this event is the mode contract.
  restore_insert_snapshot_if_needed("InsertEnter")
end

---@return integer|nil
local function acquire_focus()
  if focused then
    return nil
  end
  focus_generation = focus_generation + 1
  focused = true
  return focus_generation
end

---@return nil
local function on_focus_gained()
  if acquire_focus() == nil then
    return
  end
  reconcile_focused_source("FocusGained")
end

---@return nil
local function on_vim_resume()
  -- Resuming a headless process does not establish its host's focus.
  if #vim.api.nvim_list_uis() > 0 then
    on_focus_gained()
  end
end

---@return nil
local function on_ui_enter()
  if #vim.api.nvim_list_uis() == 0 then
    return
  end
  local generation = acquire_focus()
  if generation == nil then
    return
  end

  vim.schedule(function()
    if generation ~= focus_generation then
      return
    end
    reconcile_focused_source("UIEnter")
  end)
end

---@return nil
local function on_focus_lost()
  can_skip_english_restore = false
  if not focused then
    return
  end
  focus_generation = focus_generation + 1
  focused = false
end

---@return nil
local function on_ui_leave()
  if #vim.api.nvim_list_uis() == 0 then
    on_focus_lost()
  end
end

---@return nil
function M.dressing()
  if backend == nil then
    return
  end

  local augroup = stl.nvim.fn.augroup("era.im_auto_toggle")
  if auto_im_subscription ~= nil then
    auto_im_subscription:unsubscribe()
  end
  local subscriber = stl.c.Subscriber.new({ on_next = on_auto_im_changed })
  auto_im_subscription = dot.context.behavior.auto_im:subscribe(subscriber, true)

  vim.api.nvim_create_autocmd("InsertLeave", { group = augroup, callback = on_insert_leave })
  vim.api.nvim_create_autocmd("InsertEnter", { group = augroup, callback = on_insert_enter })
  vim.api.nvim_create_autocmd("UIEnter", { group = augroup, callback = on_ui_enter })
  vim.api.nvim_create_autocmd("FocusGained", { group = augroup, callback = on_focus_gained })
  vim.api.nvim_create_autocmd("VimResume", { group = augroup, callback = on_vim_resume })
  vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend", "VimLeavePre" }, {
    group = augroup,
    callback = on_focus_lost,
  })
  vim.api.nvim_create_autocmd("UILeave", { group = augroup, callback = on_ui_leave })
end

return M
