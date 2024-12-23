local __module_name__ = "guanghechen.plugins.CopilotChat" ---@type string

local constant = require("eve.lib.constant")
local reporter = require("eve.lib.reporter")
local state = require("eve.state")

if not state.flight.copilot:snapshot() then
  return
end

local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

---@class guanghechen.command.copilot_chat.prompt_actions.IItem
---@field public prompt                 ?string
---@field public callback               ?fun(): nil

---@class guanghechen.command.copilot_chat.widget : eve.t.ux.IWidget
---@field public internal_winnr         integer|nil
---@field public internal_cursor        integer[]|nil
---@field public internal_status        eve.e.WidgetStatus
---@field public internal_win_find      fun(): integer|nil
---@field public internal_win_cfg       fun(): vim.api.keyset.win_config
---@field public internal_win_clsoe     fun(): nil
---@field public internal_win_open      fun(): nil
---@field public internal_win_resize    fun(): nil
local chat_widget

chat_widget = {
  internal_winnr = nil,
  internal_cursor = nil,
  internal_status = "closed",
  internal_win_find = function()
    local winnrs = vim.api.nvim_list_wins() ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if vim.bo[bufnr].filetype == constant.FT_COPILOT_CHAT then
        return winnr
      end
    end
  end,
  internal_win_cfg = function()
    local width = math.min(124, math.floor(vim.o.columns * 0.8)) ---@type integer
    local height = math.min(48, math.floor(vim.o.lines * 0.8)) ---@type integer
    local row = math.floor((vim.o.lines - height) / 2) ---@type integer
    local col = math.floor((vim.o.columns - width) / 2) ---@type integer

    ---@type vim.api.keyset.win_config
    local wincfg = {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
      title = " Copilot Chat ",
      title_pos = "center",
      border = "rounded",
      focusable = true,
    }
    return wincfg
  end,
  internal_win_clsoe = function()
    local winnr = chat_widget.internal_winnr ---@type integer|nil
    chat_widget.internal_winnr = nil

    ---save the window cursor.
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
      chat_widget.internal_cursor = cursor
    end

    require("CopilotChat").close()
  end,
  internal_win_open = function()
    require("CopilotChat").open()
    vim.schedule(function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

      local cfg_current = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
      local cfg_customized = chat_widget.internal_win_cfg() ---@type vim.api.keyset.win_config
      local cfg = vim.tbl_extend("force", cfg_current, cfg_customized) ---@type vim.api.keyset.win_config
      vim.api.nvim_win_set_config(winnr, cfg)

      if vim.bo[bufnr].filetype == constant.FT_COPILOT_CHAT then
        chat_widget.internal_winnr = winnr
        chat_widget.internal_status = "visible"

        vim.wo[winnr].wrap = true
        vim.wo[winnr].number = false
        vim.wo[winnr].relativenumber = false
        vim.wo[winnr].signcolumn = "yes"

        if not vim.b[bufnr].ghc_key_bound then
          vim.b[bufnr].ghc_key_bound = true
          local keymaps = eve.widgets.get_keymaps() ---@type eve.t.IKeymap[]
          eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
        end

        vim.schedule(function()
          vim.cmd("stopinsert")
          if chat_widget.internal_cursor then
            pcall(function()
              vim.api.nvim_win_set_cursor(winnr, chat_widget.internal_cursor)
            end)
          end
        end)
      end
    end)
  end,
  internal_win_resize = function()
    local winnr = chat_widget.internal_winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local wincfg = chat_widget.internal_win_cfg() ---@type vim.api.keyset.win_config
      vim.api.nvim_win_set_config(winnr, wincfg)
    end
  end,

  ----

  name = "copitlot-chat",
  statusline_items = nil,
  status = function()
    return chat_widget.internal_status
  end,
  close = function()
    chat_widget.internal_status = "closed"
    chat_widget.internal_win_clsoe()
  end,
  hide = function()
    chat_widget.internal_status = "hidden"
    chat_widget.internal_win_clsoe()
  end,
  resize = function()
    chat_widget.internal_win_resize()
  end,
  open = function()
    if chat_widget.internal_status == "closed" then
      chat_widget.internal_status = "hidden"
    end
    eve.widgets.open(chat_widget)
  end,
  show = function()
    if chat_widget.internal_status ~= "visible" then
      chat_widget.internal_win_open()
    end
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
        reporter.warn({
          from = __module_name__,
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
          local select_items = {} ---@type fml.t.ux.select.IItem[]
          for name, action in pairs(prompt_actions.actions) do
            ---@type fml.t.ux.select.IItem
            local item = {
              uuid = name,
              text = name,
              data = action,
            }
            select_items[select_items + 1] = item
          end
          table.sort(select_items, function(a, b)
            return a.text < b.text
          end)
          return select_items
        end,
        fetch_preview_data = function(item)
          local data = item.data ---@type guanghechen.command.copilot_chat.prompt_actions.IItem
          local lines = vim.split(data.prompt or "", "\n", { plain = true }) ---@type string[]

          ---@type fml.t.ux.search.preview.IData
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
            chat_widget:open()
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
        chat_widget:open()
        require("CopilotChat").ask(input, {
          context = { "buffer", "files" },
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
      if chat_widget.internal_status == "visible" then
        chat_widget:hide()
      else
        chat_widget:open()
      end
    end,
  })
