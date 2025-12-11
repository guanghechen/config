---@class eve.__mods
local __mods = {
  context = "eve.context",
  fn = "eve.fn",
  state = "eve.state",

  ai = "eve.builtin.ai",
  buf = "era.buf",
  clipboard = "eve.builtin.clipboard",
  git = "eve.state.git",
  lsp = "eve.builtin.lsp",
  lsp_action = "eve.builtin.lsp_action",
  notifier = "eve.builtin.notifier",
  session = "era.session",
  tab = "era.tab",
  term = "eve.builtin.term",
  win = "era.win",
  winpicker = "eve.builtin.winpicker",
}

---@class eve
---@field public __mods                 eve.__mods
---@field public context                eve.context
---@field public fn                     eve.fn
---@field public state                  eve.state
---
---@field public ai                     eve.builtin.ai
---@field public buf                    era.buf
---@field public clipboard              eve.builtin.clipboard
---@field public git                    eve.state.git
---@field public lsp                    eve.builtin.lsp
---@field public lsp_action             eve.builtin.lsp_action
---@field public notifier               eve.builtin.notifier
---@field public session                era.session
---@field public tab                    era.tab
---@field public term                   eve.builtin.term
---@field public win                    era.win
---@field public winpicker              eve.builtin.winpicker
local M = setmetatable({ __mods = __mods }, {
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

  local colorscheme = eve.context.theme.theme:snapshot() ---@type dot.e.ThemeFullName
  vim.cmd.colorscheme(colorscheme)
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

  era.win.open_filepaths(0, filepaths)

  std.timer.set_timeout(function()
    local bps = require("dap.breakpoints")
    for _, breakpoint in ipairs(breakpoints) do
      local bufnr = era.buf.loadfile(breakpoint.filepath) ---@type integer|nil
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
function M.setup_diagnostics()
  local severity2numhl = dot.var.diagnostic.severity2numhl ---@type table<vim.diagnostic.Severity, string>
  local severity2prefixicon = dot.var.diagnostic.severity2prefixicon ---@type table<vim.diagnostic.Severity, string>
  local severity2texticon = dot.var.diagnostic.severity2texticon ---@type table<vim.diagnostic.Severity, string>

  ark.fn.observe({ eve.context.lsp.diagnostics_virt_lines }, function()
    ---@type vim.diagnostic.Opts
    local config = {
      float = {
        border = "rounded",
        focus = true,
        focusable = true,
        source = true,
      },
      severity_sort = true,
      signs = {
        numhl = severity2numhl,
        text = severity2texticon,
      },
      underline = true,
      update_in_insert = false,
      virtual_lines = {
        current_line = true,
        format = function(diagnostic)
          local icon = severity2prefixicon[diagnostic.severity] or ""
          return string.format("%s %s", icon, diagnostic.message)
        end,
      },
      virtual_text = {
        current_line = false,
        prefix = function(diagnostic)
          return severity2prefixicon[diagnostic.severity] or ""
        end,
        source = "if_many",
        spacing = 4,
      },
    }

    local enable_diagnostic_virt_lines = eve.context.lsp.diagnostics_virt_lines:snapshot() ---@type boolean
    if not enable_diagnostic_virt_lines then
      config.virtual_lines = false
      config.virtual_text.current_line = nil
    end
    vim.diagnostic.config(config)
  end)
end

---@return nil
function M.setup_lsp()
  -- Lazy load LSP servers on FileType, see lua/integration/neovim/autocmd.lua
  -- local lsp_servers = {
  --   -- "basedpyright",
  --   "bashls",
  --   "clangd",
  --   "cssls",
  --   "docker_compose_language_service",
  --   "dockerls",
  --   "eslint",
  --   "html",
  --   "jsonls",
  --   "lua_ls",
  --   "pyright",
  --   "ruff",
  --   "rust_analyzer",
  --   "tailwindcss",
  --   "taplo",
  --   "vtsls",
  --   "yamlls",
  -- }
  -- vim.lsp.enable(lsp_servers)

  if not vim.g.vscode and eve.context.flight.ai:snapshot() then
    vim.lsp.enable("copilot")
  end

  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local bufnr_cur = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
  local filepath_cur = vim.api.nvim_buf_get_name(bufnr_cur) ---@type string
  if filepath_cur ~= "" then
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(winnr_cur) and not vim.wo[winnr_cur].winfixbuf then
        local bufnr = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
        local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
        if filepath == filepath_cur then
          vim.api.nvim_win_call(winnr_cur, function()
            vim.cmd.edit(filepath)
          end)
        end
      end
    end)
  end
end

return M
