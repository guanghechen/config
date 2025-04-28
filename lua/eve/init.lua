---@class eve.__mods
local __mods = {
  G = "eve.builtin.G",
  box = "eve.builtin.box",
  buf = "eve.builtin.buf",
  clipboard = "eve.builtin.clipboard",
  command = "eve.builtin.command",
  debug = "eve.builtin.debug",
  editor = "eve.builtin.editor",
  env = "eve.builtin.env",
  filetype = "eve.builtin.filetype",
  fn = "eve.builtin.fn",
  fs = "eve.builtin.fs",
  icon = "eve.builtin.icon",
  im = "eve.builtin.im",
  json = "eve.builtin.json",
  lsp = "eve.builtin.lsp",
  notifier = "eve.builtin.notifier",
  nvim = "eve.builtin.nvim",
  oxi = "eve.builtin.oxi",
  path = "eve.builtin.path",
  qflist = "eve.builtin.qflist",
  reporter = "eve.builtin.reporter",
  session = "eve.builtin.session",
  setting = "eve.builtin.setting",
  shell = "eve.builtin.shell",
  sign = "eve.builtin.sign",
  string = "eve.builtin.string",
  tab = "eve.builtin.tab",
  table = "eve.builtin.table",
  tmux = "eve.builtin.tmux",
  var = "eve.builtin.var",
  widget = "eve.builtin.widget",
  win = "eve.builtin.win",
  winpicker = "eve.builtin.winpicker",
}

---@class eve
---@field public __mods                 eve.__mods
---@field public constant               eve.constant
---@field public std                    eve.std
---@field public state                  eve.state
---@field public ux                     eve.ux
---
---@field public G                      eve.builtin.G
---@field public box                    eve.builtin.box
---@field public buf                    eve.builtin.buf
---@field public clipboard              eve.builtin.clipboard
---@field public command                eve.builtin.command
---@field public debug                  eve.builtin.debug
---@field public editor                 eve.builtin.editor
---@field public env                    eve.builtin.env
---@field public filetype               eve.builtin.filetype
---@field public fn                     eve.builtin.fn
---@field public fs                     eve.builtin.fs
---@field public icon                   eve.builtin.icon
---@field public im                     eve.builtin.im
---@field public json                   eve.builtin.json
---@field public lsp                    eve.builtin.lsp
---@field public notifier               eve.builtin.notifier
---@field public nvim                   eve.builtin.nvim
---@field public oxi                    eve.builtin.oxi
---@field public path                   eve.builtin.path
---@field public qflist                 eve.builtin.qflist
---@field public reporter               eve.builtin.reporter
---@field public session                eve.builtin.session
---@field public setting                eve.builtin.setting
---@field public shell                  eve.builtin.shell
---@field public sign                   eve.builtin.sign
---@field public string                 eve.builtin.string
---@field public tab                    eve.builtin.tab
---@field public table                  eve.builtin.table
---@field public tmux                   eve.builtin.tmux
---@field public var                    eve.builtin.var
---@field public widget                 eve.builtin.widget
---@field public win                    eve.builtin.win
---@field public winpicker              eve.builtin.winpicker
local M = setmetatable({
  __mods = __mods,
  constant = require("eve.constant"),
  std = require("eve.std"),
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
_G.eve = M

---@return eve.state.storage
function M.get_default_storage()
  local is_git_repo = eve.path.is_repo_git() ---@type boolean

  ---@type eve.state.storage
  return {
    editor = eve.path.locate_context_filepath("editor.json"),
    session = is_git_repo and eve.path.locate_workspace_filepath("session.json") or nil,
    workspace = is_git_repo and eve.path.locate_workspace_filepath("workspace.json") or nil,
    nvim_session = is_git_repo and eve.path.locate_workspace_filepath("session.vim") or nil,
    nvim_session_autosaved = is_git_repo and eve.path.locate_workspace_filepath("session.autosaved.vim") or nil,
  }
end

---@return nil
function M.setup_breakpoints()
  local breakpoints = eve.state.lsp.breakpoints:snapshot() ---@type eve.state.lsp.IBreakpointData
  if #breakpoints < 1 then
    return
  end

  local filepath_set = {} ---@type table<string, true>
  for _, breakpoint in ipairs(breakpoints) do
    filepath_set[breakpoint.filepath] = true
  end
  local filepaths = vim.tbl_keys(filepath_set) ---@type string[]

  eve.win.open_filepaths(0, filepaths)

  eve.std.timer.set_timeout(function()
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
function M.setup_patches()
  vim.hl = vim.hl or vim.highlight --- vim.hl has been renamed to vim.highlight
  table.unpack = table.unpack or unpack --- table.unpack is introduced in Lua 5.2
end

---! Auto cd the directory:
---! 1. the opened file is under a git repo, let's remember the the git repo path as A,
---!    and assume the git repo directory of the shell cwd is B.
---!      a) If A is different from B, then auto cd the A.
---!      b) If A is the same as B, then no action needed.
---! 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
---@return nil
function M.setup_workspace()
  if vim.fn.expand("%") ~= "" then
    local cwd = vim.uv.cwd() or vim.fn.getcwd() ---@type string
    local p = vim.fn.expand("%:p:h")
    local A = eve.path.locate_git_repo(p)
    local B = eve.path.locate_git_repo(cwd)

    if A == nil then
      pcall(function()
        vim.api.nvim_set_current_dir(p)
      end)
    elseif A ~= B then
      vim.api.nvim_set_current_dir(A)
    end
  end

  ---! Clear jumplist. See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
  vim.schedule(function()
    vim.cmd("clearjumps")
  end)
end

---@param storage                       eve.state.storage|nil
---@return nil
function M.setup_state(storage)
  storage = storage or M.get_default_storage() ---@type eve.state.storage
  eve.state.set_storage(storage)
  eve.state.load(storage, false)
  require("eve.state.autocmd")
end

---@return nil
function M.setup_theme()
  eve.state.theme.reload_theme(false, false)
  vim.schedule(function()
    eve.state.watch_changes()
  end)
end

return M
