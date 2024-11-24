local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

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
        require("CopilotChat").ask(input)
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
      return require("CopilotChat").toggle()
    end,
  })
