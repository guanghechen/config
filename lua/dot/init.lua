---@class dot.fn.__mods
local __fn__mods = {
  add_locations_to_ai = "dot.fn.add_locations_to_ai",
  find_buffers = "dot.fn.find-buffers",
  find_diagnostics = "dot.fn.find-diagnostics",
  find_explorer = "dot.fn.find-explorer",
  find_files = "dot.fn.find-files",
  find_git = "dot.fn.find-git",
  find_highlights = "dot.fn.find-highlights",
  find_keymaps = "dot.fn.find-keymaps",
  find_lsp_symbols = "dot.fn.find-lsp-symbols",
  find_notifications = "dot.fn.find-notifications",
  find_pinned_files = "dot.fn.find-pinned-files",
  find_vim_options = "dot.fn.find-vim-options",
  insert_splitline = "dot.fn.insert-splitline",
  paste_image = "dot.fn.paste_image",
  paste_image_as_base64 = "dot.fn.paste_image_as_base64",
  pick_win = "dot.fn.pick_win",
  rename = "dot.fn.rename",
  run_code = "dot.fn.run_code",
  run_code_as_neovim_command = "dot.fn.run_code_as_neovim_command",
  search_in_buffer = "dot.fn.search-in-buffer",
  search_in_files = "dot.fn.search-in-files",
  select_copy_filepath = "dot.fn.select_copy_filepath",
  select_copy_filepaths = "dot.fn.select_copy_filepaths",
  select_encoding = "dot.fn.select_encoding",
}

---@class dot.fn
---@field public __mods                 dot.fn.__mods
---@field public add_locations_to_ai    fun(locations: dot.t.ILocation[]): nil
---@field public find_buffers           fun(scope: dot.e.FindBufferScope|nil): nil
---@field public find_diagnostics       fun(): nil
---@field public find_explorer          fun(specified_filepath: string|nil): nil
---@field public find_files             fun(rootpath: string|"cwd"|"directory"|"workspace"|nil, reset_input: boolean|nil): nil
---@field public find_git               fun(): nil
---@field public find_highlights        fun(): nil
---@field public find_keymaps           fun(): nil
---@field public find_lsp_symbols       fun(): nil
---@field public find_notifications     fun(): nil
---@field public find_pinned_files      fun(): nil
---@field public find_vim_options       fun(): nil
---@field public insert_splitline       fun(): nil
---@field public paste_image            fun(): nil
---@field public paste_image_as_base64  fun(): string|nil
---@field public pick_win               dot.fn.pick_win
---@field public rename                 dot.fn.rename
---@field public run_code               fun(force: boolean): nil
---@field public run_code_as_neovim_command fun(): nil
---@field public search_in_buffer       fun(): nil
---@field public search_in_files        fun(rootpath: string|"cwd"|"directory"|"workspace"|"file"|nil, reset_input: boolean|nil): nil
---@field public select_copy_filepath   fun(params: dot.fn.select_copy_filepath.IParams): integer
---@field public select_copy_filepaths  fun(params: dot.fn.select_copy_filepaths.IParams): integer
---@field public select_encoding        fun(params: dot.fn.select_encoding.IParams): dot.module.picker.ListComposer
local fn = setmetatable({
  __mods = __fn__mods,
}, {
  __index = function(t, k)
    local m = __fn__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.state.__mods
local __state__mods = {
  maximized = "dot.state.maximized",
  notepad = "dot.state.notepad",
  qflist = "dot.state.qflist",
  status = "dot.state.status",
  widget = "dot.state.widget",
}

---@class dot.state
---@field public __mods                 dot.state.__mods
---@field public maximized              dot.state.maximized
---@field public notepad                dot.state.notepad
---@field public qflist                 dot.state.qflist
---@field public status                 dot.state.status
---@field public widget                 dot.state.widget
local state = setmetatable({
  __mods = __state__mods,
}, {
  __index = function(t, k)
    local m = __state__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.widget.__mods
local __widget__mods = {
  explorer = "dot.widget.explorer",
  Notepad = "dot.widget.notepad",
}

---@class dot.widget
---@field public __mods                 dot.widget.__mods
---@field public explorer               dot.widget.explorer
---@field public Notepad                dot.widget.Notepad
local widget = setmetatable({
  __mods = __widget__mods,
}, {
  __index = function(t, k)
    local m = __widget__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.__mods
local __mods = {
  board = "dot.module.board",
  git = "dot.module.git",
  lsp = "dot.module.lsp",
  picker = "dot.module.picker",
  searcher = "dot.module.searcher",
  term = "dot.module.term",
  winpicker = "dot.module.winpicker",

  buf = "dot.buf",
  command = "dot.command",
  context = "dot.context",
  notifier = "dot.notifier",
  path = "dot.path",
  session = "dot.session",
  shell = "dot.shell",
  tab = "dot.tab",
  uri = "dot.uri",
  ux = "dot.ux",
  win = "dot.win",
}

---@class dot
---@field public __mods                 dot.__mods
---@field public board                  dot.module.board
---@field public git                    dot.module.git
---@field public lsp                    dot.module.lsp
---@field public picker                 dot.module.picker
---@field public searcher               dot.module.searcher
---@field public winpicker              dot.module.winpicker
---
---@field public command                dot.command
---@field public context                dot.context
---@field public fn                     dot.fn
---@field public notifier               dot.notifier
---@field public session                dot.session
---@field public state                  dot.state
---@field public term                   dot.term
---@field public uri                    dot.uri
---@field public ux                     dot.ux
---@field public widget                 dot.widget
---
---@field public buf                    dot.buf
---@field public path                   dot.path
---@field public shell                  dot.shell
---@field public tab                    dot.tab
---@field public win                    dot.win
---
---@field public get_default_storage    fun(): dot.context.storage
---@field public setup_breakpoints      fun(): nil
---@field public setup_context          fun(storage: dot.context.storage|nil): nil
---@field public setup_diagnostics      fun(): nil
---@field public setup_lsp              fun(): nil
local M = setmetatable({
  __mods = __mods,
  fn = fn,
  state = state,
  widget = widget,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@return dot.context.storage
function M.get_default_storage()
  local is_git_repo = M.path.is_git_repo() ---@type boolean

  ---@type dot.context.storage
  return {
    editor = M.path.locate_context_filepath("editor.json"),
    session = is_git_repo and M.path.locate_workspace_filepath("session.json") or nil,
    workspace = is_git_repo and M.path.locate_workspace_filepath("workspace.json") or nil,
    nvim_session = is_git_repo and M.path.locate_workspace_filepath("session.vim") or nil,
    nvim_session_autosaved = is_git_repo and M.path.locate_workspace_filepath("session.autosaved.vim") or nil,
  }
end

---@return nil
function M.setup_breakpoints()
  local breakpoints = M.context.lsp.breakpoints:snapshot() ---@type dot.context.lsp.IBreakpointData
  if #breakpoints < 1 then
    return
  end

  local filepath_set = {} ---@type table<string, true>
  for _, breakpoint in ipairs(breakpoints) do
    filepath_set[breakpoint.filepath] = true
  end
  local filepaths = vim.tbl_keys(filepath_set) ---@type string[]

  M.win.open_filepaths(0, filepaths)

  ark.timer.delay(function()
    local bps = require("dap.breakpoints")
    for _, breakpoint in ipairs(breakpoints) do
      local bufnr = M.buf.loadfile(breakpoint.filepath) ---@type integer|nil
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

---@param storage                       dot.context.storage|nil
---@return nil
function M.setup_context(storage)
  storage = storage or M.get_default_storage() ---@type dot.context.storage
  M.context.set_storage(storage)
  M.context.load(storage, false)

  M.context.theme.reload_theme(false, false)
end

---@return nil
function M.setup_diagnostics()
  local severity2numhl = ark.var.diagnostic.severity2numhl ---@type table<vim.diagnostic.Severity, string>
  local severity2prefixicon = ark.var.diagnostic.severity2prefixicon ---@type table<vim.diagnostic.Severity, string>
  local severity2texticon = ark.var.diagnostic.severity2texticon ---@type table<vim.diagnostic.Severity, string>

  ark.fn.observe({ M.context.lsp.diagnostics_virt_lines }, function()
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

    local enable_diagnostic_virt_lines = M.context.lsp.diagnostics_virt_lines:snapshot() ---@type boolean
    if not enable_diagnostic_virt_lines then
      config.virtual_lines = false
      config.virtual_text.current_line = nil
    end
    vim.diagnostic.config(config)
  end)
end

---@return nil
function M.setup_lsp()
  if not vim.g.vscode and M.context.flight.ai:snapshot() then
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
