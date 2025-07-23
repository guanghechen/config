local __module_name__ = "eve.context.workspace.lsp" ---@type string

---@class eve.context.lsp.IBreakpointData
---@field public filepath               string
---@field public lnum                   integer
---@field public condition              ?string
---@field public hit_condition          ?string
---@field public log_message            ?string

---@class eve.context.lsp.data
---@field public breakpoints            eve.context.lsp.IBreakpointData[]
---@field public code_lens              boolean
---@field public diagnostics_virt_lines boolean
---@field public inlay_hints            boolean
---@field public python_debug_host      string
---@field public python_debug_port      integer
---@field public python_venv_path       string|nil
---@field public spellcheck             boolean

---@class eve.context.lsp.state
---@field public breakpoints            std.collection.IObservable
---@field public code_lens              std.collection.IObservable
---@field public diagnostics_virt_lines std.collection.IObservable
---@field public inlay_hints            std.collection.IObservable
---@field public python_debug_host      std.collection.IObservable
---@field public python_debug_port      std.collection.IObservable
---@field public python_venv_path       std.collection.IObservable
---@field public spellcheck             std.collection.IObservable
---
---@field public get_python_bin_path    fun(): string|nil, string|nil
---@field public refresh_breakpoints    fun(): nil

---@class eve.context.lsp : eve.context.lsp.state
---@field public defaults               fun(): eve.context.lsp.data
---@field public dump                   fun(): eve.context.lsp.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.lsp.data
local M = {}

---@param workspace                     string
---@param breakpoint                    table
---@return boolean
local function is_valid_breakpoint(workspace, breakpoint)
  if
    type(breakpoint.filepath) == "string"
    and type(breakpoint.lnum) == "number"
    and (breakpoint.condition == nil or type(breakpoint.condition) == "string")
    and (breakpoint.hit_condition == nil or type(breakpoint.hit_condition) == "string")
    and (breakpoint.log_message == nil or type(breakpoint.log_message) == "string")
  then
    breakpoint.filepath = std.path.resolve(workspace, breakpoint.filepath) ---@type string
    return vim.fn.filereadable(breakpoint.filepath) == 1
  end
  return false
end

---@return eve.context.lsp.data
function M.defaults()
  local is_git_repo = std.env.IS_GIT_REPO ---@type boolean
  local is_repo_personal = std.path.is_repo_personal_public() ---@type boolean

  ---@type eve.context.lsp.data
  return {
    breakpoints = {},
    code_lens = false,
    diagnostics_virt_lines = false,
    inlay_hints = is_git_repo,
    python_debug_host = "127.0.0.1",
    python_debug_port = 9527,
    python_venv_path = nil,
    spellcheck = is_repo_personal,
  }
end

---@param data                        any
---@return eve.context.lsp.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.lsp.data
  local workspace = std.path.workspace() ---@type string
  if type(data) == "table" then
    if type(data.breakpoints) == "table" then
      resolved.breakpoints = {} ---@type eve.context.lsp.IBreakpointData[]
      for _, raw_breakpoint in ipairs(data.breakpoints) do
        ---@type eve.context.lsp.IBreakpointData
        local breakpoint = {
          filepath = raw_breakpoint.filepath,
          lnum = raw_breakpoint.lnum,
          condition = raw_breakpoint.condition,
          hit_condition = raw_breakpoint.hit_condition,
          log_message = raw_breakpoint.log_message,
        }
        if is_valid_breakpoint(workspace, breakpoint) then
          table.insert(resolved.breakpoints, breakpoint)
        end
      end
    end
    if type(data.code_lens) == "boolean" then
      resolved.code_lens = data.code_lens
    end
    if type(data.diagnostics_virt_lines) == "boolean" then
      resolved.diagnostics_virt_lines = data.diagnostics_virt_lines
    end
    if type(data.inlay_hints) == "boolean" then
      resolved.inlay_hints = data.inlay_hints
    end
    if type(data.python_debug_host) == "string" then
      resolved.python_debug_host = data.python_debug_host
    end
    if type(data.python_debug_port) == "number" then
      resolved.python_debug_port = data.python_debug_port
    end
    if type(data.python_venv_path) == "string" then
      resolved.python_venv_path = data.python_venv_path
    end
    if type(data.spellcheck) == "boolean" then
      resolved.spellcheck = data.spellcheck
    end
  end
  return resolved
end

---@return eve.context.lsp.data
function M.dump()
  ---@type eve.context.lsp.data
  return {
    breakpoints = M.breakpoints:snapshot(),
    code_lens = M.code_lens:snapshot(),
    diagnostics_virt_lines = M.diagnostics_virt_lines:snapshot(),
    inlay_hints = M.inlay_hints:snapshot(),
    python_debug_host = M.python_debug_host:snapshot(),
    python_debug_port = M.python_debug_port:snapshot(),
    python_venv_path = M.python_venv_path:snapshot(),
    spellcheck = M.spellcheck:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.context.lsp.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.lsp.data

  M.breakpoints:next(data.breakpoints)
  M.code_lens:next(data.code_lens)
  M.diagnostics_virt_lines:next(data.diagnostics_virt_lines)
  M.inlay_hints:next(data.inlay_hints)
  M.python_debug_host:next(data.python_debug_host)
  M.python_debug_port:next(data.python_debug_port)
  M.python_venv_path:next(data.python_venv_path)
  M.spellcheck:next(data.spellcheck)
  return M
end

----------------------------------------------------------------------------------------------------

local data = M.defaults() ---@type eve.context.lsp.data
M.breakpoints = std.Observable.from_value(data.breakpoints)
M.code_lens = std.Observable.from_value(data.code_lens)
M.diagnostics_virt_lines = std.Observable.from_value(data.diagnostics_virt_lines)
M.inlay_hints = std.Observable.from_value(data.inlay_hints)
M.python_debug_host = std.Observable.from_value(data.python_debug_host)
M.python_debug_port = std.Observable.from_value(data.python_debug_port)
M.python_venv_path = std.Observable.from_value(data.python_venv_path)
M.spellcheck = std.Observable.from_value(data.spellcheck)

---@return string|nil
---@return string|nil
function M.get_python_bin_path()
  local venv_path = M.python_venv_path:snapshot() ---@type string|nil
  if venv_path == nil or vim.fn.isdirectory(venv_path) == 0 then
    return nil, nil
  end

  local python_name = std.env.IS_WIN and "python.exe" or "python" ---@type string
  local bin_home_name = std.env.IS_WIN and "Scripts" or "bin" ---@type string
  local bin_home = std.path.join(venv_path, bin_home_name) ---@type string
  local python_path ---@type string

  python_path = std.path.join(venv_path, python_name) ---@type string
  if std.path.is_exist_filepath(python_path) then
    return python_path, bin_home
  end

  python_path = std.path.join(bin_home, python_name) ---@type string
  if std.path.is_exist_filepath(python_path) then
    return python_path, bin_home
  end

  error(string.format("[%s#get_python_bin_path] Cannot resolve the python env path.", __module_name__))
end

---@return nil
function M.refresh_breakpoints()
  local ok, bps = pcall(require, "dap.breakpoints")
  if M == nil or not ok then
    return
  end

  local raw_breakpoints_list = bps.get()
  local breakpoints = {} ---@type eve.context.lsp.IBreakpointData[]
  local workspace = std.path.workspace() ---@type string
  for bufnr, raw_breakpoints in pairs(raw_breakpoints_list) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    for _, raw_breakpoint in ipairs(raw_breakpoints) do
      ---@type eve.context.lsp.IBreakpointData
      local breakpoint = {
        filepath = filepath,
        lnum = raw_breakpoint.line,
        condition = raw_breakpoint.condition,
        hit_condition = raw_breakpoint.hit_condition,
        log_message = raw_breakpoint.log_message,
      }
      if is_valid_breakpoint(workspace, breakpoint) then
        breakpoint.filepath = std.path.relative(workspace, breakpoint.filepath, false) ---@type string
        table.insert(breakpoints, breakpoint)
      end
    end
  end
  M.breakpoints:next(breakpoints)
end

return M
