local __module_name__ = "fml.action.term" ---@type string

local reporter = require("eve.builtin.reporter")

local fts = require("eve.constant.filetype")
local get_selected_text = require("eve.lib.nvim").get_selected_text
local path = require("eve.lib.path")
local Terminal = require("fml.ux.terminal")

local terminal_map = {} ---@type table<string, fml.ux.ITerminal>

---@class fml.action.term.IProps
---@field public name                   string
---@field public command                ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public flag_quit_on_q         ?boolean
---@field public permanent              ?boolean

---@class fml.action.term.toggle.IParams : fml.action.term.IProps
---@field public send_selection_to_run  ?boolean

---@class fml.action.term
local M = {}

---@param props                        fml.action.term.IProps
---@return fml.ux.ITerminal
function M.new(props)
  local name = props.name ---@type string
  local command = props.command or vim.env.SHELL or vim.o.shell ---@type string
  local cwd = props.cwd or path.cwd() ---@type string
  local env = props.env ---@type table<string, string>|nil
  local permanent = props.permanent ---@type boolean|nil

  local terminal = terminal_map[name] ---@type fml.ux.ITerminal|nil
  if terminal ~= nil then
    reporter.error({
      from = __module_name__,
      subject = "new",
      message = "The term with the given name already exists.",
      details = { name = name, command = command, cwd = cwd, env = env },
    })
    return terminal
  end

  local keymaps = {} ---@type eve.t.IKeymap[]

  local flag_quit_on_q = not not props.flag_quit_on_q ---@type boolean
  if flag_quit_on_q then
    ---@type eve.t.IKeymap[]
    local keymap = {
      modes = { "n" },
      key = "q",
      desc = "terminal: quit",
      callback = function()
        if terminal ~= nil then
          ---@cast terminal             fml.ux.ITerminal
          terminal:close()
        end
      end,
    }
    table.insert(keymaps, keymap)
  end

  ---@type fml.ux.ITerminal
  terminal = Terminal.new({
    command = command,
    command_cwd = cwd,
    command_env = env,
    keymaps = keymaps,
    permanent = permanent,
  })
  terminal_map[name] = terminal

  terminal:open()
  return terminal
end

---@param params                        fml.action.term.toggle.IParams
---@return nil
function M.toggle(params)
  local name = params.name ---@type string
  local send_selection_to_run = not not params.send_selection_to_run ---@type boolean

  local selected_text = "" ---@type string'
  if send_selection_to_run then
    local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
    local filetype = vim.bo[bufnr_cur].filetype ---@type string
    if filetype ~= fts.TERM then
      selected_text = get_selected_text() ---@type string
    end
  end

  local terminal = terminal_map[name] ---@type fml.ux.ITerminal|nil
  if terminal == nil then
    terminal = M.new(params)
  else
    terminal:toggle()
  end

  if selected_text and #selected_text > 1 then
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

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.toggle_cwd(context)
  local cwd = path.cwd()

  M.toggle({
    name = "cwd",
    cwd = cwd,
    permanent = true,
    send_selection_to_run = true,
  })
end

---@param context                       eve.command.IContext
---@return nil
function M.toggle_directory(context)
  local bufnr = context.bufnr ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local cwd = path.dirname(filepath) ---@type string

  M.toggle({
    name = "directory",
    cwd = cwd,
    permanent = true,
    send_selection_to_run = true,
  })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.toggle_workspace(context)
  local cwd = path.workspace()

  M.toggle({
    name = "workspace",
    cwd = cwd,
    permanent = true,
    send_selection_to_run = true,
  })
end

return M
