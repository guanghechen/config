local __module_name__ = "ghc.action.copilot-chat" ---@type string

if not eve.context.flight.ai:snapshot() then
  std.reporter.error({
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
---@field public win_cfg                fun(): vim.api.keyset.win_config
local config = {
  winnr = nil,
  cursor = nil,
  win_cfg = function()
    local width = math.min(124, math.floor(vim.o.columns * 0.8)) ---@type integer
    local height = math.min(48, math.floor(vim.o.lines * 0.8)) ---@type integer
    local row = math.floor((vim.o.lines - height) / 2) ---@type integer
    local col = math.floor((vim.o.columns - width) / 2) ---@type integer

    ---@type vim.api.keyset.win_config
    local wincfg = {
      zindex = 2,
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

---@return nil
local function hide()
  local winnr = config.winnr ---@type integer|nil
  config.winnr = nil

  ---save the window cursor.
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
    config.cursor = cursor
  end
  require("CopilotChat").close()
end

---@type std.t.ux.IWidget
local chat = eve.widget.wrap({
  name = "copilot-chat",
  close = hide,
  hide = hide,
  focus = function(widget)
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    if config.winnr ~= nil and not vim.api.nvim_win_is_valid(config.winnr) then
      vim.api.nvim_tabpage_set_win(tabnr, config.winnr)
      return
    end

    require("CopilotChat").open()

    vim.schedule(function()
      local winnr = eve.win.find_floating_by_filetype(0, eve.filetype.COPILOT_CHAT) ---@type integer|nil
      if winnr == nil then
        return
      end

      if eve.win.is_float(winnr) then
        local cfg_current = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
        local cfg_customized = config.win_cfg() ---@type vim.api.keyset.win_config
        local cfg = vim.tbl_extend("force", cfg_current, cfg_customized) ---@type vim.api.keyset.win_config
        vim.api.nvim_win_set_config(winnr, cfg)
      end

      config.winnr = winnr

      vim.wo[winnr].wrap = true
      vim.wo[winnr].number = false
      vim.wo[winnr].relativenumber = false
      vim.wo[winnr].signcolumn = "yes"
      vim.wo[winnr].winfixbuf = true
      vim.api.nvim_tabpage_set_win(0, winnr)

      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if not vim.b[bufnr].fml_key_bound then
        vim.b[bufnr].fml_key_bound = true
        local keymaps = eve.widget.get_keymaps(widget) ---@type std.t.IKeymap[]
        eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
      end

      vim.cmd.stopinsert()
      if config.cursor then
        pcall(function()
          vim.api.nvim_win_set_cursor(winnr, config.cursor)
        end)
      end
    end)
  end,
  isdisposed = function()
    return false
  end,
  isfocused = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    return winnr == config.winnr
  end,
  isvisible = function()
    return config.winnr ~= nil and vim.api.nvim_win_is_valid(config.winnr)
  end,
  resize = function()
    local winnr = config.winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local wincfg = config.win_cfg() ---@type vim.api.keyset.win_config
      vim.api.nvim_win_set_config(winnr, wincfg)
    end
  end,
})

---@class ghc.action.copilot_chat
local M = {}

---@return nil
function M.prompt()
  local actions = require("CopilotChat.actions")
  local prompt_actions = actions["prompt_actions"]()
  if not prompt_actions then
    std.reporter.warn({
      from = __module_name__,
      subject = "pick",
      message = "No prompt found on the current line",
    })
    return
  end

  local items = {} ---@type string[]
  local action_map = {} ---@type table<string, ghc.action.copilot_chat.prompt_actions.IItem>
  for name, action in pairs(prompt_actions.actions) do
    items[#items + 1] = name
    action_map[name] = action
  end
  table.sort(items)

  vim.ui.select(items, {
    name = __module_name__,
    prompt = prompt_actions.prompt or "Select prompt",
    dimension = {
      width = 80,
      height = math.min(#items + 3, 20),
      width_preview = 60,
    },
    preview_render = function(composer, bufnr, _)
      local item = composer:retrieve(composer.result.lnum_current:snapshot())
      if not item then
        ---@type eve.ux.picker.preview.IDrawResult
        return {
          cursorline = false,
          number = false,
          title = "Prompt Preview",
          wrap = true,
          whitespaces = false,
          lnum = nil,
          col = nil,
        }
      end
      local selected_name = item.text ---@type string
      local action = action_map[selected_name] ---@type ghc.action.copilot_chat.prompt_actions.IItem
      local prompt_text = action.prompt or "" ---@type string
      local lines = vim.split(prompt_text, "\n", { plain = true }) ---@type string[]
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.bo[bufnr].filetype = "text"
      ---@type eve.ux.picker.preview.IDrawResult
      return {
        cursorline = false,
        number = false,
        title = "Prompt Preview",
        wrap = true,
        whitespaces = false,
        lnum = 1,
        col = 0,
      }
    end,
  }, function(choice)
    if choice then
      local action = action_map[choice] ---@type ghc.action.copilot_chat.prompt_actions.IItem
      std.timer.set_timeout(function()
        chat:focus()
        require("CopilotChat").ask(action.prompt, action)
      end, 100)
    end
  end)
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
  if chat:isfocused() then
    chat:close()
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
