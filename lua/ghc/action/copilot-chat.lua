local __module_name__ = "ghc.action.copilot-chat" ---@type string

local select = require("fml.fn.select")

if not eve.state.flight.ai:snapshot() then
  eve.reporter.error({
    from = __module_name__,
    subject = "copilot-chat",
    message = "Copilot is not enabled",
  })
  return {}
end

---@class ghc.action.copilot_chat.prompt_actions.IItem
---@field public prompt                 ?string
---@field public callback               ?fun(): nil

---@class ghc.action.copilot_chat.widget
---@field public winnr                  integer|nil
---@field public cursor                 integer[]|nil
---@field public status                 eve.e.WidgetStatus
---@field public win_cfg                fun(): vim.api.keyset.win_config
local config = {
  winnr = nil,
  cursor = nil,
  status = "closed",
  win_cfg = function()
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
}

---@type eve.t.ux.IWidget
local chat = eve.state.widget.wrap({
  name = "copilot-chat",
  close = function()
    local winnr = config.winnr ---@type integer|nil
    config.status = "closed"
    config.winnr = nil

    ---save the window cursor.
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
      config.cursor = cursor
    end

    require("CopilotChat").close()
  end,
  focus = function(widget)
    if not widget:focused() then
      require("CopilotChat").open()
      vim.schedule(function()
        local winnr = eve.editor.find_winnr_floating(eve.filetype.COPILOT_CHAT) ---@type integer|nil
        if winnr == nil then
          return
        end

        if eve.editor.is_win_floating(winnr) then
          local cfg_current = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
          local cfg_customized = config.win_cfg() ---@type vim.api.keyset.win_config
          local cfg = vim.tbl_extend("force", cfg_current, cfg_customized) ---@type vim.api.keyset.win_config
          vim.api.nvim_win_set_config(winnr, cfg)
        end

        config.winnr = winnr
        config.status = "visible"

        vim.wo[winnr].wrap = true
        vim.wo[winnr].number = false
        vim.wo[winnr].relativenumber = false
        vim.wo[winnr].signcolumn = "yes"
        vim.wo[winnr].winfixbuf = true
        vim.api.nvim_tabpage_set_win(0, winnr)

        local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
        if not vim.b[bufnr].fml_key_bound then
          vim.b[bufnr].fml_key_bound = true
          local keymaps = eve.state.widget.get_keymaps(widget) ---@type eve.t.IKeymap[]
          eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
        end

        vim.cmd.stopinsert()
        if config.cursor then
          pcall(function()
            vim.api.nvim_win_set_cursor(winnr, config.cursor)
          end)
        end
      end)
    end
  end,
  focused = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    return winnr == config.winnr
  end,
  hide = function()
    local winnr = config.winnr ---@type integer|nil
    config.status = "hidden"
    config.winnr = nil

    ---save the window cursor.
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
      config.cursor = cursor
    end

    require("CopilotChat").close()
  end,
  resize = function()
    local winnr = config.winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local wincfg = config.win_cfg() ---@type vim.api.keyset.win_config
      vim.api.nvim_win_set_config(winnr, wincfg)
    end
  end,
  status = function()
    return config.status
  end,
})

---@class ghc.action.copilot_chat
local M = {}

---@return nil
function M.prompt()
  local actions = require("CopilotChat.actions")
  local prompt_actions = actions["prompt_actions"]()
  if not prompt_actions then
    eve.reporter.warn({
      from = __module_name__,
      subject = "pick",
      message = "No prompt found on the current line",
    })
    return
  end

  select({
    cfg_preview_wrap = true,
    dimension = {
      width = 40,
      height = 20,
      width_preview = 80,
    },
    multiple = false,
    title = prompt_actions.prompt,
    fetch_items = function()
      local select_items = {} ---@type fml.ux.select.IItem[]
      for name, action in pairs(prompt_actions.actions) do
        ---@type fml.ux.select.IItem
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
      local data = item.data ---@type ghc.action.copilot_chat.prompt_actions.IItem
      local lines = vim.split(data.prompt or "", "\n", { plain = true }) ---@type string[]

      ---@type fml.ux.search.preview.IData
      local result = {
        title = "Prompt",
        lines = lines,
        highlights = {},
        filetype = "text",
      }
      return result
    end,
    on_confirm = function(widget, items)
      if #items == 1 then
        widget:close()

        local data = items[1].data ---@type ghc.action.copilot_chat.prompt_actions.IItem
        vim.defer_fn(function()
          chat:focus()
          require("CopilotChat").ask(data.prompt, data)
        end, 100)
      end
    end,
  })
end

---@return nil
function M.quick()
  local input = vim.fn.input("Quick Chat: ") ---@type string
  if input ~= "" then
    chat:focus()
    require("CopilotChat").ask(input, {
      context = { "buffer", "files" },
      selection = require("CopilotChat.select").buffer,
    })
  end
end

---@return nil
function M.reset()
  vim.cmd("CopilotChatReset")
end

---@return nil
function M.stop()
  vim.cmd("CopilotChatStop")
end

---@return nil
function M.toggle()
  if chat:focused() then
    chat:hide()
  else
    chat:focus()
  end
end

---@return nil
function M.translate()
  chat:focus()
  vim.cmd("CopilotChatTranslate")
end

return M
