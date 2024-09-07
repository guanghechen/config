local Terminal = require("fml.ui.terminal")

local terminal_map = {} ---@type table<string, fml.types.ui.ITerminal>

---@class fml.api.term
local M = {}

---@class fml.api.term.ICreateParams
---@field public name                   string
---@field public command                ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public flag_quit_on_q         ?boolean
---@field public permanent              ?boolean

---@class fml.api.term.IToggleOrCreateParams : fml.api.term.ICreateParams
---@field public send_selection_to_run  ?boolean

---@param params                        fml.api.term.ICreateParams
---@return nil
function M.create(params)
  local name = params.name ---@type string
  local command = params.command or vim.env.SHELL or vim.o.shell ---@type string
  local cwd = params.cwd or eve.path.cwd() ---@type string
  local env = params.env ---@type table<string, string>|nil
  local permanent = params.permanent ---@type boolean|nil

  local terminal = terminal_map[name] ---@type fml.types.ui.ITerminal|nil
  if terminal ~= nil then
    eve.reporter.error({
      from = "fml.api.term",
      subject = "create",
      message = "The term with the given name already exists.",
      details = { name = name, command = command, cwd = cwd, env = env },
    })
    return
  end

  local keymaps = {} ---@type fml.types.IKeymap[]

  local flag_quit_on_q = not not params.flag_quit_on_q ---@type boolean
  if flag_quit_on_q then
    ---@type fml.types.IKeymap[]
    local keymap = {
      modes = { "n" },
      key = "q",
      desc = "terminal: quit",
      callback = function()
        if terminal ~= nil then
          ---@cast terminal fml.types.ui.ITerminal
          terminal:close()
        end
      end,
    }
    table.insert(keymaps, keymap)
  end

  ---@type fml.types.ui.ITerminal
  terminal = Terminal.new({
    command = command,
    command_cwd = cwd,
    command_env = env,
    keymaps = keymaps,
    permanent = permanent,
  })
  terminal_map[name] = terminal

  terminal:open()
end

---@param name                          string
---@return nil
function M.toggle(name)
  local terminal = terminal_map[name] ---@type fml.types.ui.ITerminal
  if terminal == nil then
    eve.reporter.error({
      from = "fml.api.term",
      subject = "toggle",
      message = "Cannot find the term with the given name.",
      details = { name = name },
    })
    return
  end
  terminal:toggle()
end

---@param params                        fml.api.term.IToggleOrCreateParams
---@return nil
function M.toggle_or_create(params)
  local name = params.name ---@type string
  local send_selection_to_run = not not params.send_selection_to_run ---@type boolean

  local selected_text = "" ---@type string'
  if send_selection_to_run then
    local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
    local filetype = vim.bo[bufnr_cur].filetype ---@type string
    if filetype ~= eve.constants.FT_TERM then
      selected_text = eve.util.get_selected_text() ---@type string
    end
  end

  if terminal_map[name] == nil then
    M.create(params)
  else
    M.toggle(name)
  end

  if selected_text and #selected_text > 1 then
    local terminal = terminal_map[name] ---@type fml.types.ui.ITerminal
    local winnr = terminal:get_winnr() ---@type integer|nil
    local bufnr = terminal:get_bufnr() ---@type integer|nil
    if winnr ~= nil and bufnr ~= nil then
      if selected_text and #selected_text > 1 then
        vim.api.nvim_set_current_win(winnr)
        vim.api.nvim_win_set_buf(winnr, bufnr)
        vim.api.nvim_feedkeys("i" .. selected_text, "n", true) -- Insert the text without newline
      end
    end
  end
end

return M
