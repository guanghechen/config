local __module_name__ = "era.m.ai.action" ---@type string

local S = era.m.ai

---@class era.m.ai.action
local M = {}

---@param agent                         era.m.ai.AgentName
---@return boolean
function M.is_tool_installed(agent)
  local tool = S.config.tools[agent]
  return tool ~= nil and vim.fn.executable(tool.cmd) == 1
end

---@return era.m.ai.ISelectItem[]
function M.collect_items()
  local items = {} ---@type era.m.ai.ISelectItem[]
  local seen_ids = {} ---@type table<string, boolean>
  local cwd = dot.path.cwd()
  local has_agent_pane = {} ---@type table<era.m.ai.AgentName, boolean>

  for _, source in ipairs(S.state.get_attached()) do
    seen_ids[source.id] = true
    items[#items + 1] = {
      type = "running",
      agent = source.agent,
      source = source,
      installed = true,
    }
  end

  if S.tmux.is_available() then
    for _, source in ipairs(S.tmux.find_running_agents()) do
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
      local agent_session = S.tmux.get_session_name(source.agent, cwd)
      if pane and pane.session_name == agent_session then
        has_agent_pane[source.agent] = true
      end
    end
  end

  for _, agent in ipairs(S.config.agents) do
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

---@param source                        era.m.ai.ISource
---@return string
function M.get_source_identifier(source)
  local pane = source.tmux_pane
  if pane then
    return string.format("%s:%s.%s", pane.session_name, pane.window_name, pane.pane_id:gsub("^%%", ""))
  end
  return source.id
end

---@param item                          era.m.ai.ISelectItem
---@return nil
function M.handle_selection(item)
  if item.type == "running" and item.source then
    if S.state.is_attached(item.source) then
      S.state.detach(item.source.id)
    else
      M.attach_to_source(item.source)
    end
    return
  end

  if item.type == "new" then
    if not item.installed then
      local tool = S.config.tools[item.agent]
      stl.reporter.warn({
        from = __module_name__,
        group = "ai",
        subject = "handle_selection",
        message = string.format("%s is not installed.", S.config.agent_labels[item.agent]),
        details = { url = tool and tool.url or nil },
      })
      return
    end
    M.create_and_attach(item.agent, dot.path.cwd())
  end
end

---@param source                        era.m.ai.ISource
---@return nil
function M.attach_to_source(source)
  S.state.attach(source)

  local pane = source.tmux_pane
  if source.type ~= "tmux" or not pane then
    return
  end

  if source.external then
    stl.reporter.info({
      from = __module_name__,
      group = "ai",
      subject = "attach_to_source",
      message = string.format(
        "Attached to external %s pane (messages will be sent via tmux).",
        S.config.agent_labels[source.agent]
      ),
    })
    return
  end

  local target = pane.session_name
  S.term.open({
    uuid = string.format("ai:%s:%s", source.agent, pane.pane_id),
    agent = source.agent,
    cmd = { "env", "-u", "TMUX", "tmux", "attach-session", "-t", target },
    cwd = source.cwd,
  })
end

---@param agent                         era.m.ai.AgentName
---@param cwd                           string
---@return nil
function M.create_and_attach(agent, cwd)
  if S.tmux.is_available() then
    M.__create_and_attach_tmux__(agent, cwd)
  else
    M.__create_and_attach_native__(agent, cwd)
  end
end

---@param text                          string
---@param submit                        boolean
---@return nil
function M.send_to_attached(text, submit)
  local attached = S.state.get_attached()

  if #attached == 0 then
    S.picker.show_attach({
      on_select = function(choice)
        M.handle_selection(choice)
        vim.schedule(function()
          local new_attached = S.state.get_attached()
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

  S.picker.show_send_target(attached, function(choices)
    M.__send_to_sources__(choices, text, submit)
  end)
end

---@param source                        era.m.ai.ISource
---@param text                          string
---@param submit                        boolean
---@return boolean
function M.send_to_source(source, text, submit)
  local payload = submit and text or (vim.trim(text) .. " ")

  if source.type == "tmux" and source.tmux_pane then
    local tool = S.config.tools[source.agent]
    local pane_id = source.tmux_pane.pane_id
    if tool and tool.vim_mode then
      S.tmux.send_escape_i(pane_id)
      vim.defer_fn(function()
        S.tmux.send_text(pane_id, payload)
        if submit then
          S.tmux.send_enter(pane_id)
        end
      end, 50)
      return true
    end

    if not S.tmux.send_text(pane_id, payload) then
      return false
    end
    if submit then
      return S.tmux.send_enter(pane_id)
    end
    return true
  elseif source.type == "terminal" then
    return S.term.send(source.id, payload, submit)
  end
  return false
end

---@return nil
function M.show_attach_picker()
  S.picker.show_attach({
    on_select = M.handle_selection,
    on_toggle = M.handle_selection,
  })
end

---@return nil
function M.show_detach_picker()
  local attached = S.state.get_attached()

  if #attached == 0 then
    stl.reporter.info({
      from = __module_name__,
      group = "ai",
      subject = "show_detach_picker",
      message = "No agents attached.",
    })
    return
  end

  if #attached == 1 then
    S.state.detach(attached[1].id)
    return
  end

  S.picker.show_detach(attached, function(choice)
    S.state.detach(choice.id)
  end)
end

---@return nil
function M.show_prompt_picker()
  S.picker.show_prompt(function(choice, result)
    M.send_to_attached(result.text, choice.submit)
  end)
end

----------------------------------------------------------------------------------------------------
-- Buffer/Selection Operations
----------------------------------------------------------------------------------------------------

---@return nil
function M.edit()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if vim.bo[bufnr].buftype ~= "" then
    stl.reporter.warn({
      from = __module_name__,
      group = "ai",
      subject = "edit",
      message = "Cannot edit non-standard buffer",
    })
    return
  end

  local filepath = vim.api.nvim_buf_get_name(0) ---@type string
  if filepath == "" then
    stl.reporter.warn({
      from = __module_name__,
      group = "ai",
      subject = "edit",
      message = "Cannot edit unnamed buffer",
    })
    return
  end

  local location ---@type string|nil
  local location_err ---@type string|nil
  local lnum_start, col_start, lnum_end, col_end = stl.nvim.buf.retrieve_visual_range()
  local content ---@type string

  if
    lnum_start == nil
    or col_start == nil
    or lnum_end == nil
    or col_end == nil
    or ((lnum_start == lnum_end) and (col_start == col_end))
  then
    location, location_err = dot.uri.file_location({
      filepath = filepath,
    })
    content = location or filepath
  else
    location, location_err = dot.uri.file_location({
      filepath = filepath,
      start_lnum = lnum_start,
      start_col = col_start,
      end_lnum = lnum_end,
      end_col = col_end,
    })
    local lines = stl.nvim.buf.retrieve_visual_range_lines(bufnr, lnum_start, col_start, lnum_end, col_end)
    content = table.concat(lines, "\n")
  end

  if location == nil then
    stl.reporter.warn({
      from = __module_name__,
      group = "ai",
      subject = "edit",
      message = "Failed to format selection location.",
      details = {
        error = location_err,
        filepath = filepath,
        start_lnum = lnum_start,
        start_col = col_start,
        end_lnum = lnum_end,
        end_col = col_end,
      },
    })
    location = string.format("@%s", filepath)
  end

  vim.schedule(function()
    vim.fn.setreg('"', content)
  end)
  dot.command.definitions.notepad.append_content:execute("\n" .. location .. " ")
end

---@return nil
function M.send_buffer()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local text = table.concat(lines, "\n") ---@type string
  M.send_to_attached(text, false)
end

---@return nil
function M.submit_to()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local text = stl.nvim.buf.retrieve_split_block(winnr) ---@type string
  S.picker.show_submit_to(function(sources)
    M.__send_to_sources__(sources, text, true)
  end)
end

---@return nil
function M.send_file()
  local filepath = vim.api.nvim_buf_get_name(0) ---@type string
  if filepath == "" then
    stl.reporter.warn({
      from = __module_name__,
      group = "ai",
      subject = "send_file",
      message = "Cannot send: buffer has no file path.",
    })
    return
  end

  local location, _ = dot.uri.file_location({ filepath = filepath })
  if location then
    M.send_to_attached(location, false)
  end
end

---@return nil
function M.send_selection()
  local text = stl.nvim.buf.retrieve_selected_text() or "" ---@type string
  if #text > 0 then
    M.send_to_attached(text, false)
  end
end

---@return nil
function M.submit_buffer()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local text = stl.nvim.buf.retrieve_split_block(winnr) ---@type string
  M.send_to_attached(text, true)
end

---@return nil
function M.submit_selection()
  local text = stl.nvim.buf.retrieve_selected_text() or "" ---@type string
  if #text > 0 then
    M.send_to_attached(text, true)
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@param agent                         era.m.ai.AgentName
---@param cwd                           string
---@return nil
function M.__create_and_attach_native__(agent, cwd)
  local tool = S.config.tools[agent]
  if not tool then
    return
  end

  local cmd = { tool.cmd, unpack(tool.args(cwd)) }

  local termmeta = S.term.open({
    uuid = "",
    agent = agent,
    cmd = cmd,
    cwd = cwd,
    env = tool.env(),
  })

  ---@type era.m.ai.ISource
  local source = {
    id = termmeta.uuid,
    type = "terminal",
    agent = agent,
    cwd = cwd,
    external = false,
    tmux_pane = nil,
  }

  S.state.attach(source)
end

---@protected
---@param agent                         era.m.ai.AgentName
---@param cwd                           string
---@return nil
function M.__create_and_attach_tmux__(agent, cwd)
  local pane = S.tmux.find_existing_agent_pane(agent, cwd) or S.tmux.create_agent_pane(agent, cwd)

  if not pane then
    stl.reporter.error({
      from = __module_name__,
      group = "ai",
      subject = "create_and_attach",
      message = string.format("Failed to create %s pane.", S.config.agent_labels[agent]),
    })
    return
  end

  ---@type era.m.ai.ISource
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
---@param sources                       era.m.ai.ISource[]
---@param text                          string
---@param submit                        boolean
---@return nil
function M.__send_to_sources__(sources, text, submit)
  local succeeded = {} ---@type string[]
  local failed = {} ---@type string[]

  for _, source in ipairs(sources) do
    local agent_label = S.config.agent_labels[source.agent] or source.agent
    local ok = M.send_to_source(source, text, submit)
    if ok then
      succeeded[#succeeded + 1] = agent_label
    else
      failed[#failed + 1] = agent_label
    end
  end

  if #succeeded > 0 then
    stl.reporter.info({
      from = __module_name__,
      group = "ai",
      subject = "Message Sent",
      message = string.format("Sent to %s.", table.concat(succeeded, ", ")),
    })
  end

  if #failed > 0 then
    stl.reporter.error({
      from = __module_name__,
      group = "ai",
      subject = "Send Failed",
      message = string.format("Failed to send to %s.", table.concat(failed, ", ")),
    })
  end
end

return M
