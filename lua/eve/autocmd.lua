local env = require("eve.lib.env")
local ft = require("eve.builtin.filetype")
local mvc = require("eve.builtin.mvc")
local widgets = require("eve.builtin.widgets")

if env.IS_MAC or env.IS_NIX or env.IS_WSL then
  vim.opt.shell = "/bin/bash"
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    mvc.dispose()
  end,
})

---! Auto create dirs when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

---! Go to last loc when opening a buffer
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  callback = function(event)
    local bufnr = event.buf ---@type integer
    if vim.b[bufnr].ghc_last_loc then
      return
    end
    vim.b[bufnr].ghc_last_loc = true

    local filetype = vim.bo[bufnr].filetype ---@type string
    if eve.filetype.is_plain_file(filetype) then
      local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
      local lcount = vim.api.nvim_buf_line_count(bufnr)
      if mark[1] > 0 and mark[1] <= lcount then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end
  end,
})

---! Close some filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  pattern = ft.get_quitable_with_q_filetypes(),
  callback = function(event)
    local bufnr = event.buf ---@type integer|nil
    if bufnr ~= nil then
      vim.bo[bufnr].buflisted = false
      local function action()
        vim.cmd.close()
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
      vim.keymap.set("n", "q", action, { buffer = bufnr, silent = true, desc = "buffer: quit" })
    end
  end,
})

---! Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd.checktime()
    end
  end,
})

---! Highlight on yank.
vim.api.nvim_create_autocmd({ "TextYankPost" }, {
  callback = function()
    vim.highlight.on_yank()
  end,
})

---! Auto resize splits when window got resized.
vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    local current_tab = vim.fn.tabpagenr() ---@type integer
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
    widgets.resize()
  end,
})
