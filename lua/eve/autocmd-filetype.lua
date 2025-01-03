local functional = require("eve.builtin.functional")
local fts = require("eve.constant.filetype")

vim.filetype.add({
  extension = { rasi = "rasi", rofi = "rasi", wofi = "rasi" },
  filename = {
    ["vimrc"] = "vim",
  },
  pattern = {
    [".*"] = {
      function(filepath, bufnr)
        return vim.bo[bufnr]
            and vim.bo[bufnr].filetype ~= fts.BIGFILE
            and filepath
            and vim.fn.getfsize(filepath) > vim.g.bigfile_size
            and fts.BIGFILE
          or nil
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

    [".*/waybar/config"] = "jsonc",
    [".*/mako/config"] = "dosini",
    [".*/kitty/.+%.conf"] = "bash",
    [".*/hypr/.+%.conf"] = "hyprlang",
    ["%.env%.[%w_.-]+"] = "sh",
  },
})

---bigfile
vim.api.nvim_create_autocmd("FileType", {
  group = functional.augroup("filetype_bigfile"),
  pattern = "bigfile",
  callback = function(evt)
    local bufnr = evt.buf ---@type integer
    vim.api.nvim_buf_call(bufnr, function()
      vim.opts.setup({ buf = bufnr, ft = vim.filetype.match({ buf = bufnr }) or "" })
    end)
  end,
})

---gitcommit
vim.api.nvim_create_autocmd("FileType", {
  group = functional.augroup("filetype_gitcommit"),
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.wrap = false
  end,
})

---html
vim.api.nvim_create_autocmd("FileType", {
  group = functional.augroup("filetype_html"),
  pattern = "html",
  callback = function()
    vim.opt_local.wrap = false
  end,
})

---markdown
vim.api.nvim_create_autocmd("FileType", {
  group = functional.augroup("filetype_markdown"),
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.textwidth = 0
    vim.opt_local.wrapmargin = 0
    vim.opt_local.formatoptions:append("t")

    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2 -- set the tab width
    vim.opt_local.tabstop = 2 -- set the tab width
  end,
})

---text
vim.api.nvim_create_autocmd("FileType", {
  group = functional.augroup("filetype_text"),
  pattern = "text",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.textwidth = 0
    vim.opt_local.wrapmargin = 0
    vim.opt_local.formatoptions:append("t")
  end,
})

---terminal
vim.api.nvim_create_autocmd("TermOpen", {
  group = functional.augroup("terminal"),
  callback = function()
    vim.opt_local.number = false -- Disable line numbers
    vim.opt_local.relativenumber = false -- Disable relative numbers
    vim.opt_local.signcolumn = "no" -- Hide sign column
    vim.cmd("startinsert") -- Start in insert mode
  end,
})

vim.api.nvim_create_autocmd("SessionLoadPost", {
  group = functional.augroup("auto_detect_filetypes"),
  pattern = "*",
  callback = function()
    vim.cmd("filetype detect")
  end,
})
