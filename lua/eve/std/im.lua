local constant = require("eve.builtin.constant")
local reporter = require("eve.builtin.reporter")
local path = require("eve.std.path")

---@class eve.std.im
---@field public get_input_method   fun(): eve.e.InputMethod|nil
---@field public set_input_method   fun(input_method: eve.e.InputMethod): nil
local M = {}

if constant.IS_MAC then
  local app_home = path.locate_app_config_home("guanghechen")
  local script_path = path.join(app_home, "osx/script/im-select/im-select")

  ---@return eve.e.InputMethod|nil
  function M.get_input_method()
    if not vim.fn.executable(script_path) then
      reporter.error({
        from = "eve.std.im",
        subject = "get_input_method",
        message = "Not a executable file.",
        details = { app_home = app_home, script_path = script_path },
      })
      return
    end

    local handle = io.popen(vim.fn.fnameescape(script_path))
    if not handle then
      reporter.error({
        from = "eve.std.im",
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
      from = "eve.std.im",
      subject = "get_input_method",
      message = "Unknown input method.",
      details = { app_home = app_home, script_path = script_path, input_method = input_method },
    })
  end

  ---@param input_method                eve.e.InputMethod
  ---@return nil
  function M.set_input_method(input_method)
    if not vim.fn.executable(script_path) then
      reporter.error({
        from = "eve.std.im",
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
        from = "eve.std.im",
        subject = "get_input_method",
        message = "Unknown input method.",
        details = { app_home = app_home, script_path = script_path, input_method = input_method },
      })
      return
    end

    local handle = io.popen(vim.fn.fnameescape(script_path) .. " " .. arg)
    if not handle then
      reporter.error({
        from = "eve.std.im",
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
        from = "eve.std.im",
        subject = "set_input_method",
        message = "Unexpected output from the executable file.",
        details = { app_home = app_home, script_path = script_path, input_method = input_method, output = output },
      })
    end
  end
end

return M
