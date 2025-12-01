--lsp_setup---------------------------------------------------------------------------------------

---@type table<string, string[]>
local ft_to_lsp_map = {
  astro = { "eslint" },
  bash = { "bashls" },
  c = { "clangd" },
  cpp = { "clangd" },
  css = { "cssls", "tailwindcss" },
  cuda = { "clangd" },
  dockerfile = { "dockerls" },
  excalidraw = { "jsonls" },
  handlebars = { "tailwindcss" },
  hbs = { "tailwindcss" },
  html = { "html", "tailwindcss" },
  htmlangular = { "eslint" },
  javascript = { "vtsls", "eslint", "tailwindcss" },
  javascriptreact = { "vtsls", "eslint", "tailwindcss" },
  ["javascript.jsx"] = { "vtsls", "eslint", "tailwindcss" },
  json = { "jsonls" },
  jsonc = { "jsonls" },
  less = { "cssls", "tailwindcss" },
  lua = { "lua_ls" },
  mdx = { "tailwindcss" },
  objc = { "clangd" },
  objcpp = { "clangd" },
  postcss = { "tailwindcss" },
  python = { "pyright", "ruff" },
  rust = { "rust_analyzer" },
  sass = { "tailwindcss" },
  scss = { "cssls", "tailwindcss" },
  sh = { "bashls" },
  stylus = { "tailwindcss" },
  svelte = { "eslint", "tailwindcss" },
  templ = { "html" },
  toml = { "taplo" },
  typescript = { "vtsls", "eslint", "tailwindcss" },
  typescriptreact = { "vtsls", "eslint", "tailwindcss" },
  ["typescript.tsx"] = { "vtsls", "eslint", "tailwindcss" },
  vue = { "vtsls", "eslint", "tailwindcss" },
  yaml = { "yamlls" },
  ["yaml.docker-compose"] = { "yamlls", "docker_compose_language_service" },
  ["yaml.gitlab"] = { "yamlls" },
  ["yaml.helm-values"] = { "yamlls" },
}

---@type table<string, true>
local enabled_lsp_set = {}

vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("lsp_setup"),
  callback = function(args)
    local ft = args.match ---@type string
    local lsp_servers = ft_to_lsp_map[ft]
    if lsp_servers then
      for _, lsp in ipairs(lsp_servers) do
        if not enabled_lsp_set[lsp] then
          enabled_lsp_set[lsp] = true
          vim.lsp.enable(lsp)
        end
      end
    end
  end,
})

--auto_create_dirs--------------------------------------------------------------------------------

--- Auto create dirs when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd("BufWritePre", {
  group = eve.nvim.augroup("auto_create_dirs"),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end

    local sep = package.config:sub(1, 1) ---@type string
    local filepath = event.match ---@type string
    local dirpath = rstd.path.dirname(filepath, false, sep) ---@type string
    rstd.path.mkdirs(dirpath)
  end,
})

--- Go to last loc when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  group = eve.nvim.augroup("goto_last_location"),
  callback = function(event)
    local bufnr = event.buf ---@type integer
    if vim.b[bufnr].eve_last_loc then
      return
    end
    vim.b[bufnr].eve_last_loc = true

    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if vim.api.nvim_win_get_buf(winnr) ~= bufnr then
      return
    end

    local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
    if mark == nil or type(mark[1]) ~= "number" then
      return
    end

    local count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
    if count <= 1 then
      return
    end

    if mark[1] > 0 and mark[1] <= count then
      vim.schedule(function()
        pcall(vim.api.nvim_win_set_cursor, winnr, mark)
      end)
    end
  end,
})

--- Highlight on yank.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = eve.nvim.augroup("highlight_on_yank"),
  callback = function()
    vim.hl.on_yank()
  end,
})

--- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = eve.nvim.augroup("check_file_change"),
  callback = function()
    if vim.bo.buftype == "" or vim.bo.buftype == "nowrite" then
      vim.cmd("checktime")
    end
  end,
})

--filetype------------------------------------------------------------------------------------------

vim.filetype.add({
  extension = {
    excalidraw = "excalidraw",
    log = "text",
    md = "markdown",
    rasi = "rasi",
    rofi = "rasi",
    ts = "typescript",
    tsx = "typescriptreact",
    wofi = "rasi",
  },
  filename = {
    [".eslintignore"] = "ignore",
    [".git-credentials"] = "git-credentials",
    [".prettierignore"] = "ignore",
    log = "text",
    skhdrc = "conf",
    vimrc = "vim",
    yabairc = "sh",
  },
  pattern = {
    [".*"] = {
      function(filepath, bufnr)
        if not filepath or not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        if vim.bo[bufnr].filetype == eve.filetype.BIGFILE then
          return
        end

        local size = vim.fn.getfsize(filepath) ---@type integer
        if size <= 0 then
          return
        end

        local size_limit = vim.g.bigfile_size or 0 ---@type integer
        if size_limit > 0 and size > size_limit then
          return eve.filetype.BIGFILE
        end

        local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
        if line_count <= 0 then
          return
        end

        local threshold = vim.g.bigfile_line_length or 0 ---@type integer
        if threshold > 0 and (size - line_count) / line_count > threshold then
          return eve.filetype.BIGFILE
        end
      end,
    },

    ["*.fzfrc"] = "bash",
    ["*.ripgreprc"] = "bash",
    ["*.tmux.conf"] = "tmux",

    ["*.ts"] = "typescript",
    ["*.cts"] = "typescript",
    ["*.mts"] = "typescript",

    ["*.js"] = "javascript",
    ["*.cjs"] = "javascript",
    ["*.mjs"] = "javascript",

    ["%.json5$"] = "jsonc",
    ["%.jsonc$"] = "jsonc",
    ["%.vscode/tasks%.json$"] = "jsonc",
    ["%.vscode/settings%.json$"] = "jsonc",
    ["%.vscode/launch%.json$"] = "jsonc",
    ["%.vscode/extensions%.json$"] = "jsonc",
    [".*/waybar/config"] = "jsonc",
    [".*/mako/config"] = "dosini",
    [".*/kitty/.+%.conf"] = "bash",
    [".*/hypr/.+%.conf"] = "hyprlang",
    ["%.env%.[%w_.-]+"] = "sh",
    ["untitled%-(%d+)"] = "text",
    [".*rc"] = "ini",
  },
})

--filetype functional-------------------------------------------------------------------------------

--- Close some filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("close_filetypes_with_q"),
  pattern = eve.filetype.get_quitable_with_q_filetypes(),
  callback = function(event)
    local bufnr = event.buf ---@type integer|nil
    if bufnr ~= nil then
      vim.bo[bufnr].buflisted = false
      local function action()
        vim.cmd("close")
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
      vim.keymap.set({ "n", "x" }, "q", action, { buffer = bufnr, silent = true, desc = "buffer: quit" })
    end
  end,
})
