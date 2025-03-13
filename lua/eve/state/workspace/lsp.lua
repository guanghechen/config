---@class eve.state.lsp.IBreakpointData
---@field public filepath               string
---@field public lnum                   integer
---@field public condition              ?string
---@field public hit_condition          ?string
---@field public log_message            ?string

---@class eve.state.lsp.data
---@field public breakpoints            eve.state.lsp.IBreakpointData[]
---@field public code_lens              boolean
---@field public inlay_hints            boolean
---@field public python_debug_host      string
---@field public python_debug_port      integer
---@field public python_venv_path       string|nil
---@field public spellcheck             boolean

---@class eve.state.lsp.state
---@field public breakpoints            eve.collection.IObservable -- eve.state.lsp.IBreakpointData[]>
---@field public code_lens              eve.collection.IObservable -- boolean>
---@field public inlay_hints            eve.collection.IObservable -- boolean>
---@field public python_debug_host      eve.collection.IObservable -- string>
---@field public python_debug_port      eve.collection.IObservable -- integer>
---@field public python_venv_path       eve.collection.IObservable -- string|nil>
---@field public spellcheck             eve.collection.IObservable -- boolean>
---
---@field public get_python_bin_path    fun(): string|nil, string|nil
---@field public refresh_breakpoints    fun(): nil

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
    breakpoint.filepath = eve.std.path.resolve(workspace, breakpoint.filepath) ---@type string
    return vim.fn.filereadable(breakpoint.filepath) == 1
  end
  return false
end

---@class eve.state.lsp
---@field public defaults               fun(): eve.state.lsp.data
---@field public dump                   fun(): eve.state.lsp.data
---@field public load                   fun(data: unknown): eve.state.lsp.state
---@field public normalize              fun(data: unknown): eve.state.lsp.data
local M = {}

local _state = nil ---@type eve.state.lsp.state | nil

---@return eve.state.lsp.data
function M.defaults()
  local is_git_repo = eve.std.path.is_repo_git() ---@type boolean
  local is_repo_personal = eve.std.path.is_repo_personal_public() ---@type boolean

  ---@type eve.state.lsp.data
  return {
    breakpoints = {},
    code_lens = is_git_repo,
    inlay_hints = is_git_repo,
    python_debug_host = "127.0.0.1",
    python_debug_port = 9527,
    python_venv_path = nil,
    spellcheck = is_repo_personal,
  }
end

---@param data                        any
---@return eve.state.lsp.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.lsp.data
  local workspace = eve.std.path.workspace() ---@type string
  if type(data) == "table" then
    if type(data.breakpoints) == "table" then
      resolved.breakpoints = {} ---@type eve.state.lsp.IBreakpointData[]
      for _, raw_breakpoint in ipairs(data.breakpoints) do
        ---@type eve.state.lsp.IBreakpointData
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

---@return eve.state.lsp.data
function M.dump()
  if _state == nil then
    return M.defaults()
  end

  ---@type eve.state.lsp.data
  return {
    breakpoints = _state.breakpoints:snapshot(),
    code_lens = _state.code_lens:snapshot(),
    inlay_hints = _state.inlay_hints:snapshot(),
    python_debug_host = _state.python_debug_host:snapshot(),
    python_debug_port = _state.python_debug_port:snapshot(),
    python_venv_path = _state.python_venv_path:snapshot(),
    spellcheck = _state.spellcheck:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.lsp.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.lsp.data

  if _state == nil then
    local python_venv_path = eve.c.Observable.from_value(data.python_venv_path)

    ---@type eve.state.lsp.state
    _state = {
      breakpoints = eve.c.Observable.from_value(data.breakpoints),
      code_lens = eve.c.Observable.from_value(data.code_lens),
      inlay_hints = eve.c.Observable.from_value(data.inlay_hints),
      python_debug_host = eve.c.Observable.from_value(data.python_debug_host),
      python_debug_port = eve.c.Observable.from_value(data.python_debug_port),
      python_venv_path = python_venv_path,
      spellcheck = eve.c.Observable.from_value(data.spellcheck),

      ---@return string|nil
      get_python_bin_path = function()
        local venv_path = python_venv_path:snapshot() ---@type string|nil
        if venv_path == nil or vim.fn.isdirectory(venv_path) == 0 then
          return nil, nil
        end

        local python_name = eve.std.env.IS_WIN and "python.exe" or "python" ---@type string
        local python_parent_path = eve.std.env.IS_WIN and "Scripts" or "bin" ---@type string

        local bin_path = eve.std.path.join(venv_path, python_parent_path) ---@type string
        local python_path = eve.std.path.join(bin_path, python_name) ---@type string
        return python_path, bin_path
      end,

      ---@return nil
      refresh_breakpoints = function()
        local ok, bps = pcall(require, "dap.breakpoints")
        if _state == nil or not ok then
          return
        end

        local raw_breakpoints_list = bps.get()
        local breakpoints = {} ---@type eve.state.lsp.IBreakpointData[]
        local workspace = eve.std.path.workspace() ---@type string
        for bufnr, raw_breakpoints in pairs(raw_breakpoints_list) do
          local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
          for _, raw_breakpoint in ipairs(raw_breakpoints) do
            ---@type eve.state.lsp.IBreakpointData
            local breakpoint = {
              filepath = filepath,
              lnum = raw_breakpoint.line,
              condition = raw_breakpoint.condition,
              hit_condition = raw_breakpoint.hit_condition,
              log_message = raw_breakpoint.log_message,
            }
            if is_valid_breakpoint(workspace, breakpoint) then
              breakpoint.filepath = eve.std.path.relative(workspace, breakpoint.filepath, false) ---@type string
              table.insert(breakpoints, breakpoint)
            end
          end
        end
        _state.breakpoints:next(breakpoints)
      end,
    }
    return _state
  end

  _state.breakpoints:next(data.breakpoints)
  _state.code_lens:next(data.code_lens)
  _state.inlay_hints:next(data.inlay_hints)
  _state.python_debug_host:next(data.python_debug_host)
  _state.python_debug_port:next(data.python_debug_port)
  _state.python_venv_path:next(data.python_venv_path)
  _state.spellcheck:next(data.spellcheck)
  return _state
end

return M
