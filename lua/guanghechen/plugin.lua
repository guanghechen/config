---@class guanghechen.plugin.IRawSpec
---@field public name                   string
---@field public branch                 ?string
---@field public main                   ?string
---@field public cond                   fun(): boolean

---@class guanghechen.plugin.ISpec
---@field public url                    string
---@field public branch                 string
---@field public name                   string
---@field public main                   ?string
---@field public cond                   fun(): boolean

---@class guanghechen.plugin.ISpecDetails : guanghechen.plugin.ISpec
---@field public cmd                    ?any
---@field public cond                   ?any
---@field public enabled                ?any
---@field public event                  ?any
---@field public lazy                   ?any

---@class guanghechen.plugin.bootstrap.conds
local conds = {
  ---@return boolean
  not_vscode = function()
    return not vim.g.vscode
  end,
  ---@return boolean
  copilot = function()
    return not vim.g.vscode and eve.context.state.flight.copilot:snapshot()
  end,
  common = function()
    return true
  end,
}

---@type guanghechen.plugin.IRawSpec[]
local raw_specs = {
  { name = "cmp-buffer", main = "cmp_buffer", cond = conds.not_vscode },
  { name = "cmp-nvim-lsp", main = "cmp_nvim_lsp", cond = conds.not_vscode },
  { name = "cmp-path", main = "cmp_path", cond = conds.not_vscode },
  { name = "conform.nvim", main = "conform", cond = conds.not_vscode },
  { name = "copilot.lua", main = "copilot", cond = conds.copilot },
  { name = "copilot-cmp", main = "copilot_cmp", cond = conds.copilot },
  { name = "diffview.nvim", main = "diffview", cond = conds.not_vscode },
  { name = "dressing.nvim", main = "dressing", cond = conds.not_vscode },
  { name = "flash.nvim", main = "flash", cond = conds.not_vscode },
  { name = "friendly-snippets", cond = conds.not_vscode },
  { name = "gitsigns.nvim", main = "gitsigns", cond = conds.not_vscode },
  { name = "indent-blankline.nvim", main = "ibl", cond = conds.not_vscode },
  { name = "mason.nvim", main = "mason", cond = conds.not_vscode },
  { name = "mason-lspconfig.nvim", main = "mason-lspconfig", cond = conds.not_vscode },
  { name = "mini.comment", main = "mini.comment", cond = conds.not_vscode },
  { name = "mini.icons", main = "mini.icons", cond = conds.not_vscode },
  { name = "mini.indentscope", main = "mini.indentscope", cond = conds.not_vscode },
  { name = "mini.pairs", main = "mini.pairs", cond = conds.not_vscode },
  { name = "mini.surround", main = "mini.surround", cond = conds.common },
  { name = "neo-tree.nvim", main = "neo-tree", cond = conds.not_vscode },
  { name = "noice.nvim", main = "noice", cond = conds.not_vscode },
  { name = "nui.nvim", main = "nui", cond = conds.not_vscode },
  { name = "nvim-cmp", main = "cmp", cond = conds.not_vscode },
  { name = "nvim-colorizer.lua", main = "colorizer", cond = conds.not_vscode },
  { name = "nvim-lspconfig", main = "lspconfig", cond = conds.not_vscode },
  { name = "nvim-notify", main = "notify", cond = conds.not_vscode },
  { name = "nvim-snippets", main = "snippets", cond = conds.not_vscode },
  { name = "nvim-treesitter", main = "nvim-treesitter", cond = conds.not_vscode },
  { name = "nvim-treesitter-context", main = "treesitter-context", cond = conds.not_vscode },
  { name = "nvim-treesitter-textobjects", main = "nvim-treesitter-textobjects", cond = conds.not_vscode },
  { name = "nvim-window-picker", main = "window-picker", cond = conds.not_vscode },
  { name = "plenary.nvim", main = "plenary", cond = conds.not_vscode },
  { name = "trouble.nvim", main = "trouble", cond = conds.not_vscode },
  { name = "vim-illuminate", main = "illuminate", cond = conds.not_vscode },
  { name = "which-key.nvim", main = "which-key", cond = conds.not_vscode },
}

---@type guanghechen.plugin.ISpec[]
local specs = {}
for _, raw_spec in ipairs(raw_specs) do
  local url = "https://github.com/guanghechen/mirror.git" ---@type string
  local name = raw_spec.name ---@type string
  local main = raw_spec.main ---@type string
  local branch = raw_spec.branch or ("nvim@" .. name) ---@type string
  local cond = raw_spec.cond ---@type fun(): boolean
  ---@type guanghechen.plugin.ISpec
  local meta = {
    url = url,
    branch = branch,
    name = name,
    main = main,
    cond = cond,
  }
  table.insert(specs, meta)
end

---extend specs------------------------------------------------------------------------------

local final_specs = {} ---@type guanghechen.plugin.ISpecDetails[]
for _, spec in ipairs(specs) do
  ---@type guanghechen.plugin.ISpecDetails
  local spec_basic = vim.tbl_deep_extend("force", {}, spec)
  table.insert(final_specs, spec_basic)
end

---@type string[]
local no_details_module_names = {
  "cmp-buffer", --
  "cmp-nvim-lsp",
  "cmp-path",
  "friendly-snippets",
  "mason-lspconfig.nvim",
  "nui.nvim",
  "plenary.nvim",
}

for index = 1, #specs, 1 do
  local spec_basic = final_specs[index] ---@type guanghechen.plugin.ISpecDetails
  local spec_module_name = "guanghechen.plugins."
    .. spec_basic.name:gsub("%.nvim$", ""):gsub("%.lua$", ""):gsub("%.", "-"):gsub("%_", "-")
  local ok, spec_module = pcall(require, spec_module_name)
  if ok then
    local spec_details = vim.tbl_deep_extend("force", {}, spec_basic, spec_module)
    table.insert(final_specs, spec_details)

    spec_basic.cmd = spec_details.cmd
    spec_basic.enabled = spec_details.enabled
    spec_basic.event = spec_details.event
    spec_basic.lazy = spec_details.lazy

    spec_details.cond = spec_basic.cond
    spec_details.url = spec_basic.url
    spec_details.branch = spec_basic.branch
    spec_details.main = spec_basic.main
  elseif not eve.array.contains(no_details_module_names, spec_basic.name) then
    eve.reporter.error({
      from = "guanghechen.plugin.bootstrap",
      subject = "resolve plugin details",
      message = "Failed to resolve the details of plugin: " .. spec_basic.name,
    })
  end
end

---! bootstrap lazy and all plugins
local lazypath = eve.path.normalize(eve.path.HOME_NVIM_DATA .. "/lazy/lazy.nvim")
if not eve.path.is_exist(lazypath) then
  local repo = "https://github.com/guanghechen/mirror"
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    repo,
    "--single-branch",
    "--branch=nvim@ghc-lazy.nvim",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
vim.env.LAZY_PATH = lazypath
require("lazy").setup({
  spec = final_specs,
  defaults = {
    lazy = true,
  },
  install = {
    colorscheme = {},
  },
  checker = {
    enabled = false, -- set true to automatically check for plugin updates
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "2html_plugin",
        "bugreport",
        "compiler",
        "ftplugin",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "matchit",
        "matchparen",
        "netrw",
        "netrwFileHandlers",
        "netrwPlugin",
        "netrwSettings",
        "optwin",
        "rplugin",
        "rrhelper",
        "spellfile_plugin",
        "synmenu",
        "syntax",
        "tar",
        "tarPlugin",
        "tohtml",
        "tutor",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
      },
    },
  },
  ui = {
    icons = {
      ft = "",
      lazy = "󰂠 ",
      loaded = "",
      not_loaded = "",
    },
  },
})
