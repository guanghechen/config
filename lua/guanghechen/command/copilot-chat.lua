if not eve.context.state.flight.copilot:snapshot() then
  return
end

---@class guanghechen.command.copilot_chat.prompt_actions.IItem
---@field public prompt                 ?string
---@field public callback               ?fun(): nil

local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

local widget_status = "closed" ---@type t.eve.e.WidgetStatus

---@type t.eve.ux.IWidget
local widget
widget = {
  name = "copitlot-chat",
  statusline_items = nil,
  status = function()
    return widget_status
  end,
  close = function()
    widget:hide()
  end,
  hide = function()
    widget_status = "hidden"
    require("CopilotChat").close()
  end,
  resize = function()
    if widget_status == "visible" then
      require("CopilotChat").close()
      require("CopilotChat").open()
    end
  end,
  open = function()
    eve.globals.widgets.open(widget)
  end,
  show = function()
    if widget_status == "visible" then
      return
    end

    require("CopilotChat").open()
    widget_status = "visible"

    vim.schedule(function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if vim.bo[bufnr].filetype == eve.constants.FT_COPILOT_CHAT then
        vim.cmd("stopinsert")

        ---Center the title
        local cfg = vim.api.nvim_win_get_config(winnr)
        cfg.title_pos = "center"
        vim.api.nvim_win_set_config(winnr, cfg)

        ---Change highlights
        vim.wo[winnr].wrap = true

        if not vim.b[bufnr].guanghechen_key_binded then
          vim.b[bufnr].guanghechen_key_binded = true

          local keymaps = eve.globals.widgets.get_keymaps() ---@type t.eve.IKeymap[]
          eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
        end
      end
    end)
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
          local data = item.data ---@type guanghechen.command.copilot_chat.prompt_actions.IItem
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
          local data = item.data ---@type guanghechen.command.copilot_chat.prompt_actions.IItem
          vim.defer_fn(function()
            widget:open()
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
        widget:open()
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
      if widget_status == "visible" then
        widget:hide()
      else
        widget:open()
      end
    end,
  })
