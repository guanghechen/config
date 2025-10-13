local __module_name__ = "ghc.plugin" ---@type string

---@class ghc.plugin.IRawSpec
---@field public name                   string
---@field public branch                 ?string
---@field public main                   ?string
---@field public cond                   fun(): boolean

---@class ghc.plugin.ISpec
---@field public url                    string
---@field public branch                 string
---@field public name                   string
---@field public main                   ?string
---@field public cond                   fun(): boolean

---@class ghc.plugin.ISpecDetails : ghc.plugin.ISpec
---@field public cmd                    ?any
---@field public cond                   ?any
---@field public enabled                ?any
---@field public event                  ?any
---@field public lazy                   ?any

---@class ghc.plugin.bootstrap.conds
local conds = {
  common = function()
    return true
  end,
  disabled = function()
    return false
  end,
  ---@return boolean
  ai = function()
    return not vim.g.vscode and eve.context.flight.ai:snapshot()
  end,
  ---@return boolean
  cmp = function()
    return not vim.g.vscode
  end,
  ---@return boolean
  dap = function()
    return not vim.g.vscode
  end,
  ---@return boolean
  lsp = function()
    return not vim.g.vscode
  end,
  ---@return boolean
  not_vscode = function()
    return not vim.g.vscode
  end,
  treesitter_context = function()
    return not vim.g.vscode and eve.context.plugin.treesitter_context:snapshot()
  end,
}

---@type ghc.plugin.IRawSpec[]
local raw_specs = {
  -- stylua: ignore start
  { name = "blink.cmp",                   main = "blink.cmp",                     cond = conds.cmp                },
  { name = "blink.pairs",                 main = "blink.pairs",                   cond = conds.not_vscode         },
  { name = "conform.nvim",                main = "conform",                       cond = conds.not_vscode         },
  { name = "diffview.nvim",               main = "diffview",                      cond = conds.not_vscode         },
  { name = "flash.nvim",                  main = "flash",                         cond = conds.common             },
  { name = "friendly-snippets",                                                   cond = conds.not_vscode         },
  { name = "gitsigns.nvim",               main = "gitsigns",                      cond = conds.not_vscode         },
  { name = "mason.nvim",                  main = "mason",                         cond = conds.lsp                },
  { name = "mini.ai",                     main = "mini.ai",                       cond = conds.common             },
  { name = "mini.hipatterns",             main = "mini.hipatterns",               cond = conds.not_vscode         },
  { name = "mini.indentscope",            main = "mini.indentscope",              cond = conds.not_vscode         },
  { name = "mini.surround",               main = "mini.surround",                 cond = conds.common             },
  { name = "neo-tree.nvim",               main = "neo-tree",                      cond = conds.not_vscode         },
  { name = "nui.nvim",                    main = "nui",                           cond = conds.not_vscode         },
  { name = "nvim-dap",                    main = "dap",                           cond = conds.dap                },
  { name = "nvim-dap-ui",                 main = "dapui",                         cond = conds.dap                },
  { name = "nvim-dap-virtual-text",       main = "nvim-dap-virtual-text",         cond = conds.dap                },
  { name = "nvim-lint",                   main = "lint",                          cond = conds.lsp                },
  { name = "nvim-nio",                    main = "nio",                           cond = conds.not_vscode         },
  { name = "nvim-treesitter",             main = "nvim-treesitter",               cond = conds.common             },
  { name = "nvim-treesitter-context",     main = "treesitter-context",            cond = conds.treesitter_context },
  { name = "nvim-treesitter-textobjects", main = "nvim-treesitter-textobjects",   cond = conds.common             },
  { name = "plenary.nvim",                main = "plenary",                       cond = conds.common             },
  { name = "render-markdown.nvim",        main = "render-markdown",               cond = conds.not_vscode         },
  { name = "sidekick.nvim",               main = "sidekick",                      cond = conds.not_vscode         },
  { name = "which-key.nvim",              main = "which-key",                     cond = conds.common             },
  -- stylua: ignore end
}

---@type ghc.plugin.ISpec[]
local specs = {}
for _, raw_spec in ipairs(raw_specs) do
  local url = "https://github.com/guanghechen/mirror.git" ---@type string
  local name = raw_spec.name ---@type string
  local main = raw_spec.main ---@type string
  local branch = raw_spec.branch or ("nvim@" .. name) ---@type string
  local cond = raw_spec.cond ---@type fun(): boolean
  ---@type ghc.plugin.ISpec
  local spec = {
    url = url,
    branch = branch,
    name = name,
    main = main,
    cond = cond,
  }
  specs[#specs + 1] = spec
end

---extend specs------------------------------------------------------------------------------

local final_specs = {} ---@type ghc.plugin.ISpecDetails[]
for _, spec in ipairs(specs) do
  ---@type ghc.plugin.ISpecDetails
  local spec_basic = vim.tbl_deep_extend("force", {}, spec)
  final_specs[#final_specs + 1] = spec_basic
end

---@type string[]
local no_details_module_names = {
  "friendly-snippets",
  "nui.nvim",
  "nvim-nio",
  "plenary.nvim",
}

for index = 1, #specs, 1 do
  local spec_basic = final_specs[index] ---@type ghc.plugin.ISpecDetails
  local spec_module_name = "ghc.plugins."
    .. spec_basic.name:gsub("%.nvim$", ""):gsub("%.lua$", ""):gsub("%.", "-"):gsub("%_", "-")
  local ok, spec_module = pcall(require, spec_module_name)
  if ok then
    local spec_details = vim.tbl_deep_extend("force", {}, spec_basic, spec_module)
    final_specs[#final_specs + 1] = spec_details

    spec_basic.cmd = spec_details.cmd
    spec_basic.enabled = spec_details.enabled
    spec_basic.event = spec_details.event
    spec_basic.lazy = spec_details.lazy

    spec_details.cond = spec_basic.cond
    spec_details.url = spec_basic.url
    spec_details.branch = spec_basic.branch
    spec_details.main = spec_basic.main
  elseif not vim.list_contains(no_details_module_names, spec_basic.name) then
    std.reporter.error({
      from = __module_name__,
      subject = "resolve plugin details",
      message = "Failed to resolve the details of plugin: " .. spec_basic.name,
      details = { basic = spec_basic, error = spec_module },
    })
  end
end

---! bootstrap lazy and all plugins
vim.list_extend(final_specs, require("ghc.plugins._extra"))

local lazypath = std.path.normalize(std.env.HOME_NVIM_DATA .. "/lazy/lazy.nvim")
if not std.path.is_exist(std.path.join(lazypath, ".git")) then
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
  git = {
    timeout = 60 * 60 * 24, -- 24h
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = vim.tbl_filter(function(v)
        return type(v) == "string" and #v > 0
      end, {
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
        (std.env.IS_WIN or std.env.IS_MAC) and "osc52" or nil,
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
      }),
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
