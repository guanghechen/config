---@see https://github.com/nvim-treesitter/nvim-treesitter/tree/c5871d9d870c866fea9f271f1a3b3f29049a4793

local __module_name__ = "era.plugin.nvim-treesitter" ---@type string

----------------------------------------------------------------------------------------------------

---@type string[]
local ensure_filetypes = {
  "bash",
  "c",
  "cc",
  "cpp",
  "css",
  "cxx",
  "diff",
  "dockerfile",
  "fish",
  "gitcommit",
  "gitconfig",
  "gitignore",
  "gitrebase",
  "glsl",
  "go",
  "gomod",
  "gosum",
  "htm",
  "html",
  "javascript",
  "json",
  "json5",
  "js",
  "jsx",
  "less",
  "lua",
  "make",
  "makefile",
  "markdown",
  "md",
  "ninja",
  "notepad",
  "py",
  "python",
  "query",
  "rs",
  "rst",
  "rust",
  "scss",
  "sh",
  "sql",
  "svelte",
  "tex",
  "toml",
  "ts",
  "tsx",
  "typescript",
  "typescriptreact",
  "vim",
  "xml",
  "yaml",
  "yml",
  "zsh",
}

---@type string[]
local ensure_installed = {
  "bash",
  "c",
  "cpp",
  "css",
  "diff",
  "dockerfile",
  "fish",
  "git_config",
  "git_rebase",
  "gitcommit",
  "gitignore",
  "gitattributes",
  "glsl",
  "go",
  "gomod",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "json5",
  "latex",
  "lua",
  "luadoc",
  "luap",
  "make",
  "markdown",
  "markdown_inline",
  "ninja",
  "rst",
  "python",
  "query",
  "regex",
  "rust",
  "sql",
  "svelte",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "xml",
  "yaml",
}

---@param subject                       string
---@param callback                      fun(): nil
---@return nil
local function install(subject, callback)
  if vim.fn.executable("tree-sitter") == 1 then
    callback()
    return
  end

  if not pcall(require, "mason") then
    stl.reporter.error({
      from = __module_name__,
      subject = subject,
      message = "Mason is enabled",
    })
    return
  end

  -- check again since we might have installed it already
  if vim.fn.executable("tree-sitter") == 1 then
    callback()
    return
  end

  local mr = require("mason-registry")
  mr.refresh(function()
    local p = mr.get_package("tree-sitter-cli")
    if not p:is_installed() then
      stl.reporter.info({
        from = __module_name__,
        subject = subject,
        message = "Installing `tree-sitter-cli` with `mason.nvim`...",
      })

      p:install(
        nil,
        vim.schedule_wrap(function(success)
          if success then
            stl.reporter.info({
              from = __module_name__,
              subject = subject,
              message = "Installed `tree-sitter-cli` with `mason.nvim`.",
            })
            callback()
          else
            stl.reporter.error({
              from = __module_name__,
              subject = subject,
              message = "**treesitter-main** requires the `tree-sitter` executable to be installed",
            })
          end
        end)
      )
    end
  end)
end

---@param node                          TSNode
---@return TSNode|nil
local function find_conditional_node(node)
  local node_type = node:type() ---@type string
  if node_type == "ternary_expression" or node_type == "if_statement" then
    return node
  end

  local parent = node:parent()
  return parent and find_conditional_node(parent)
end

---@return nil
local function action_swap_next_parameter()
  require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
end

---@return nil
local function action_swap_prev_parameter()
  require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
end

---@return nil
local function action_swap_conditional_branches()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr_sourcefile })
  local lang = vim.treesitter.language.get_lang(filetype)
  if not lang or not pcall(vim.treesitter.language.inspect, lang) then
    stl.reporter.error({
      from = __module_name__,
      subject = "swap conditional branches",
      message = "No treesitter parser for current language",
    })
    return
  end

  local node = vim.treesitter.get_node({ bufnr = bufnr_sourcefile })
  local conditional_node = node and find_conditional_node(node)
  if not conditional_node then
    return
  end

  local consequence = conditional_node:field("consequence")[1]
  local alternate = conditional_node:field("alternative")[1]
  if consequence == nil or alternate == nil then
    return
  end

  if consequence:type() == "statement_block" then
    consequence = consequence:child(1) or consequence
  end
  if alternate:type() == "else_clause" or alternate:type() == "else_statement" then
    alternate = alternate:child(1) or alternate
  end
  if alternate:type() == "statement_block" then
    alternate = alternate:child(1) or alternate
  end

  local csr, csc, cer, cec = consequence:range() ---@type integer, integer, integer, integer
  local asr, asc, aer, aec = alternate:range() ---@type integer, integer, integer, integer

  ---@type string
  local consequence_text = table.concat(vim.api.nvim_buf_get_text(bufnr_sourcefile, csr, csc, cer, cec, {}), "\n")

  ---@type string
  local alternate_text = table.concat(vim.api.nvim_buf_get_text(bufnr_sourcefile, asr, asc, aer, aec, {}), "\n")

  ---@type string
  local middle_text = table.concat(vim.api.nvim_buf_get_text(bufnr_sourcefile, cer, cec, asr, asc, {}), "\n")

  local text = alternate_text .. middle_text .. consequence_text ---@type string
  local lines = vim.split(text, "\n", { plain = true }) ---@type string[]
  vim.api.nvim_buf_set_text(bufnr_sourcefile, csr, csc, aer, aec, lines)
end

----------------------------------------------------------------------------------------------------

---@class era.plugin.nvim_treesitter
---@field public swap_conditional_branches fun(): nil
---@field public swap_next_parameter      fun(): nil
---@field public swap_prev_parameter      fun(): nil
local M = {
  swap_conditional_branches = action_swap_conditional_branches,
  swap_next_parameter = action_swap_next_parameter,
  swap_prev_parameter = action_swap_prev_parameter,
}

----------------------------------------------------------------------------------------------------

---@type era.m.plugin.IPluginSpec
M.spec = {
  name = "nvim-treesitter",
  lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
  event = "VeryLazy",
  cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
  build = function()
    install("build", function()
      local treesitter = require("nvim-treesitter")
      treesitter.update(nil, { summary = true })
    end)
  end,
  opts = {
    folds = { enable = true },
    highlight = { enable = true },
    indent = { enable = true },
    install_dir = dot.path.locate_data_filepath("treesitter"),
  },
  config = function(_, opts)
    require("nvim-treesitter").setup(opts)
    vim.api.nvim_create_user_command("TreesitterInstallAll", function()
      install("setup", function()
        require("nvim-treesitter").install(ensure_installed, { summary = true })
      end)
    end, {})

    vim.treesitter.language.register("json", "excalidraw")
    vim.treesitter.language.register("json", "jsonc")
    vim.api.nvim_create_autocmd("FileType", {
      pattern = ensure_filetypes,
      callback = function()
        vim.treesitter.start()
        vim.api.nvim_set_option_value("foldexpr", "v:lua.vim.treesitter.foldexpr()", { win = 0, scope = "local" })
        vim.api.nvim_set_option_value("indentexpr", "v:lua.require'nvim-treesitter'.indentexpr()", { buf = 0 })
      end,
    })
  end,
  dependencies = {
    "nvim-treesitter-textobjects",
  },
}

return M
