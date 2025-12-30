local __module_name__ = "fml.plugin" ---@type string

---@class fml.plugin.bootstrap.conds
local conds = {
  common = function()
    return true
  end,
  disabled = function()
    return false
  end,
  ---@return boolean
  ai = function()
    return not vim.g.vscode and dot.context.flight.ai:snapshot()
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
    return not vim.g.vscode and dot.context.plugin.treesitter_context:snapshot()
  end,
}

---@type era.m.plugin.IRawSpec[]
local raw_specs = {
  -- stylua: ignore start
  { name = "blink.cmp",                   main = "blink.cmp",                     cond = conds.cmp                },
  { name = "blink.indent",                main = "blink.indent",                  cond = conds.not_vscode         },
  { name = "blink.pairs",                 main = "blink.pairs",                   cond = conds.not_vscode         },
  { name = "conform.nvim",                main = "conform",                       cond = conds.not_vscode         },
  { name = "diffview.nvim",               main = "diffview",                      cond = conds.not_vscode         },
  { name = "flash.nvim",                  main = "flash",                         cond = conds.common             },
  { name = "friendly-snippets",                                                   cond = conds.not_vscode         },
  { name = "mason.nvim",                  main = "mason",                         cond = conds.lsp                },
  { name = "mini.ai",                     main = "mini.ai",                       cond = conds.common             },
  { name = "mini.hipatterns",             main = "mini.hipatterns",               cond = conds.not_vscode         },
  { name = "mini.indentscope",            main = "mini.indentscope",              cond = conds.not_vscode         },
  { name = "mini.splitjoin",              main = "mini.splitjoin",                cond = conds.common             },
  { name = "mini.surround",               main = "mini.surround",                 cond = conds.common             },
  { name = "nvim-dap",                    main = "dap",                           cond = conds.dap                },
  { name = "nvim-dap-ui",                 main = "dapui",                         cond = conds.dap                },
  { name = "nvim-dap-virtual-text",       main = "nvim-dap-virtual-text",         cond = conds.dap                },
  { name = "nvim-lint",                   main = "lint",                          cond = conds.lsp                },
  { name = "nvim-nio",                    main = "nio",                           cond = conds.not_vscode         },
  { name = "nvim-treesitter",             main = "nvim-treesitter",               cond = conds.common             },
  { name = "nvim-treesitter-context",     main = "treesitter-context",            cond = conds.treesitter_context },
  { name = "nvim-treesitter-textobjects", main = "nvim-treesitter-textobjects",   cond = conds.common             },
  { name = "render-markdown.nvim",        main = "render-markdown",               cond = conds.not_vscode         },
  { name = "which-key.nvim",              main = "which-key",                     cond = conds.common             },
  -- stylua: ignore end
}

---@type string[]
local no_details_module_names = {
  "friendly-snippets",
  "nvim-nio",
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

  -- Load plugin details from fml.plugin.*
  local spec_module_name = "fml.plugin." .. name:gsub("%.nvim$", ""):gsub("%.lua$", ""):gsub("%.", "-"):gsub("%_", "-")
  local ok, spec_module = pcall(require, spec_module_name)
  if ok and spec_module then
    spec = vim.tbl_deep_extend("force", spec, spec_module)
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

  specs[#specs + 1] = spec
end

era.m.plugin.setup(specs)
