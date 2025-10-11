local __module_name__ = "ghc.plugin.nvim-treesitter" ---@type string

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
  "go",
  "gomod",
  "gosum",
  "htm",
  "html",
  "javascript",
  "json",
  "json5",
  "jsonc",
  "js",
  "jsx",
  "less",
  "lua",
  "make",
  "makefile",
  "markdown",
  "md",
  "ninja",
  "py",
  "python",
  "query",
  "rs",
  "rst",
  "rust",
  "scss",
  "sh",
  "sql",
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
  "go",
  "gomod",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "json5",
  "jsonc",
  -- "latex",
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
    std.reporter.error({
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
      std.reporter.info({
        from = __module_name__,
        subject = subject,
        message = "Installing `tree-sitter-cli` with `mason.nvim`...",
      })

      p:install(
        nil,
        vim.schedule_wrap(function(success)
          if success then
            std.reporter.info({
              from = __module_name__,
              subject = subject,
              message = "Installed `tree-sitter-cli` with `mason.nvim`.",
            })
            callback()
          else
            std.reporter.error({
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

-- Treesitter is a new parser generator tool that we can
-- use in Neovim to power faster and more accurate
-- syntax highlighting.
return {
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
    install_dir = std.path.locate_data_filepath("treesitter"),
  },
  config = function(_, opts)
    if vim.fn.executable("tree-sitter") == 0 then
      std.reporter.error({
        from = __module_name__,
        subject = "config",
        message = "**treesitter-main** requires the `tree-sitter` executable to be installed",
      })
      return
    end

    require("nvim-treesitter").setup(opts)
    vim.api.nvim_create_user_command("TreesitterInstallAll", function()
      install("setup", function()
        local treesitter = require("nvim-treesitter")
        treesitter.install(ensure_installed, { summary = true })
      end)
      require("nvim-treesitter").install(ensure_installed)
    end, {})

    vim.treesitter.language.register("json", "excalidraw")
    vim.api.nvim_create_autocmd("FileType", {
      pattern = ensure_filetypes,
      callback = function()
        vim.treesitter.start()
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
  dependencies = {
    "nvim-treesitter-textobjects",
  },
}
