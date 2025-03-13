local __module_name__ = "eve.builtin.im" ---@type string

local env = require("eve.std.env")
local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")

---@alias eve.builtin.im.InputMethod
---|"English"
---|"Chinese"

---@class eve.builtin.im
---@field public get_input_method   fun(): eve.builtin.im.InputMethod|nil
---@field public set_input_method   fun(input_method: eve.builtin.im.InputMethod): nil
local M = {}

if env.IS_MAC then
  local app_home = path.locate_app_config_home("guanghechen")
  local script_path = path.join(app_home, "osx/script/im-select/im-select")

  ---@return eve.builtin.im.InputMethod|nil
  function M.get_input_method()
    if not vim.fn.executable(script_path) then
      reporter.error({
        from = __module_name__,
        subject = "get_input_method",
        message = "Not a executable file.",
        details = { app_home = app_home, script_path = script_path },
      })
      return
    end

    local handle = io.popen(vim.fn.fnameescape(script_path))
    if not handle then
      reporter.error({
        from = __module_name__,
        subject = "get_input_method",
        message = "Failed to run the executable file.",
        details = { app_home = app_home, script_path = script_path },
      })
      return
    end

    local input_method = handle:read("*a")
    handle:close()

    if input_method == nil then
      return
    end

    input_method = input_method:match("^%s*(.-)%s*$")
    if input_method == "com.apple.keylayout.ABC" then
      return "English"
    elseif input_method == "com.apple.inputmethod.SCIM.ITABC" then
      return "Chinese"
    end

    reporter.error({
      from = __module_name__,
      subject = "get_input_method",
      message = "Unknown input method.",
      details = { app_home = app_home, script_path = script_path, input_method = input_method },
    })
  end

  ---@param input_method                eve.builtin.im.InputMethod
  ---@return nil
  function M.set_input_method(input_method)
    if not vim.fn.executable(script_path) then
      reporter.error({
        from = __module_name__,
        subject = "set_input_method",
        message = "Not a executable file.",
        details = { app_home = app_home, script_path = script_path, input_method = input_method },
      })
      return
    end

    local arg = "" ---@type string
    if input_method == "English" then
      arg = "com.apple.keylayout.ABC"
    elseif input_method == "Chinese" then
      arg = "com.apple.inputmethod.SCIM.ITABC"
    else
      reporter.error({
        from = __module_name__,
        subject = "get_input_method",
        message = "Unknown input method.",
        details = { app_home = app_home, script_path = script_path, input_method = input_method },
      })
      return
    end

    local handle = io.popen(vim.fn.fnameescape(script_path) .. " " .. arg)
    if not handle then
      reporter.error({
        from = __module_name__,
        subject = "set_input_method",
        message = "Failed to run the executable file.",
        details = { app_home = app_home, script_path = script_path, input_method = input_method },
      })
      return
    end

    local output = handle:read("*a")
    handle:close()

    if output ~= nil and output ~= "" then
      reporter.error({
        from = __module_name__,
        subject = "set_input_method",
        message = "Unexpected output from the executable file.",
        details = { app_home = app_home, script_path = script_path, input_method = input_method, output = output },
      })
    end
  end
end

return M
