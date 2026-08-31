---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.im" ---@type string

---@alias era.m.im.InputMethod
---| "English"
---| "Chinese"

---@alias era.m.im.Snapshot string

---@class era.m.im.IBackend
---@field public capture                fun(): era.m.im.Snapshot|nil, string|nil
---@field public restore                fun(snapshot: era.m.im.Snapshot): boolean|nil, string|nil
---@field public is_input_method        fun(snapshot: era.m.im.Snapshot, input_method: era.m.im.InputMethod): boolean
---@field public get_input_method       fun(): era.m.im.InputMethod|nil, string|nil
---@field public set_input_method       fun(input_method: era.m.im.InputMethod): boolean|nil, string|nil

---@class era.m.im
---@field public dressing               fun(): nil
---@field public get_input_method       fun(): era.m.im.InputMethod|nil
---@field public set_input_method       fun(input_method: era.m.im.InputMethod): nil
local M = {}

local auto_im_subscription = nil ---@type stl.c.IUnsubscribable|nil

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

---@param input_method                  era.m.im.InputMethod
---@param subject                       string
---@return boolean
local function set_input_method(input_method, subject)
  local ok, err = backend.set_input_method(input_method)
  if not ok then
    report_error(subject, "Failed to select input method.", err)
    return false
  end
  return true
end

---@param mode                          string
---@return boolean
local function is_command_mode(mode)
  return mode == "n" or mode:match("^no") ~= nil or mode == "v" or mode == "V" or mode == string.char(22)
end

---@return era.m.im.InputMethod|nil
function M.get_input_method()
  if backend == nil then
    return
  end

  local input_method, err = backend.get_input_method()
  if input_method == nil then
    report_error("get_input_method", "Failed to read current input method.", err)
    return
  end
  return input_method
end

---@param input_method                  era.m.im.InputMethod
---@return nil
function M.set_input_method(input_method)
  if backend == nil then
    return
  end
  set_input_method(input_method, "set_input_method")
end

---@return nil
function M.dressing()
  if backend == nil then
    return
  end

  local augroup = stl.nvim.fn.augroup("era.im_auto_toggle")
  local generation = 0 ---@type integer
  local insert_snapshot = nil ---@type era.m.im.Snapshot|nil

  if auto_im_subscription ~= nil then
    auto_im_subscription.unsubscribe()
  end
  auto_im_subscription = dot.context.behavior.auto_im:subscribe(
    stl.c.Subscriber.new({
      on_next = function(enabled)
        if enabled then
          return
        end
        generation = generation + 1
        insert_snapshot = nil
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
        return
      end

      local snapshot, err = backend.capture()
      insert_snapshot = snapshot
      if snapshot == nil then
        report_error("capture", "Failed to capture the current IM source token.", err)
        set_input_method("English", "InsertLeave")
      elseif not backend.is_input_method(snapshot, "English") then
        set_input_method("English", "InsertLeave")
      end
    end,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = augroup,
    callback = function()
      generation = generation + 1
      local current_generation = generation ---@type integer
      local snapshot = insert_snapshot ---@type era.m.im.Snapshot|nil
      if
        not dot.context.behavior.auto_im:snapshot()
        or snapshot == nil
        or backend.is_input_method(snapshot, "English")
      then
        return
      end

      -- Restore after all synchronous InsertEnter handlers have observed a stable buffer/cursor context.
      vim.schedule(function()
        local mode = vim.api.nvim_get_mode().mode ---@type string
        if current_generation ~= generation or not mode:match("^[iR]") then
          return
        end
        if not dot.context.behavior.auto_im:snapshot() then
          return
        end
        local ok, err = backend.restore(snapshot)
        if not ok then
          report_error("restore", "Failed to restore the IM source token.", err)
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = augroup,
    callback = function()
      if not dot.context.behavior.auto_im:snapshot() then
        return
      end

      local mode = vim.api.nvim_get_mode().mode ---@type string
      if not is_command_mode(mode) then
        return
      end

      -- Do not record the IM source token inherited from another application as Insert-mode state.
      set_input_method("English", "FocusGained")
    end,
  })
end

return M
