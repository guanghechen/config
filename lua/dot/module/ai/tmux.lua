local __module_name__ = "dot.module.ai.tmux" ---@type string

local config = require("dot.module.ai.config")
local proc = require("dot.module.ai.proc")

---@class dot.module.ai.tmux
local M = {}

local PANE_FORMAT = table.concat({
  "#{session_id}",
  "#{session_name}",
  "#{window_id}",
  "#{window_name}",
  "#{pane_id}",
  "#{pane_pid}",
  "#{?pane_current_path,#{pane_current_path},#{pane_start_path}}",
}, ":")

---@param cmd                           string[]
---@param opts                          ?{ stdin?: string }
---@return string[]|nil
local function exec(cmd, opts)
  opts = opts or {}
  local result = vim.system(cmd, { text = true, stdin = opts.stdin }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.split(result.stdout or "", "\n", { trimempty = true })
end

---@param line                          string
---@return dot.module.ai.ITmuxPaneInfo|nil
local function parse_pane_format(line)
  local session_id, session_name, window_id, window_name, pane_id, pane_pid, pane_cwd =
    line:match("^(%$%d+):(.-):(@%d+):(.-):(%%.+):(%d+):(.*)")

  if not (session_id and pane_id and pane_pid) then
    return nil
  end

  return {
    session_id = session_id,
    session_name = session_name or "",
    window_id = window_id or "",
    window_name = window_name or "",
    pane_id = pane_id,
    pane_pid = tonumber(pane_pid) or 0,
    pane_cwd = pane_cwd or "",
  }
end

---@param tool_config                   dot.module.ai.IToolConfig
---@param cwd                           string
---@return string
local function build_shell_command(tool_config, cwd)
  local parts = {} ---@type string[]

  for k, v in pairs(tool_config.env()) do
    if v ~= false then
      parts[#parts + 1] = string.format("%s=%s", k, vim.fn.shellescape(tostring(v)))
    end
  end

  parts[#parts + 1] = vim.fn.shellescape(tool_config.cmd)
  for _, arg in ipairs(tool_config.args(cwd)) do
    parts[#parts + 1] = vim.fn.shellescape(arg)
  end

  return table.concat(parts, " ")
end

----------------------------------------------------------------------------------------------------
--- Basic operations
----------------------------------------------------------------------------------------------------

---@return boolean
function M.is_available()
  return vim.fn.executable("tmux") == 1
end

---@return boolean
function M.is_inside_tmux()
  return vim.env.TMUX ~= nil
end

---@class dot.module.ai.ITmuxCurrentInfo
---@field public session_name           string
---@field public window_name            string

---@return dot.module.ai.ITmuxCurrentInfo|nil
function M.get_current_info()
  if not M.is_inside_tmux() then
    return nil
  end

  local lines = exec({ "tmux", "display-message", "-p", "#{session_name}:#{window_name}" })
  if not lines or #lines == 0 then
    return nil
  end

  local session_name, window_name = lines[1]:match("^(.-):(.*)$")
  if session_name and window_name then
    return { session_name = session_name, window_name = window_name }
  end
  return nil
end

----------------------------------------------------------------------------------------------------
--- Naming conventions
----------------------------------------------------------------------------------------------------

---@param agent                         dot.module.ai.AgentName
---@param cwd                           string
---@return string
function M.get_session_name(agent, cwd)
  local hash = yoz.fn.md5(cwd)
  return string.format("%s-%s", agent, hash)
end

---@param session_name                  string
---@return boolean
function M.is_agent_session(session_name)
  for _, agent in ipairs(config.agents) do
    local pattern = "^" .. agent .. "%-[0-9a-f]+$"
    if session_name:match(pattern) and #session_name == #agent + 33 then
      return true
    end
  end
  return false
end

----------------------------------------------------------------------------------------------------
--- Pane operations
----------------------------------------------------------------------------------------------------

---@return dot.module.ai.ITmuxPaneInfo[]
function M.list_panes()
  local lines = exec({ "tmux", "list-panes", "-a", "-F", PANE_FORMAT })
  if not lines then
    return {}
  end

  local panes = {} ---@type dot.module.ai.ITmuxPaneInfo[]
  for _, line in ipairs(lines) do
    local pane = parse_pane_format(line)
    if pane then
      panes[#panes + 1] = pane
    end
  end
  return panes
end

---@param pane_id                       string
---@return dot.module.ai.ITmuxPaneInfo|nil
function M.get_pane(pane_id)
  for _, pane in ipairs(M.list_panes()) do
    if pane.pane_id == pane_id then
      return pane
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------
--- Agent detection
----------------------------------------------------------------------------------------------------

---@return dot.module.ai.ISource[]
function M.find_running_agents()
  if not M.is_available() then
    return {}
  end

  local panes = M.list_panes()
  local procs = proc.Procs.new()
  local sources = {} ---@type dot.module.ai.ISource[]

  for _, pane in ipairs(panes) do
    local agent = proc.detect_agent(procs, pane.pane_pid)
    if agent then
      sources[#sources + 1] = {
        id = string.format("tmux:%s", pane.pane_id),
        type = "tmux",
        agent = agent,
        cwd = pane.pane_cwd,
        external = not M.is_agent_session(pane.session_name),
        tmux_pane = pane,
      }
    end
  end

  return sources
end

---@param agent                         dot.module.ai.AgentName
---@param cwd                           string
---@return dot.module.ai.ITmuxPaneInfo|nil
function M.find_existing_agent_pane(agent, cwd)
  local session_name = M.get_session_name(agent, cwd)
  local procs = proc.Procs.new()

  for _, pane in ipairs(M.list_panes()) do
    if pane.session_name == session_name then
      if proc.is_running_agent(procs, pane.pane_pid, agent) then
        return pane
      end
    end
  end

  return nil
end

----------------------------------------------------------------------------------------------------
--- Agent pane creation
----------------------------------------------------------------------------------------------------

---@param agent                         dot.module.ai.AgentName
---@param cwd                           string
---@return dot.module.ai.ITmuxPaneInfo|nil
function M.create_agent_pane(agent, cwd)
  local tool_config = config.tools[agent]
  if not tool_config then
    stl.reporter.error({
      from = __module_name__,
      subject = "create_agent_pane",
      message = string.format("Unknown agent: %s", agent),
    })
    return nil
  end

  local session_name = M.get_session_name(agent, cwd)
  local shell_cmd = build_shell_command(tool_config, cwd)

  local result = exec({
    "tmux",
    "new-session",
    "-d",
    "-P",
    "-F",
    PANE_FORMAT,
    "-s",
    session_name,
    "-n",
    agent,
    "-c",
    cwd,
    shell_cmd,
  })

  if not result or #result == 0 then
    stl.reporter.error({
      from = __module_name__,
      subject = "create_agent_pane",
      message = string.format("Failed to create tmux session for %s.", agent),
    })
    return nil
  end

  local pane = parse_pane_format(result[1])
  if not pane then
    stl.reporter.error({
      from = __module_name__,
      subject = "create_agent_pane",
      message = "Failed to parse tmux pane info.",
    })
    return nil
  end

  return pane
end

----------------------------------------------------------------------------------------------------
--- Text sending
----------------------------------------------------------------------------------------------------

---@param pane_id                       string
---@return boolean
function M.send_escape_i(pane_id)
  return exec({ "tmux", "send-keys", "-t", pane_id, "Escape", "i" }) ~= nil
end

---@param pane_id                       string
---@param text                          string
---@return boolean
function M.send_text(pane_id, text)
  local buffer_name = "dot-ai-" .. pane_id
  if not exec({ "tmux", "load-buffer", "-b", buffer_name, "-" }, { stdin = text }) then
    return false
  end
  return exec({ "tmux", "paste-buffer", "-b", buffer_name, "-d", "-r", "-t", pane_id }) ~= nil
end

---@param pane_id                       string
---@return boolean
function M.send_enter(pane_id)
  return exec({ "tmux", "send-keys", "-t", pane_id, "Enter" }) ~= nil
end

return M
