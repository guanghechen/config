---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.context.workspace.lsp" ---@type string

---@class dot.context.lsp.IBreakpointData
---@field public filepath               string
---@field public lnum                   integer
---@field public condition              ?string
---@field public hit_condition          ?string
---@field public log_message            ?string

---@class dot.context.lsp.data
---@field public breakpoints            dot.context.lsp.IBreakpointData[]
---@field public code_lens              boolean
---@field public diagnostics_virt_lines boolean
---@field public inlay_hints            boolean
---@field public python_venv_path       string|nil
---@field public spellcheck             boolean

---@class dot.context.lsp.state
---@field public breakpoints            stl.c.Observable
---@field public code_lens              stl.c.Observable
---@field public diagnostics_virt_lines stl.c.Observable
---@field public inlay_hints            stl.c.Observable
---@field public python_venv_path       stl.c.Observable
---@field public spellcheck             stl.c.Observable
---
---@field public get_python_bin_path    fun(): string|nil, string|nil
---@field public refresh_breakpoints    fun(): nil

---@class dot.context.lsp : dot.context.lsp.state
---@field public defaults               fun(): dot.context.lsp.data
---@field public dump                   fun(): dot.context.lsp.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.lsp.data
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
    breakpoint.filepath = dot.path.resolve(workspace, breakpoint.filepath) ---@type string
    return vim.fn.filereadable(breakpoint.filepath) == 1
  end
  return false
end

---@return dot.context.lsp.data
function M.defaults()
  local is_git_repo = dot.path.is_git_repo() ---@type boolean
  local is_repo_personal = dot.path.is_repo_personal_public() ---@type boolean

  ---@type dot.context.lsp.data
  return {
    breakpoints = {},
    code_lens = false,
    diagnostics_virt_lines = true,
    inlay_hints = is_git_repo,
    python_venv_path = nil,
    spellcheck = is_repo_personal,
  }
end

---@param data                          any
---@return dot.context.lsp.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.lsp.data
  local workspace = dot.path.workspace() ---@type string
  if type(data) == "table" then
    if type(data.breakpoints) == "table" then
      resolved.breakpoints = {} ---@type dot.context.lsp.IBreakpointData[]
      for _, raw_breakpoint in ipairs(data.breakpoints) do
        ---@type dot.context.lsp.IBreakpointData
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
    if type(data.python_venv_path) == "string" then
      resolved.python_venv_path = data.python_venv_path
    end
    if type(data.spellcheck) == "boolean" then
      resolved.spellcheck = data.spellcheck
    end
  end
  return resolved
end

---@return dot.context.lsp.data
function M.dump()
  ---@type dot.context.lsp.data
  return {
    breakpoints = M.breakpoints:snapshot(),
    code_lens = M.code_lens:snapshot(),
    diagnostics_virt_lines = M.diagnostics_virt_lines:snapshot(),
    inlay_hints = M.inlay_hints:snapshot(),
    python_venv_path = M.python_venv_path:snapshot(),
    spellcheck = M.spellcheck:snapshot(),
  }
end

---@param raw_data                      any
---@return dot.context.lsp.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.lsp.data

  M.breakpoints:next(data.breakpoints)
  M.code_lens:next(data.code_lens)
  M.diagnostics_virt_lines:next(data.diagnostics_virt_lines)
  M.inlay_hints:next(data.inlay_hints)
  M.python_venv_path:next(data.python_venv_path)
  M.spellcheck:next(data.spellcheck)
  return M
end

----------------------------------------------------------------------------------------------------

local data = M.defaults() ---@type dot.context.lsp.data
M.breakpoints = stl.c.Observable.from_value(data.breakpoints)
M.code_lens = stl.c.Observable.from_value(data.code_lens)
M.diagnostics_virt_lines = stl.c.Observable.from_value(data.diagnostics_virt_lines)
M.inlay_hints = stl.c.Observable.from_value(data.inlay_hints)
M.python_venv_path = stl.c.Observable.from_value(data.python_venv_path)
M.spellcheck = stl.c.Observable.from_value(data.spellcheck)

---@return string|nil
---@return string|nil
function M.get_python_bin_path()
  local venv_path = M.python_venv_path:snapshot() ---@type string|nil
  if venv_path == nil or vim.fn.isdirectory(venv_path) == 0 then
    return nil, nil
  end

  local python_name = stl.env.IS_WIN and "python.exe" or "python" ---@type string
  local bin_home_name = stl.env.IS_WIN and "Scripts" or "bin" ---@type string
  local bin_home = dot.path.join(venv_path, bin_home_name) ---@type string
  local python_path ---@type string

  python_path = dot.path.join(venv_path, python_name) ---@type string
  if yoz.path.is_exist_file(python_path) then
    return python_path, bin_home
  end

  python_path = dot.path.join(bin_home, python_name) ---@type string
  if yoz.path.is_exist_file(python_path) then
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
  local breakpoints = {} ---@type dot.context.lsp.IBreakpointData[]
  local workspace = dot.path.workspace() ---@type string
  for bufnr, raw_breakpoints in pairs(raw_breakpoints_list) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    for _, raw_breakpoint in ipairs(raw_breakpoints) do
      ---@type dot.context.lsp.IBreakpointData
      local breakpoint = {
        filepath = filepath,
        lnum = raw_breakpoint.line,
        condition = raw_breakpoint.condition,
        hit_condition = raw_breakpoint.hit_condition,
        log_message = raw_breakpoint.log_message,
      }
      if is_valid_breakpoint(workspace, breakpoint) then
        breakpoint.filepath = dot.path.relative(workspace, breakpoint.filepath) ---@type string
        table.insert(breakpoints, breakpoint)
      end
    end
  end
  M.breakpoints:next(breakpoints)
end

return M
