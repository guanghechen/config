local __module_name__ = "dot.module.ai.action" ---@type string

local config = require("dot.module.ai.config")
local state = require("dot.module.ai.state")
local term = require("dot.module.ai.term")
local tmux = require("dot.module.ai.tmux")

---@class dot.module.ai.action
local M = {}

---@param agent                         dot.module.ai.AgentName
---@return boolean
function M.is_tool_installed(agent)
  local tool = config.tools[agent]
  return tool ~= nil and vim.fn.executable(tool.cmd) == 1
end

---@return dot.module.ai.ISelectItem[]
function M.collect_items()
  local items = {} ---@type dot.module.ai.ISelectItem[]
  local seen_ids = {} ---@type table<string, boolean>
  local cwd = dot.path.cwd()
  local has_agent_pane = {} ---@type table<dot.module.ai.AgentName, boolean>

  for _, source in ipairs(state.get_attached()) do
    seen_ids[source.id] = true
    items[#items + 1] = {
      type = "running",
      agent = source.agent,
      source = source,
      installed = true,
    }
  end

  if tmux.is_available() then
    for _, source in ipairs(tmux.find_running_agents()) do
      if not seen_ids[source.id] then
        seen_ids[source.id] = true
        items[#items + 1] = {
          type = "running",
          agent = source.agent,
          source = source,
          installed = true,
        }
      end
      local pane = source.tmux_pane
      local agent_session = tmux.get_session_name(source.agent, cwd)
      if pane and pane.session_name == agent_session then
        has_agent_pane[source.agent] = true
      end
    end
  end

  for _, agent in ipairs(config.agents) do
    if not has_agent_pane[agent] then
      items[#items + 1] = {
        type = "new",
        agent = agent,
        source = nil,
        installed = M.is_tool_installed(agent),
      }
    end
  end

  return items
end

---@param source                        dot.module.ai.ISource
---@return string
function M.get_source_identifier(source)
  local pane = source.tmux_pane
  if pane then
    return string.format("%s:%s.%s", pane.session_name, pane.window_name, pane.pane_id:gsub("^%%", ""))
  end
  return source.id
end

---@param item                          dot.module.ai.ISelectItem
---@return nil
function M.handle_selection(item)
  if item.type == "running" and item.source then
    if state.is_attached(item.source) then
      state.detach(item.source.id)
    else
      M.attach_to_source(item.source)
    end
    return
  end

  if item.type == "new" then
    if not item.installed then
      local tool = config.tools[item.agent]
      ark.reporter.warn({
        from = __module_name__,
        subject = "handle_selection",
        message = string.format("%s is not installed.", config.agent_labels[item.agent]),
        details = { url = tool and tool.url or nil },
      })
      return
    end
    M.create_and_attach(item.agent, dot.path.cwd())
  end
end

---@param source                        dot.module.ai.ISource
---@return nil
function M.attach_to_source(source)
  state.attach(source)

  local pane = source.tmux_pane
  if source.type ~= "tmux" or not pane then
    return
  end

  if source.external then
    ark.reporter.info({
      from = __module_name__,
      subject = "attach_to_source",
      message = string.format(
        "Attached to external %s pane (messages will be sent via tmux).",
        config.agent_labels[source.agent]
      ),
    })
    return
  end

  local target = pane.session_name
  term.open({
    uuid = string.format("ai:%s:%s", source.agent, pane.pane_id),
    agent = source.agent,
    cmd = { "env", "-u", "TMUX", "tmux", "attach-session", "-t", target },
    cwd = source.cwd,
  })
end

---@param agent                         dot.module.ai.AgentName
---@param cwd                           string
---@return nil
function M.create_and_attach(agent, cwd)
  if tmux.is_available() then
    M.__create_and_attach_tmux__(agent, cwd)
  else
    M.__create_and_attach_native__(agent, cwd)
  end
end

---@param text                          string
---@param submit                        boolean
---@return nil
function M.send_to_attached(text, submit)
  local picker = require("dot.module.ai.picker")
  local attached = state.get_attached()

  if #attached == 0 then
    picker.show_attach({
      on_select = function(choice)
        M.handle_selection(choice)
        vim.schedule(function()
          local new_attached = state.get_attached()
          if #new_attached > 0 then
            M.__send_to_sources__({ new_attached[#new_attached] }, text, submit)
          end
        end)
      end,
    })
    return
  end

  if #attached == 1 then
    M.__send_to_sources__({ attached[1] }, text, submit)
    return
  end

  picker.show_send_target(attached, function(choices)
    M.__send_to_sources__(choices, text, submit)
  end)
end

---@param source                        dot.module.ai.IAttachedSource
---@param text                          string
---@param submit                        boolean
---@return boolean
function M.send_to_source(source, text, submit)
  local payload = submit and text or (vim.trim(text) .. " ")

  if source.type == "tmux" and source.tmux_pane then
    local tool = config.tools[source.agent]
    local pane_id = source.tmux_pane.pane_id
    if tool and tool.vim_mode then
      tmux.send_escape_i(pane_id)
      vim.defer_fn(function()
        tmux.send_text(pane_id, payload)
        if submit then
          tmux.send_enter(pane_id)
        end
      end, 50)
      return true
    end

    if not tmux.send_text(pane_id, payload) then
      return false
    end
    if submit then
      return tmux.send_enter(pane_id)
    end
    return true
  elseif source.type == "terminal" then
    return term.send(source.id, payload, submit)
  end
  return false
end

---@return nil
function M.show_attach_picker()
  local picker = require("dot.module.ai.picker")
  picker.show_attach({
    on_select = M.handle_selection,
    on_toggle = M.handle_selection,
  })
end

---@return nil
function M.show_detach_picker()
  local attached = state.get_attached()

  if #attached == 0 then
    ark.reporter.info({
      from = __module_name__,
      subject = "show_detach_picker",
      message = "No agents attached.",
    })
    return
  end

  if #attached == 1 then
    state.detach(attached[1].id)
    return
  end

  local picker = require("dot.module.ai.picker")
  picker.show_detach(attached, function(choice)
    state.detach(choice.id)
  end)
end

---@return nil
function M.show_prompt_picker()
  local picker = require("dot.module.ai.picker")

  picker.show_prompt(function(choice, result)
    M.send_to_attached(result.text, choice.submit)
  end)
end

----------------------------------------------------------------------------------------------------

---@protected
---@param agent                         dot.module.ai.AgentName
---@param cwd                           string
---@return nil
function M.__create_and_attach_native__(agent, cwd)
  local tool = config.tools[agent]
  if not tool then
    return
  end

  local cmd = { tool.cmd, unpack(tool.args(cwd)) }

  local termmeta = term.open({
    uuid = "",
    agent = agent,
    cmd = cmd,
    cwd = cwd,
    env = tool.env(),
  })

  ---@type dot.module.ai.ISource
  local source = {
    id = termmeta.uuid,
    type = "terminal",
    agent = agent,
    cwd = cwd,
    external = false,
    tmux_pane = nil,
  }

  state.attach(source)
end

---@protected
---@param agent                         dot.module.ai.AgentName
---@param cwd                           string
---@return nil
function M.__create_and_attach_tmux__(agent, cwd)
  local pane = tmux.find_existing_agent_pane(agent, cwd) or tmux.create_agent_pane(agent, cwd)

  if not pane then
    ark.reporter.error({
      from = __module_name__,
      subject = "create_and_attach",
      message = string.format("Failed to create %s pane.", config.agent_labels[agent]),
    })
    return
  end

  ---@type dot.module.ai.ISource
  local source = {
    id = string.format("tmux:%s", pane.pane_id),
    type = "tmux",
    agent = agent,
    cwd = cwd,
    external = false,
    tmux_pane = pane,
  }
  M.attach_to_source(source)
end

---@protected
---@param sources                       dot.module.ai.IAttachedSource[]
---@param text                          string
---@param submit                        boolean
---@return nil
function M.__send_to_sources__(sources, text, submit)
  local succeeded = {} ---@type string[]
  local failed = {} ---@type string[]

  for _, source in ipairs(sources) do
    local agent_label = config.agent_labels[source.agent] or source.agent
    local ok = M.send_to_source(source, text, submit)
    if ok then
      succeeded[#succeeded + 1] = agent_label
    else
      failed[#failed + 1] = agent_label
    end
  end

  if #succeeded > 0 then
    ark.reporter.info({
      from = __module_name__,
      subject = "Message Sent",
      message = string.format("Sent to %s.", table.concat(succeeded, ", ")),
    })
  end

  if #failed > 0 then
    ark.reporter.error({
      from = __module_name__,
      subject = "Send Failed",
      message = string.format("Failed to send to %s.", table.concat(failed, ", ")),
    })
  end
end

return M
