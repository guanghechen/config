---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.plugin" ---@type string

---@class era.plugin.bootstrap.conds
local conds = {
  common = function()
    return true
  end,
  disabled = function()
    return false
  end,
  ---@return boolean
  cmp = function()
    return not vim.g.vscode and not vim.g.yozvim
  end,
  ---@return boolean
  lsp = function()
    return not vim.g.vscode and not vim.g.yozvim
  end,
  ---@return boolean
  not_vscode = function()
    return not vim.g.vscode
  end,
  ---@return boolean
  not_yozvim = function()
    return not vim.g.yozvim
  end,
  ---@return boolean
  not_vscode_or_yozvim = function()
    return not vim.g.vscode and not vim.g.yozvim
  end,
  treesitter_context = function()
    return not vim.g.vscode and not vim.g.yozvim and dot.context.plugin.treesitter_context:snapshot()
  end,
}

---@type era.m.plugin.IRawSpec[]
local raw_specs = {
  -- stylua: ignore start
  { name = "blink.cmp",                   main = "blink.cmp",                     cond = conds.cmp                    },
  { name = "blink.indent",                main = "blink.indent",                  cond = conds.not_vscode_or_yozvim   },
  { name = "blink.pairs",                 main = "blink.pairs",                   cond = conds.not_vscode_or_yozvim   },
  { name = "conform.nvim",                main = "conform",                       cond = conds.not_vscode_or_yozvim   },
  { name = "flash.nvim",                  main = "flash",                         cond = conds.not_vscode_or_yozvim   },
  { name = "friendly-snippets",                                                   cond = conds.not_vscode_or_yozvim   },
  { name = "mason.nvim",                  main = "mason",                         cond = conds.lsp                    },
  { name = "mini.ai",                     main = "mini.ai",                       cond = conds.not_vscode_or_yozvim   },
  { name = "mini.hipatterns",             main = "mini.hipatterns",               cond = conds.not_vscode_or_yozvim   },
  { name = "nvim-lint",                   main = "lint",                          cond = conds.lsp                    },
  { name = "nvim-treesitter",             main = "nvim-treesitter",               cond = conds.not_vscode_or_yozvim   },
  { name = "nvim-treesitter-context",     main = "treesitter-context",            cond = conds.treesitter_context     },
  { name = "nvim-treesitter-textobjects", main = "nvim-treesitter-textobjects",   cond = conds.not_vscode_or_yozvim   },
  { name = "render-markdown.nvim",        main = "render-markdown",               cond = conds.not_vscode_or_yozvim   },
  -- stylua: ignore end
}

---@type string[]
local no_details_module_names = {
  "friendly-snippets",
}

---@type era.m.plugin.IPluginSpec[]
local specs = {}
for _, raw_spec in ipairs(raw_specs) do
  local url = "https://github.com/guanghechen/mirror.git" ---@type string
  local name = raw_spec.name ---@type string
  local main = raw_spec.main ---@type string|nil
  local branch = raw_spec.branch or ("nvim@" .. name) ---@type string
  local cond = raw_spec.cond ---@type fun(): boolean

  ---@type era.m.plugin.IPluginSpec
  local spec = {
    url = url,
    branch = branch,
    name = name,
    main = main,
    cond = cond,
  }

  -- Load plugin details from era.plugin.*
  if cond() then
    local spec_module_name = "era.plugin."
      .. name:gsub("%.nvim$", ""):gsub("%.lua$", ""):gsub("%.", "-"):gsub("%_", "-")
    local ok, spec_module = pcall(require, spec_module_name)
    if ok and spec_module then
      local spec_details = spec_module.spec or spec_module ---@type era.m.plugin.IPluginSpec
      spec = vim.tbl_deep_extend("force", spec, spec_details)
      spec.cond = cond
      spec.url = url
      spec.branch = branch
      spec.main = main or spec.main
    elseif not vim.list_contains(no_details_module_names, name) then
      stl.reporter.error({
        from = __module_name__,
        subject = "resolve plugin details",
        message = "Failed to resolve the details of plugin: " .. name,
        details = { basic = spec, error = spec_module },
      })
    end
  end

  specs[#specs + 1] = spec
end

era.m.plugin.setup(specs)
