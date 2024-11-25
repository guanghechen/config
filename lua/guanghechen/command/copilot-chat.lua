if not eve.context.state.flight.copilot:snapshot() then
  return
end

local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

---@return boolean
local function detect_if_copilot_chat_is_open()
  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype == eve.constants.FT_COPILOT_CHAT then
      return true
    end
  end
  return false
end

local widget_status = "closed" ---@type t.eve.e.WidgetStatus

---@type t.eve.ux.IWidget
local widget
widget = {
  statusline_items = nil,
  status = function()
    return widget_status
  end,
  hide = function()
    eve.debug.log("CopilotChat hidden")
    widget_status = "hidden"
    require("CopilotChat").close()
  end,
  resize = function()
    if detect_if_copilot_chat_is_open() then
      require("CopilotChat").close()
      require("CopilotChat").open()
    end
  end,
  show = function()
    eve.debug.log("CopilotChat show")
    widget_status = "visible"
    eve.globals.widgets.push(widget)
    require("CopilotChat").open()
  end,
}

eve.commander
  .register({
    uuid = uuids.copilot_chat_prompt,
    desc = "copilot chat: prompt actions",
    action = function()
      local actions = require("CopilotChat.actions")
      local prompt_actions = actions["prompt_actions"]()
      if not prompt_actions then
        eve.reporter.warn({
          from = "guanghechen.plugins.CopilotChat",
          subject = "pick",
          message = "No prompt found on the current line",
        })
        return
      end

      fml.fn.select({
        title = prompt_actions.prompt,
        dimension = {
          width = 40,
          height = 20,
          width_preview = 80,
        },
        preview_flag_wrap = true,
        fetch_items = function()
          local select_items = {} ---@type t.fml.ux.select.IItem[]
          for name, action in pairs(prompt_actions.actions) do
            ---@type t.fml.ux.select.IItem
            local item = {
              uuid = name,
              text = name,
              data = action,
            }
            table.insert(select_items, item)
          end
          table.sort(select_items, function(a, b)
            return a.text < b.text
          end)
          return select_items
        end,
        fetch_preview_data = function(item)
          local data = item.data ---@type guanghechen.plugins.copilot_chat.prompt_actions.IItem
          local lines = vim.split(data.prompt or "", "\n") ---@type string[]

          ---@type t.fml.ux.search.preview.IData
          local result = {
            title = "Prompt",
            lines = lines,
            highlights = {},
            filetype = "text",
          }
          return result
        end,
        on_confirm = function(item)
          local data = item.data ---@type guanghechen.plugins.copilot_chat.prompt_actions.IItem
          vim.defer_fn(function()
            widget:show()
            require("CopilotChat").ask(data.prompt, data)
          end, 100)

          return "close"
        end,
      })
    end,
  })
  .register({
    uuid = uuids.copilot_chat_quick,
    desc = "copilot chat: quick chat",
    action = function()
      local input = vim.fn.input("Quick Chat: ") ---@type string
      if input ~= "" then
        widget:show()
        require("CopilotChat").ask(input, {
          context = { "buffer", "files", "git" },
          selection = require("CopilotChat.select").buffer,
        })
      end
    end,
  })
  .register({
    uuid = uuids.copilot_chat_reset,
    desc = "copilot chat: reset",
    action = function()
      return require("CopilotChat").reset()
    end,
  })
  .register({
    uuid = uuids.copilot_chat_stop,
    desc = "copilot chat: stop output",
    action = function()
      return require("CopilotChat").stop()
    end,
  })
  .register({
    uuid = uuids.copilot_chat_toggle,
    desc = "copilot chat: toggle",
    action = function()
      if detect_if_copilot_chat_is_open() then
        widget:hide()
      else
        widget:show()
      end
    end,
  })
