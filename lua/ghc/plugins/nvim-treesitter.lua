local __module_name__ = "ghc.plugin.nvim-treesitter" ---@type string

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

local opts = {
  install_dir = std.path.locate_data_filepath("treesitter"),
}

-- Treesitter is a new parser generator tool that we can
-- use in Neovim to power faster and more accurate
-- syntax highlighting.
return {
  name = "nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  opts = opts,
  config = function()
    if vim.fn.executable("tree-sitter") == 0 then
      std.reporter.error({
        from = __module_name__,
        subject = "pre-check",
        message = "**treesitter-main** requires the `tree-sitter` executable to be installed",
      })
      return
    end

    require("nvim-treesitter").setup(opts)

    vim.api.nvim_create_user_command("TreesitterInstallAll", function()
      require("nvim-treesitter").install(ensure_installed)
    end, {})

    vim.treesitter.language.register("json", "excalidraw")
    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "bash",
        "sh",
        "zsh",
        "c",
        "cpp",
        "cc",
        "cxx",
        "css",
        "scss",
        "less",
        "diff",
        "dockerfile",
        "fish",
        "gitconfig",
        "gitrebase",
        "gitcommit",
        "gitignore",
        "go",
        "gomod",
        "gosum",
        "html",
        "htm",
        "javascript",
        "js",
        "jsx",
        "json",
        "json5",
        "jsonc",
        "lua",
        "make",
        "makefile",
        "markdown",
        "md",
        "ninja",
        "rst",
        "python",
        "py",
        "query",
        "rust",
        "rs",
        "sql",
        "toml",
        "typescript",
        "ts",
        "tsx",
        "typescriptreact",
        "vim",
        "xml",
        "yaml",
        "yml",
      },
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
