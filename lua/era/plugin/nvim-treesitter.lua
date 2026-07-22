---@see https://github.com/nvim-treesitter/nvim-treesitter

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
  "dart",
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
  "dart",
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

    local augroup = stl.nvim.fn.augroup(__module_name__) ---@type integer
    local pending_bufnrs = {} ---@type table<integer, true>
    local ensured_filetype_set = {} ---@type table<string, true>
    for _, filetype in ipairs(ensure_filetypes) do
      ensured_filetype_set[filetype] = true
    end

    ---@param bufnr                      integer
    ---@return string|nil
    local function resolve_lang(bufnr)
      if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
        return
      end

      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
      if not ensured_filetype_set[filetype] then
        return
      end
      return vim.treesitter.language.get_lang(filetype)
    end

    ---@param bufnr                      integer
    ---@return string|nil
    local function active_lang(bufnr)
      -- `vim.treesitter.start()` replaces an existing highlighter without disposing it.
      local highlighter = vim.treesitter.highlighter.active[bufnr]
      return highlighter and highlighter.tree:lang() or nil
    end

    ---@param bufnr                      integer
    ---@return nil
    local function configure_windows(bufnr)
      for _, winnr in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) == bufnr then
          local foldexpr = vim.api.nvim_get_option_value("foldexpr", { win = winnr }) ---@type string
          if foldexpr ~= "v:lua.vim.lsp.foldexpr()" then
            vim.api.nvim_set_option_value(
              "foldexpr",
              "v:lua.vim.treesitter.foldexpr()",
              { win = winnr, scope = "local" }
            )
          end
        end
      end
    end

    ---@param bufnr                      integer
    ---@return nil
    local function configure(bufnr)
      vim.api.nvim_set_option_value("indentexpr", "v:lua.require'nvim-treesitter'.indentexpr()", { buf = bufnr })
      configure_windows(bufnr)
    end

    ---@param bufnr                      integer
    ---@return nil
    local function activate(bufnr)
      local lang = resolve_lang(bufnr) ---@type string|nil
      if lang == nil then
        pending_bufnrs[bufnr] = nil
        return
      end

      pending_bufnrs[bufnr] = nil
      local current_lang = active_lang(bufnr) ---@type string|nil
      if current_lang ~= lang then
        if current_lang ~= nil then
          vim.treesitter.stop(bufnr)
        end
        vim.treesitter.start(bufnr, lang)
      end
      configure(bufnr)
    end

    ---@param bufnr                      integer
    ---@return nil
    local function defer_activation(bufnr)
      local lang = resolve_lang(bufnr) ---@type string|nil
      if lang == nil then
        pending_bufnrs[bufnr] = nil
        return
      end
      if active_lang(bufnr) == lang then
        pending_bufnrs[bufnr] = nil
        configure(bufnr)
        return
      end
      pending_bufnrs[bufnr] = true
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = augroup,
      pattern = ensure_filetypes,
      callback = function(event)
        activate(event.buf)
      end,
    })

    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = augroup,
      callback = function(event)
        defer_activation(event.buf)
      end,
    })

    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "InsertEnter" }, {
      group = augroup,
      callback = function(event)
        if pending_bufnrs[event.buf] then
          activate(event.buf)
        end
      end,
    })

    vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout" }, {
      group = augroup,
      callback = function(event)
        pending_bufnrs[event.buf] = nil
      end,
    })

    for _, winnr in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(winnr) then
        defer_activation(vim.api.nvim_win_get_buf(winnr))
      end
    end
  end,
  dependencies = {
    "nvim-treesitter-textobjects",
  },
}

return M
