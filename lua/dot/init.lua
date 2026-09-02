---@class dot.state.__mods
local __state__mods = {
  maximized = "dot.state.maximized",
  qflist = "dot.state.qflist",
  status = "dot.state.status",
  widget = "dot.state.widget",
}

---@class dot.state
---@field public __mods                 dot.state.__mods
---@field public maximized              dot.state.maximized
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

---@class dot.theme.scheme.__mods
local theme_scheme__mods = {
  ["catppuccin-frappe"] = "dot.theme.scheme.catppuccin-frappe",
  ["catppuccin-latte"] = "dot.theme.scheme.catppuccin-latte",
  ["catppuccin-macchiato"] = "dot.theme.scheme.catppuccin-macchiato",
  ["catppuccin-mocha"] = "dot.theme.scheme.catppuccin-mocha",
  ["gruvbox-dark"] = "dot.theme.scheme.gruvbox-dark",
  ["gruvbox-light"] = "dot.theme.scheme.gruvbox-light",
  ["kanagawa-dragon"] = "dot.theme.scheme.kanagawa-dragon",
  ["kanagawa-lotus"] = "dot.theme.scheme.kanagawa-lotus",
  ["kanagawa-wave"] = "dot.theme.scheme.kanagawa-wave",
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
---@field public ["catppuccin-frappe"]  stl.t.theme.IScheme
---@field public ["catppuccin-latte"]   stl.t.theme.IScheme
---@field public ["catppuccin-macchiato"] stl.t.theme.IScheme
---@field public ["catppuccin-mocha"]   stl.t.theme.IScheme
---@field public ["gruvbox-dark"]       stl.t.theme.IScheme
---@field public ["gruvbox-light"]      stl.t.theme.IScheme
---@field public ["kanagawa-dragon"]    stl.t.theme.IScheme
---@field public ["kanagawa-lotus"]     stl.t.theme.IScheme
---@field public ["kanagawa-wave"]      stl.t.theme.IScheme
---@field public ["rosepine-dawn"]      stl.t.theme.IScheme
---@field public ["rosepine-main"]      stl.t.theme.IScheme
---@field public ["rosepine-moon"]      stl.t.theme.IScheme
---@field public ["tokyonight-day"]     stl.t.theme.IScheme
---@field public ["tokyonight-moon"]    stl.t.theme.IScheme
---@field public ["tokyonight-night"]   stl.t.theme.IScheme
---@field public ["tokyonight-storm"]   stl.t.theme.IScheme
---@field public ["vsc-dark-modern"]    stl.t.theme.IScheme
---@field public ["vsc-light-modern"]   stl.t.theme.IScheme
local theme_scheme = setmetatable({ __mods = theme_scheme__mods }, {
  __index = function(t, k)
    local m = theme_scheme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@class dot.theme.hlgroup.__mods
local theme_hlgroup__mods = {
  basic = "dot.theme.hlgroup.basic",
  common = "dot.theme.hlgroup.common",
  lsp = "dot.theme.hlgroup.lsp",
  module = "dot.theme.hlgroup.module",
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
---@field public module                 dot.theme.hlgroup.module
---@field public nvimbar                dot.theme.hlgroup.nvimbar
---@field public plugin                 dot.theme.hlgroup.plugin
---@field public treesitter             dot.theme.hlgroup.treesitter
---@field public widget                 dot.theme.hlgroup.widget
local theme_hlgroup = setmetatable({ __mods = theme_hlgroup__mods }, {
  __index = function(t, k)
    local m = theme_hlgroup__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@class dot.theme.__mods
local theme__mods = {}

---@class dot.theme
---@field public __mods                 dot.theme.__mods
---@field public hlgroup                dot.theme.hlgroup
---@field public scheme                 dot.theme.scheme
local theme = setmetatable({
  __mods = theme__mods,
  hlgroup = theme_hlgroup,
  scheme = theme_scheme,
}, {
  __index = function(t, k)
    local m = theme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.__mods
local __mods = {
  buf = "dot.buf",
  command = "dot.command",
  context = "dot.context",
  G = "dot.G",
  path = "dot.path",
  session = "dot.session",
  tab = "dot.tab",
  uri = "dot.uri",
  var = "dot.var",
  win = "dot.win",
}

---@class dot
---@field public __mods                 dot.__mods
---
---@field public command                dot.command
---@field public context                dot.context
---@field public G                      dot.G
---@field public session                dot.session
---@field public state                  dot.state
---@field public theme                  dot.theme
---@field public uri                    dot.uri
---
---@field public buf                    dot.buf
---@field public path                   dot.path
---@field public tab                    dot.tab
---@field public var                    dot.var
---@field public win                    dot.win
---
---@field public get_default_storage    fun(): dot.context.storage
---@field public setup_context          fun(storage: dot.context.storage|nil): nil
---@field public setup_diagnostics      fun(): nil
local M = setmetatable({
  __mods = __mods,
  state = state,
  theme = theme,
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

---@param storage                       dot.context.storage|nil
---@return nil
function M.setup_context(storage)
  storage = storage or M.get_default_storage() ---@type dot.context.storage
  M.context.set_storage(storage)
  M.context.load(storage, false)

  M.context.theme.reload_theme()
end

---@return nil
function M.setup_diagnostics()
  local severity2numhl = dot.var.diagnostic.severity2numhl ---@type table<vim.diagnostic.Severity, string>
  local severity2prefixicon = dot.var.diagnostic.severity2prefixicon ---@type table<vim.diagnostic.Severity, string>
  local severity2texticon = dot.var.diagnostic.severity2texticon ---@type table<vim.diagnostic.Severity, string>

  stl.fn.observe({ M.context.lsp.diagnostics_virt_lines }, function()
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

return M
