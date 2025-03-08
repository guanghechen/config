local env = require("eve.builtin.env")
local fn = require("eve.builtin.fn")
local ft = require("eve.constant.filetype")

if env.IS_MAC then
  vim.defer_fn(function()
    local im = require("eve.builtin.im")
    local previous_mode = nil ---@type eve.e.VimMode|nil
    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
      group = fn.augroup("auto_toggle_im"),
      callback = function()
        local current_mode = vim.fn.mode() ---@type eve.e.VimMode|nil
        if previous_mode == "i" and current_mode == "n" then
          im.set_input_method("English")
        end
        previous_mode = current_mode
      end,
    })
  end, 500)
end

if not vim.g.vscode then
  ---! Auto create dirs when saving a file, in case some intermediate directory does not exist
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = fn.augroup("auto_create_dirs"),
    callback = function(event)
      if event.match:match("^%w%w+:[\\/][\\/]") then
        return
      end
      local file = vim.uv.fs_realpath(event.match) or event.match
      vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end,
  })

  ---! Go to last loc when opening a buffer
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = fn.augroup("goto_last_location"),
    callback = function(event)
      local bufnr = event.buf ---@type integer
      if vim.b[bufnr].eve_last_loc then
        return
      end
      vim.b[bufnr].eve_last_loc = true

      local filetype = vim.bo[bufnr].filetype ---@type string
      if ft.is_plain_file(filetype) then
        local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
        local count = vim.api.nvim_buf_line_count(bufnr)
        if mark[1] > 0 and mark[1] <= count then
          pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
      end
    end,
  })

  ---! Close some filetypes with q
  vim.api.nvim_create_autocmd("FileType", {
    group = fn.augroup("close_filetypes_with_q"),
    pattern = ft.get_quitable_with_q_filetypes(),
    callback = function(event)
      local bufnr = event.buf ---@type integer|nil
      if bufnr ~= nil then
        vim.bo[bufnr].buflisted = false
        local function action()
          vim.cmd.close()
          pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
        end
        vim.keymap.set({ "n", "v" }, "q", action, { buffer = bufnr, silent = true, desc = "buffer: quit" })
        vim.keymap.set({ "i", "n", "v" }, "<C-a>q", action, { buffer = bufnr, silent = true, desc = "buffer: quit" })
        vim.keymap.set({ "i", "n", "v" }, "<D-q>", action, { buffer = bufnr, silent = true, desc = "buffer: quit" })
        vim.keymap.set({ "i", "n", "v" }, "<M-q>", action, { buffer = bufnr, silent = true, desc = "buffer: quit" })
      end
    end,
  })

  ---! Disable autopairs
  vim.api.nvim_create_autocmd("FileType", {
    group = fn.augroup("close_filetypes_with_q"),
    pattern = ft.get_disable_autopairs_filetypes(),
    callback = function(event)
      local bufnr = event.buf ---@type integer|nil
      if bufnr ~= nil then
        vim.b[bufnr].minipairs_disable = true
      end
    end,
  })

  ---! Highlight on yank.
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = fn.augroup("highlight_on_yank"),
    callback = function()
      vim.highlight.on_yank()
    end,
  })

  ---! Check if we need to reload the file when it changed
  vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
    group = fn.augroup("check_file_change"),
    callback = function()
      if vim.o.buftype ~= "nofile" then
        vim.cmd.checktime()
      end
    end,
  })
end
