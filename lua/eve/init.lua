---@class eve.__mods
local __mods = {
  G = "eve.builtin.G",
  ai = "eve.builtin.ai",
  box = "eve.builtin.box",
  buf = "eve.builtin.buf",
  clipboard = "eve.builtin.clipboard",
  command = "eve.builtin.command",
  filetype = "eve.builtin.filetype",
  git = "eve.state.git",
  icon = "eve.builtin.icon",
  im = "eve.builtin.im",
  lsp = "eve.builtin.lsp",
  notifier = "eve.builtin.notifier",
  nvim = "eve.builtin.nvim",
  qflist = "eve.builtin.qflist",
  plugin = "eve.builtin.plugin",
  prompt = "eve.builtin.prompt",
  session = "eve.builtin.session",
  setting = "eve.builtin.setting",
  shell = "eve.builtin.shell",
  status = "eve.builtin.status",
  tab = "eve.builtin.tab",
  term = "eve.builtin.term",
  var = "eve.builtin.var",
  widget = "eve.builtin.widget",
  win = "eve.builtin.win",
  winpicker = "eve.builtin.winpicker",
}

---@class eve
---@field public __mods                 eve.__mods
---@field public constant               eve.constant
---@field public context                eve.context
---@field public fn                     eve.fn
---@field public state                  eve.state
---@field public ux                     eve.ux
---
---@field public G                      eve.builtin.G
---@field public ai                     eve.builtin.ai
---@field public box                    eve.builtin.box
---@field public buf                    eve.builtin.buf
---@field public clipboard              eve.builtin.clipboard
---@field public command                eve.builtin.command
---@field public filetype               eve.builtin.filetype
---@field public git                    eve.state.git
---@field public icon                   eve.builtin.icon
---@field public im                     eve.builtin.im
---@field public lsp                    eve.builtin.lsp
---@field public notifier               eve.builtin.notifier
---@field public nvim                   eve.builtin.nvim
---@field public qflist                 eve.builtin.qflist
---@field public plugin                 eve.builtin.plugin
---@field public prompt                 eve.builtin.prompt
---@field public session                eve.builtin.session
---@field public setting                eve.builtin.setting
---@field public shell                  eve.builtin.shell
---@field public status                 eve.builtin.status
---@field public tab                    eve.builtin.tab
---@field public term                   eve.builtin.term
---@field public var                    eve.builtin.var
---@field public widget                 eve.builtin.widget
---@field public win                    eve.builtin.win
---@field public winpicker              eve.builtin.winpicker
local M = setmetatable({
  __mods = __mods,
  constant = require("eve.constant"),
  context = require("eve.context"),
  fn = require("eve.fn"),
  state = require("eve.state"),
  ux = require("eve.ux"),
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@return eve.context.storage
function M.get_default_storage()
  local is_git_repo = std.path.is_git_repo() ---@type boolean

  ---@type eve.context.storage
  return {
    editor = std.path.locate_context_filepath("editor.json"),
    session = is_git_repo and std.path.locate_workspace_filepath("session.json") or nil,
    workspace = is_git_repo and std.path.locate_workspace_filepath("workspace.json") or nil,
    nvim_session = is_git_repo and std.path.locate_workspace_filepath("session.vim") or nil,
    nvim_session_autosaved = is_git_repo and std.path.locate_workspace_filepath("session.autosaved.vim") or nil,
  }
end

---@param storage                       eve.context.storage|nil
---@return nil
function M.setup_context(storage)
  storage = storage or M.get_default_storage() ---@type eve.context.storage
  eve.context.set_storage(storage)
  eve.context.load(storage, false)
end

---@return nil
function M.setup_theme()
  eve.context.theme.reload_theme(false, false)
  vim.schedule(function()
    eve.context.theme.reload_theme(false, false)
    eve.context.watch_changes()
  end)
end

---@return nil
function M.setup_breakpoints()
  local breakpoints = eve.context.lsp.breakpoints:snapshot() ---@type eve.context.lsp.IBreakpointData
  if #breakpoints < 1 then
    return
  end

  local filepath_set = {} ---@type table<string, true>
  for _, breakpoint in ipairs(breakpoints) do
    filepath_set[breakpoint.filepath] = true
  end
  local filepaths = vim.tbl_keys(filepath_set) ---@type string[]

  eve.win.open_filepaths(0, filepaths)

  std.timer.set_timeout(function()
    local bps = require("dap.breakpoints")
    for _, breakpoint in ipairs(breakpoints) do
      local bufnr = eve.buf.loadfile(breakpoint.filepath) ---@type integer|nil
      if bufnr ~= nil then
        bps.set({
          condition = breakpoint.condition,
          hit_condition = breakpoint.hit_condition,
          log_message = breakpoint.log_message,
        }, bufnr, breakpoint.lnum)
      end
    end
  end, 100)
end

---@return nil
function M.setup_lsp()
  local lsp_servers = {
    -- "basedpyright",
    "bashls",
    "clangd",
    "cssls",
    "docker_compose_language_service",
    "dockerls",
    "eslint",
    "html",
    "jsonls",
    "lua_ls",
    "pyright",
    "ruff",
    "rust_analyzer",
    "tailwindcss",
    "taplo",
    "vtsls",
    "yamlls",
  }

  -- Add Copilot LSP if AI is enabled
  if eve.context.flight.ai:snapshot() then
    table.insert(lsp_servers, "copilot")
  end

  vim.lsp.enable(lsp_servers)

  local severity2prefixicon = eve.constant.diagnostic.severity2prefixicon ---@type table<vim.diagnostic.Severity, string> {
  local severity2texticon = eve.constant.diagnostic.severity2texticon ---@type table<vim.diagnostic.Severity, string>
  local severity2numhl = eve.constant.diagnostic.severity2numhl ---@type table<vim.diagnostic.Severity, string>
  local enable_diagnostic_virt_lines = eve.context.lsp.diagnostics_virt_lines:snapshot() ---@type boolean
  local virtual_text_current_line = nil ---@type boolean|nil
  if enable_diagnostic_virt_lines then
    virtual_text_current_line = false ---@type boolean|nil
  end
  vim.diagnostic.config({
    virtual_text = {
      current_line = virtual_text_current_line,
      source = "if_many",
      spacing = 4,
      prefix = function(diagnostic)
        return severity2prefixicon[diagnostic.severity] or ""
      end,
    },
    virtual_lines = enable_diagnostic_virt_lines and {
      current_line = true,
      format = function(diagnostic)
        local icon = severity2prefixicon[diagnostic.severity] or ""
        return string.format("%s %s", icon, diagnostic.message)
      end,
    } or nil,
    signs = {
      text = severity2texticon,
      numhl = severity2numhl,
    },
    severity_sort = true,
    underline = true,
    update_in_insert = false,
    float = {
      border = "rounded",
      focus = true,
      focusable = true,
      source = true,
    },
  })

  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local bufnr_cur = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
  local filepath_cur = vim.api.nvim_buf_get_name(bufnr_cur) ---@type string
  if filepath_cur ~= "" then
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(winnr_cur) then
        local bufnr = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
        local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
        if filepath == filepath_cur then
          vim.api.nvim_win_call(winnr_cur, function()
            vim.cmd("edit " .. filepath)
          end)
        end
      end
    end)
  end
end

return M
