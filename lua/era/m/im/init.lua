---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.im" ---@type string

---@alias era.m.im.Snapshot string

---@class era.m.im
---@field public dressing               fun(): nil
local M = {}

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
local insert_snapshot = nil ---@type era.m.im.Snapshot|nil

---@return boolean
local function owns_source()
  return focused and dot.context.behavior.auto_im:snapshot()
end

---@param subject                       string
---@return era.m.im.Snapshot|nil
local function capture_and_select_english(subject)
  local im = backend
  if im == nil then
    return nil
  end

  local snapshot, ready, err = im.capture_and_select_english()
  if not ready then
    report_error(subject, "Failed to capture and select an English input source.", err)
  end
  return snapshot
end

---@param snapshot                      era.m.im.Snapshot
---@param subject                       string
local function restore_snapshot(snapshot, subject)
  local im = backend
  if im == nil then
    return
  end

  local restored, err = im.restore(snapshot)
  if not restored then
    report_error(subject, "Failed to restore the input-source ID.", err)
  end
end

---@param subject                       string
local function restore_insert_snapshot(subject)
  if not owns_source() or insert_snapshot == nil then
    return
  end
  restore_snapshot(insert_snapshot, subject)
end

---@param subject                       string
local function restore_non_english_insert_snapshot(subject)
  local im = backend
  if not owns_source() or insert_snapshot == nil or im == nil or im.is_english(insert_snapshot) then
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
local function reconcile_focused_source(subject)
  if not owns_source() then
    return
  end

  local mode = vim.api.nvim_get_mode().mode ---@type string
  if is_command_mode(mode) then
    capture_and_select_english(subject)
  elseif is_insert_mode(mode) then
    restore_insert_snapshot(subject)
  end
end

---@param enabled                       boolean
local function on_auto_im_changed(enabled)
  if not enabled then
    insert_snapshot = nil
    return
  end
  reconcile_focused_source("auto_im")
end

local function on_insert_leave()
  if not owns_source() then
    insert_snapshot = nil
    return
  end
  insert_snapshot = capture_and_select_english("InsertLeave")
end

local function on_insert_enter()
  -- InsertEnter fires before nvim_get_mode() reports Insert, so this event is the mode contract.
  restore_non_english_insert_snapshot("InsertEnter")
end

local function on_focus_gained()
  if focused or #vim.api.nvim_list_uis() == 0 then
    return
  end
  focused = true
  reconcile_focused_source("FocusGained")
end

local function on_focus_lost()
  focused = false
end

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
  vim.api.nvim_create_autocmd({ "UIEnter", "FocusGained", "VimResume" }, {
    group = augroup,
    callback = on_focus_gained,
  })
  vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend", "VimLeavePre" }, {
    group = augroup,
    callback = on_focus_lost,
  })
  vim.api.nvim_create_autocmd("UILeave", { group = augroup, callback = on_ui_leave })
end

return M
