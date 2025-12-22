---@class dot.fn.__mods
local __fn__mods = {
  add_locations_to_ai = "dot.fn.add_locations_to_ai",
  paste_image = "dot.fn.paste_image",
  paste_image_as_base64 = "dot.fn.paste_image_as_base64",
  pick_win = "dot.fn.pick_win",
  rename = "dot.fn.rename",
  select_copy_filepath = "dot.fn.select_copy_filepath",
  select_copy_filepaths = "dot.fn.select_copy_filepaths",
  select_encoding = "dot.fn.select_encoding",
}

---@class dot.fn
---@field public __mods                 dot.fn.__mods
---@field public add_locations_to_ai    fun(locations: dot.t.ILocation[]): nil
---@field public paste_image            fun(): nil
---@field public paste_image_as_base64  fun(): string|nil
---@field public pick_win               dot.fn.pick_win
---@field public rename                 dot.fn.rename
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

---@class dot.dict.__mods
local __dict__mods = {
  en = "dot.dict.en",
}

---@class dot.dict
---@field public __mods                 dot.dict.__mods
---@field public en                     { [1]: string, [2]: string }[]
local dict = setmetatable({
  __mods = __dict__mods,
}, {
  __index = function(t, k)
    local m = __dict__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.lang.__mods
local __lang__mods = {
  python = "dot.lang.python",
  tailwind = "dot.lang.tailwind",
}

---@class dot.lang
---@field public __mods                 dot.lang.__mods
---@field public python                 dot.lang.python
---@field public tailwind               dot.lang.tailwind
local lang = setmetatable({
  __mods = __lang__mods,
}, {
  __index = function(t, k)
    local m = __lang__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.theme.hlgroup.__mods
local __theme_hlgroup__mods = {
  basic = "dot.theme.hlgroup.basic",
  common = "dot.theme.hlgroup.common",
  lsp = "dot.theme.hlgroup.lsp",
  nvimbar = "dot.theme.hlgroup.nvimbar",
  plugin = "dot.theme.hlgroup.plugin",
  treesitter = "dot.theme.hlgroup.treesitter",
  widget = "dot.theme.hlgroup.widget",
}

---@class dot.theme.hlgroup
---@field public __mods                 dot.theme.hlgroup.__mods
---@field public basic                  dot.theme.hlgroup.basic
---@field public common                 dot.theme.hlgroup.common
---@field public lsp                    dot.theme.hlgroup.lsp
---@field public nvimbar                dot.theme.hlgroup.nvimbar
---@field public plugin                 dot.theme.hlgroup.plugin
---@field public treesitter             dot.theme.hlgroup.treesitter
---@field public widget                 dot.theme.hlgroup.widget
local hlgroup = setmetatable({
  __mods = __theme_hlgroup__mods,
}, {
  __index = function(t, k)
    local m = __theme_hlgroup__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.theme.scheme.__mods
local __theme_scheme__mods = {
  ["catppuccin-frappe"] = "dot.theme.scheme.catppuccin-frappe",
  ["catppuccin-latte"] = "dot.theme.scheme.catppuccin-latte",
  ["catppuccin-macchiato"] = "dot.theme.scheme.catppuccin-macchiato",
  ["catppuccin-mocha"] = "dot.theme.scheme.catppuccin-mocha",
  ["gruvbox-dark"] = "dot.theme.scheme.gruvbox-dark",
  ["gruvbox-light"] = "dot.theme.scheme.gruvbox-light",
  ["nord"] = "dot.theme.scheme.nord",
  ["onehalf-dark"] = "dot.theme.scheme.onehalf-dark",
  ["onehalf-light"] = "dot.theme.scheme.onehalf-light",
  ["rosepine-dawn"] = "dot.theme.scheme.rosepine-dawn",
  ["rosepine-main"] = "dot.theme.scheme.rosepine-main",
  ["rosepine-moon"] = "dot.theme.scheme.rosepine-moon",
  ["tokyonight-day"] = "dot.theme.scheme.tokyonight-day",
  ["tokyonight-moon"] = "dot.theme.scheme.tokyonight-moon",
  ["tokyonight-night"] = "dot.theme.scheme.tokyonight-night",
  ["tokyonight-storm"] = "dot.theme.scheme.tokyonight-storm",
  ["vsc-dark-modern"] = "dot.theme.scheme.vsc-dark-modern",
  ["vsc-light-modern"] = "dot.theme.scheme.vsc-light-modern",
}

---@class dot.theme.scheme
---@field public __mods                 dot.theme.scheme.__mods
---@field public ["catppuccin-frappe"]  dot.t.theme.IScheme
---@field public ["catppuccin-latte"]   dot.t.theme.IScheme
---@field public ["catppuccin-macchiato"] dot.t.theme.IScheme
---@field public ["catppuccin-mocha"]   dot.t.theme.IScheme
---@field public ["gruvbox-dark"]       dot.t.theme.IScheme
---@field public ["gruvbox-light"]      dot.t.theme.IScheme
---@field public ["nord"]               dot.t.theme.IScheme
---@field public ["onehalf-dark"]       dot.t.theme.IScheme
---@field public ["onehalf-light"]      dot.t.theme.IScheme
---@field public ["rosepine-dawn"]      dot.t.theme.IScheme
---@field public ["rosepine-main"]      dot.t.theme.IScheme
---@field public ["rosepine-moon"]      dot.t.theme.IScheme
---@field public ["tokyonight-day"]     dot.t.theme.IScheme
---@field public ["tokyonight-moon"]    dot.t.theme.IScheme
---@field public ["tokyonight-night"]   dot.t.theme.IScheme
---@field public ["tokyonight-storm"]   dot.t.theme.IScheme
---@field public ["vsc-dark-modern"]    dot.t.theme.IScheme
---@field public ["vsc-light-modern"]   dot.t.theme.IScheme
local scheme = setmetatable({
  __mods = __theme_scheme__mods,
}, {
  __index = function(t, k)
    local m = __theme_scheme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.theme.__mods
local __theme__mods = {
  Namespace = "dot.theme.namespace",
}

---@class dot.theme
---@field public __mods                 dot.theme.__mods
---@field public hlgroup                dot.theme.hlgroup
---@field public scheme                 dot.theme.scheme
---@field public Namespace              dot.theme.Namespace
local theme = setmetatable({
  __mods = __theme__mods,
  hlgroup = hlgroup,
  scheme = scheme,
}, {
  __index = function(t, k)
    local m = __theme__mods[k] ---@type string|nil
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
  Terminal = "dot.widget.terminal",
}

---@class dot.widget
---@field public __mods                 dot.widget.__mods
---@field public explorer               dot.widget.explorer
---@field public Notepad                dot.widget.Notepad
---@field public Terminal               dot.widget.Terminal
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
  picker = "dot.module.picker",
  searcher = "dot.module.searcher",
  tree = "dot.module.tree",

  G = "dot.G",
  buf = "dot.buf",
  command = "dot.command",
  context = "dot.context",
  fileicon = "dot.fileicon",
  filetype = "dot.filetype",
  icon = "dot.icon",
  lsp = "dot.lsp",
  lsp_action = "dot.lsp_action",
  notifier = "dot.notifier",
  path = "dot.path",
  session = "dot.session",
  shell = "dot.shell",
  tab = "dot.tab",
  term = "dot.term",
  uri = "dot.uri",
  ux = "dot.ux",
  var = "dot.var",
  view = "dot.view",
  win = "dot.win",
}

---@class dot
---@field public __mods                 dot.__mods
---@field public board                  dot.module.board
---@field public git                    dot.module.git
---@field public picker                 dot.module.picker
---@field public searcher               dot.module.searcher
---@field public tree                   dot.module.tree
---
---@field public command                dot.command
---@field public context                dot.context
---@field public dict                   dot.dict
---@field public fn                     dot.fn
---@field public lang                   dot.lang
---@field public lsp                    dot.lsp
---@field public lsp_action             dot.lsp_action
---@field public notifier               dot.notifier
---@field public session                dot.session
---@field public state                  dot.state
---@field public term                   dot.term
---@field public theme                  dot.theme
---@field public uri                    dot.uri
---@field public ux                     dot.ux
---@field public view                   dot.view
---@field public widget                 dot.widget
---
---@field public G                      dot.G
---@field public buf                    dot.buf
---@field public fileicon               dot.fileicon
---@field public filetype               dot.filetype
---@field public icon                   dot.icon
---@field public path                   dot.path
---@field public shell                  dot.shell
---@field public tab                    dot.tab
---@field public var                    dot.var
---@field public win                    dot.win
---
---@field public get_default_storage    fun(): dot.context.storage
---@field public setup_breakpoints      fun(): nil
---@field public setup_context          fun(storage: dot.context.storage|nil): nil
---@field public setup_diagnostics      fun(): nil
---@field public setup_lsp              fun(): nil
local M = setmetatable({
  __mods = __mods,
  dict = dict,
  fn = fn,
  lang = lang,
  state = state,
  theme = theme,
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

  local colorscheme = M.context.theme.theme:snapshot() ---@type dot.e.ThemeFullName
  vim.cmd.colorscheme(colorscheme)
end

---@return nil
function M.setup_diagnostics()
  local severity2numhl = M.var.diagnostic.severity2numhl ---@type table<vim.diagnostic.Severity, string>
  local severity2prefixicon = M.var.diagnostic.severity2prefixicon ---@type table<vim.diagnostic.Severity, string>
  local severity2texticon = M.var.diagnostic.severity2texticon ---@type table<vim.diagnostic.Severity, string>

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
