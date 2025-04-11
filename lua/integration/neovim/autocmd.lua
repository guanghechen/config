--- Auto create dirs when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd("BufWritePre", {
  group = eve.nvim.augroup("auto_create_dirs"),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
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

    local filetype = vim.bo[bufnr].filetype ---@type string
    if not eve.filetype.is_not_sourcefile(filetype) then
      local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
      local count = vim.api.nvim_buf_line_count(bufnr)
      if mark[1] > 0 and mark[1] <= count then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "WinNew", "WinEnter" }, {
  callback = function()
    local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
    local winnrs = vim.api.nvim_list_wins() ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      if eve.editor.is_win_floating(winnr) then
        local winhighlight = vim.wo[winnr].winhighlight
        if winnr == winnr_cur then
          local winhighlight_next = winhighlight:gsub("FloatBorder:FloatBorder", "FloatBorder:FloatActiveBorder")
          vim.wo[winnr].winhighlight = winhighlight_next
        else
          local winhighlight_next = winhighlight:gsub("FloatBorder:FloatActiveBorder", "FloatBorder:FloatBorder")
          vim.wo[winnr].winhighlight = winhighlight_next
        end
      end
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
    if vim.o.buftype ~= "nofile" then
      vim.cmd.checktime()
    end
  end,
})

--filetype------------------------------------------------------------------------------------------

vim.filetype.add({
  extension = {
    avanterules = "jinja",
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
    ["log"] = "text",
    ["vimrc"] = "vim",
  },
  pattern = {
    [".*"] = {
      function(filepath, bufnr)
        return vim.bo[bufnr]
            and vim.bo[bufnr].filetype ~= eve.filetype.BIGFILE
            and filepath
            and vim.fn.getfsize(filepath) > vim.g.bigfile_size
            and eve.filetype.BIGFILE
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
    ["untitled%-(%d+)"] = "text",
  },
})

---bigfile
vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("filetype_bigfile"),
  pattern = "bigfile",
  callback = function(evt)
    local bufnr = evt.buf ---@type integer
    vim.api.nvim_buf_call(bufnr, function()
      vim.bo[bufnr].filetype = vim.filetype.match({ buf = bufnr }) or ""
    end)
  end,
})

---gitcommit
vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("filetype_gitcommit"),
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.wrap = false
  end,
})

---html
vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("filetype_html"),
  pattern = "html",
  callback = function()
    vim.opt_local.wrap = false
  end,
})

---jsonc
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = eve.nvim.augroup("filetype_jsonc"),
  pattern = {
    "*.json5",
    "*.jsonc",
    "**/.vscode/tasks.json",
    "**/.vscode/settings.json",
    "**/.vscode/launch.json",
    "**/.vscode/extensions.json",
  },
  callback = function()
    vim.bo.filetype = "jsonc"
  end,
})

---markdown
vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("filetype_markdown"),
  pattern = "markdown",
  callback = function()
    vim.opt_local.backupcopy = "yes" -- disable atomic writing
    vim.opt_local.formatoptions:append("t")
    vim.opt_local.linebreak = true
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2 -- set the tab width
    vim.opt_local.tabstop = 2 -- set the tab width
    vim.opt_local.textwidth = 0
    vim.opt_local.wrap = true
    vim.opt_local.wrapmargin = 0
  end,
})

---text
vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("filetype_text"),
  pattern = "text",
  callback = function()
    vim.opt_local.backupcopy = "yes" -- disable atomic writing
    vim.opt_local.formatoptions:append("t")
    vim.opt_local.linebreak = true
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2 -- set the tab width
    vim.opt_local.tabstop = 2 -- set the tab width
    vim.opt_local.textwidth = 0
    vim.opt_local.wrap = true
    vim.opt_local.wrapmargin = 0
  end,
})

---terminal
vim.api.nvim_create_autocmd("TermOpen", {
  group = eve.nvim.augroup("filetype_terminal"),
  callback = function()
    vim.opt_local.number = false -- Disable line numbers
    vim.opt_local.relativenumber = false -- Disable relative numbers
    vim.opt_local.signcolumn = "no" -- Hide sign column
    vim.cmd("startinsert") -- Start in insert mode
  end,
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

--- Disable autopairs
vim.api.nvim_create_autocmd("FileType", {
  group = eve.nvim.augroup("disable_autopairs"),
  pattern = eve.filetype.get_disable_autopairs_filetypes(),
  callback = function(event)
    local bufnr = event.buf ---@type integer|nil
    if bufnr ~= nil then
      vim.b[bufnr].minipairs_disable = true
    end
  end,
})
