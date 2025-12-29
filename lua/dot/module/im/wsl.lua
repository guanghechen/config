local __module_name__ = "dot.module.im.wsl" ---@type string

---@class dot.module.im.wsl : dot.module.im
local M = {}

local app_home = dot.path.locate_app_config_home("guanghechen")
local script_path = dot.path.join(
  app_home,
  (stl.env.IS_X64 and "bin/im-select/win/x64/im-select.exe")
    or (stl.env.IS_X86 and "bin/im-select/win/x86/im-select.exe")
    or "bin/im-select/win/x64/im-select.exe"
)

---@return dot.module.im.InputMethod|nil
function M.get_input_method()
  if not vim.fn.executable(script_path) then
    stl.reporter.error({
      from = __module_name__,
      subject = "get_input_method",
      message = "Not a executable file.",
      details = { app_home = app_home, script_path = script_path },
    })
    return
  end

  local handle = io.popen(vim.fn.fnameescape(script_path))
  if not handle then
    stl.reporter.error({
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
  if input_method == "1033" then
    return "English"
  elseif input_method == "2052" then
    return "Chinese"
  end

  stl.reporter.error({
    from = __module_name__,
    subject = "get_input_method",
    message = "Unknown input method.",
    details = { app_home = app_home, script_path = script_path, input_method = input_method },
  })
end

---@param input_method                  dot.module.im.InputMethod
---@return nil
function M.set_input_method(input_method)
  if not vim.fn.executable(script_path) then
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
    arg = "1033"
  elseif input_method == "Chinese" then
    arg = "2052"
  else
    stl.reporter.error({
      from = __module_name__,
      subject = "get_input_method",
      message = "Unknown input method.",
      details = { app_home = app_home, script_path = script_path, input_method = input_method },
    })
    return
  end

  local handle = io.popen(vim.fn.fnameescape(script_path) .. " " .. arg)
  if not handle then
    stl.reporter.error({
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
    stl.reporter.error({
      from = __module_name__,
      subject = "set_input_method",
      message = "Unexpected output from the executable file.",
      details = { app_home = app_home, script_path = script_path, input_method = input_method, output = output },
    })
  end
end

return M
