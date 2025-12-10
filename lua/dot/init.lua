local __module_name__ = "dot" ---@type string

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

---@class dot.theme
---@field public hlgroup                dot.theme.hlgroup
---@field public scheme                 dot.theme.scheme
local theme = {
  hlgroup = hlgroup,
  scheme = scheme,
}

----------------------------------------------------------------------------------------------------

---@class dot.state.__mods
local __state__mods = {
  qflist = "dot.state.qflist",
  status = "dot.state.status",
  widget = "dot.state.widget",
}

---@class dot.state
---@field public __mods                 dot.state.__mods
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

---@class dot.__mods
local __mods = {
  command = "dot.command",
  env = "dot.env",
  fileicon = "dot.fileicon",
  filetype = "dot.filetype",
  icon = "dot.icon",
  var = "dot.var",
}

---@class dot
---@field public __mods                 dot.__mods
---@field public dict                   dot.dict
---@field public lang                   dot.lang
---@field public state                  dot.state
---@field public theme                  dot.theme
---
---@field public command                dot.command
---@field public env                    dot.env
---@field public fileicon               dot.fileicon
---@field public filetype               dot.filetype
---@field public icon                   dot.icon
---@field public var                    dot.var
local M = setmetatable({
  __mods = __mods,
  dict = dict,
  lang = lang,
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

----------------------------------------------------------------------------------------------------

---@return nil
function M.setup_patches()
  table.unpack = table.unpack or unpack --- table.unpack is introduced in Lua 5.2
  table.clear = table.clear or function(map)
    for k in pairs(map) do
      map[k] = nil
    end
  end
end

---! Auto cd the directory:
---! 1. the opened file is under a git repo, let's remember the the git repo path as A,
---!    and assume the git repo directory of the shell cwd is B.
---!      a) If A is different from B, then auto cd the A.
---!      b) If A is the same as B, then no action needed.
---! 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
---@return nil
function M.setup_workspace()
  local INITIAL_FILEPATH = vim.fn.expand("%") ---@type string
  if INITIAL_FILEPATH ~= "" then
    local cwd = vim.uv.cwd() or vim.fn.getcwd() ---@type string
    local p = vim.fn.expand("%:p:h")

    local env = require("dot.env")
    local A = env.locate_gitroot(p)
    local B = env.locate_gitroot(cwd)

    if A == nil then
      local ok, err = pcall(function()
        yoz.path.set_cwd(p)
        vim.api.nvim_set_current_dir(p)
      end)
      if not ok then
        local message = "Failed to change directory to file directory" ---@type string
        local details = { path = p, error = err } ---@type table
        message = message .. "\n\n" .. "```json\n" .. vim.inspect(details, { newline = "\n" }) .. "\n```" ---@type string

        vim.schedule(function()
          vim.notify(message, vim.log.levels.WARN, {
            group = nil,
            title = string.format("%s | %s", __module_name__, "setup_workspace"),
            timeout = 3000,
            message = message,
            anonymous = false,
            silent = false,
          })
        end)
      end
    elseif A ~= B then
      local ok, err = pcall(function()
        vim.api.nvim_set_current_dir(A)
      end)
      if not ok then
        local message = "Failed to change directory to git repo" ---@type string
        local details = { repopath = A, error = err } ---@type table
        message = message .. "\n\n" .. "```json\n" .. vim.inspect(details, { newline = "\n" }) .. "\n```" ---@type string

        vim.schedule(function()
          vim.notify(message, vim.log.levels.WARN, {
            group = nil,
            title = string.format("%s | %s", __module_name__, "setup_workspace"),
            timeout = 3000,
            message = message,
            anonymous = false,
            silent = false,
          })
        end)
      end
    end
  end

  ---! Clear jumplist. See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
  vim.schedule(function()
    vim.cmd("clearjumps")
  end)
end

return M
