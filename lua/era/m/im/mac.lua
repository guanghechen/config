---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.im.mac" ---@type string

-- cspell:ignore SCIM ITABC

---@class era.m.im.mac : era.m.im
local M = {}

local app_home = dot.path.locate_app_config_home("guanghechen")
local script_path = dot.path.join(app_home, "cli/im-select/osx/im-select")

---@return era.m.im.InputMethod|nil
function M.get_input_method()
  if vim.fn.executable(script_path) ~= 1 then
    stl.reporter.error({
      from = __module_name__,
      subject = "get_input_method",
      message = "Not a executable file.",
      details = { app_home = app_home, script_path = script_path },
    })
    return
  end

  local ok, input_method = pcall(vim.fn.system, { script_path })
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "get_input_method",
      message = "Failed to start the executable file.",
      details = { app_home = app_home, script_path = script_path, error = input_method },
    })
    return
  end
  ---@cast input_method string
  local exit_code = vim.v.shell_error ---@type integer
  if exit_code ~= 0 then
    stl.reporter.error({
      from = __module_name__,
      subject = "get_input_method",
      message = "Failed to run the executable file.",
      details = { app_home = app_home, script_path = script_path, exit_code = exit_code, output = input_method },
    })
    return
  end

  input_method = input_method:match("^%s*(.-)%s*$")
  if input_method == "com.apple.keylayout.ABC" then
    return "English"
  elseif input_method == "com.apple.inputmethod.SCIM.ITABC" then
    return "Chinese"
  end

  stl.reporter.error({
    from = __module_name__,
    subject = "get_input_method",
    message = "Unknown input method.",
    details = { app_home = app_home, script_path = script_path, input_method = input_method },
  })
end

---@param input_method                  era.m.im.InputMethod
---@return nil
function M.set_input_method(input_method)
  if vim.fn.executable(script_path) ~= 1 then
    stl.reporter.error({
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
    stl.reporter.error({
      from = __module_name__,
      subject = "get_input_method",
      message = "Unknown input method.",
      details = { app_home = app_home, script_path = script_path, input_method = input_method },
    })
    return
  end

  local ok, output = pcall(vim.fn.system, { script_path, arg })
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "set_input_method",
      message = "Failed to start the executable file.",
      details = { app_home = app_home, script_path = script_path, input_method = input_method, error = output },
    })
    return
  end
  ---@cast output string
  local exit_code = vim.v.shell_error ---@type integer
  if exit_code ~= 0 then
    stl.reporter.error({
      from = __module_name__,
      subject = "set_input_method",
      message = "Failed to run the executable file.",
      details = {
        app_home = app_home,
        script_path = script_path,
        input_method = input_method,
        exit_code = exit_code,
        output = output,
      },
    })
    return
  end

  if output ~= "" then
    stl.reporter.error({
      from = __module_name__,
      subject = "set_input_method",
      message = "Unexpected output from the executable file.",
      details = { app_home = app_home, script_path = script_path, input_method = input_method, output = output },
    })
  end
end

return M
