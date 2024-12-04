local constant = require("eve.builtin.constant")

vim.filetype.add({
  extension = { rasi = "rasi", rofi = "rasi", wofi = "rasi" },
  filename = {
    ["vifmrc"] = "vim",
  },
  pattern = {
    [".*"] = {
      function(filepath, bufnr)
        return vim.bo[bufnr]
            and vim.bo[bufnr].filetype ~= constant.FT_BIGFILE
            and filepath
            and vim.fn.getfsize(filepath) > vim.g.bigfile_size
            and constant.FT_BIGFILE
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
  pattern = "bigfile",
  callback = function(ev)
    vim.schedule(function()
      vim.bo[ev.buf].syntax = vim.filetype.match({ buf = ev.buf }) or ""
    end)
  end,
})

---gitcommit
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = true
  end,
})

---html
vim.api.nvim_create_autocmd("FileType", {
  pattern = "html",
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = true
  end,
})

---markdown
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
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
  pattern = "text",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
    vim.opt_local.textwidth = 0
    vim.opt_local.wrapmargin = 0
    vim.opt_local.formatoptions:append("t")
  end,
})
