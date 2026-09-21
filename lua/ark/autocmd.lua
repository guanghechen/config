---@param name                          string
---@return integer
local function augroup(name)
  return vim.api.nvim_create_augroup("ark_" .. name, { clear = true })
end

vim.filetype.add({
  extension = {
    conf = "conf",
    excalidraw = "excalidraw",
    glsl = "glsl",
    log = "text",
    md = "markdown",
    rasi = "rasi",
    rofi = "rasi",
    ts = "typescript",
    tsx = "typescriptreact",
    wofi = "rasi",
  },
  filename = {
    [".env"] = "conf",
    [".eslintignore"] = "ignore",
    [".git-credentials"] = "git-credentials",
    [".prettierignore"] = "ignore",
    [".prettierrc"] = "yaml",
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

        if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == "bigfile" then
          return
        end

        local ext = vim.fn.fnamemodify(filepath, ":e"):lower() ---@type string
        local binary_exts = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "ico", "svg", "tiff", "tif", "pdf" }
        for _, binary_ext in ipairs(binary_exts) do
          if ext == binary_ext then
            return
          end
        end

        local size = vim.fn.getfsize(filepath) ---@type integer
        if size <= 0 then
          return
        end

        local size_limit = vim.g.bigfile_size or 0 ---@type integer
        if size_limit > 0 and size > size_limit then
          return "bigfile"
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
    ["%.env%.[%w_.-]+"] = "conf",
    ["untitled%-(%d+)"] = "text",
    [".*rc"] = "ini",
  },
})

-- Register synchronously so the initial Python buffer cannot miss FileType; load the implementation on demand.
if not vim.g.vscode and not vim.g.yozvim and not vim.g.yuivim then
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("python_venv"),
    pattern = "python",
    callback = function()
      era.m.python_venv.dressing()
    end,
  })
end

--- Only files read from disk have a saved location pending restoration.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("goto_last_location_read"),
  callback = function(event)
    if vim.b[event.buf].eve_last_loc == nil then
      vim.b[event.buf].eve_last_loc = false
    end
  end,
})

--- Restore before +cmd and callers position the cursor; commit only after entry settles.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = augroup("goto_last_location"),
  callback = function(event)
    local bufnr = event.buf ---@type integer
    if vim.b[bufnr].eve_last_loc ~= false then
      return
    end

    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if vim.api.nvim_win_get_buf(winnr) ~= bufnr then
      return
    end
    local pending_winnr = vim.b[bufnr].eve_last_loc_winnr ---@type integer|nil
    if pending_winnr == winnr then
      return
    end
    vim.b[bufnr].eve_last_loc_winnr = winnr

    local mark = vim.api.nvim_buf_get_mark(bufnr, '"')
    local count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
    local restored = false ---@type boolean
    if count > 1 and mark[1] > 0 and mark[1] <= count then
      restored = pcall(vim.api.nvim_win_set_cursor, winnr, mark)
    end
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) or vim.b[bufnr].eve_last_loc_winnr ~= winnr then
        return
      end
      vim.b[bufnr].eve_last_loc_winnr = nil
      if not vim.api.nvim_win_is_valid(winnr) or vim.api.nvim_win_get_buf(winnr) ~= bufnr then
        return
      end
      vim.b[bufnr].eve_last_loc = true
      if restored then
        era.dressing.scroll.accept_current_view(winnr)
      end
    end)
  end,
})

--- Auto create dirs when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("auto_create_dirs"),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end

    local sep = package.config:sub(1, 1) ---@type string
    local filepath = event.match ---@type string
    local dirpath = yoz.path.dirname(filepath, false, sep) ---@type string
    yoz.path.mkdirs(dirpath)
  end,
})

--- Close some filetypes with q
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_filetypes_with_q"),
  pattern = {
    "checkhealth",
    "explorer",
    "gitcommit",
    "help",
    "image-viewer",
    "lazy",
    "man",
    "mason",
    "notify",
    "lspinfo",
    "qf",
    "startuptime",
    "term",
    "term-mask",
  },
  callback = function(event)
    local bufnr = event.buf ---@type integer|nil
    if bufnr ~= nil then
      vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
      local function action()
        vim.cmd("close")
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
      vim.keymap.set({ "n", "x" }, "q", action, { buffer = bufnr, silent = true, desc = "buffer: quit" })
    end
  end,
})

--- Highlight on yank.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_on_yank"),
  callback = function()
    vim.hl.on_yank()
  end,
})

--- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("check_file_change"),
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ---@type string
    if buftype == "" or buftype == "nowrite" then
      vim.cmd("checktime")
    end
  end,
})

--- Cache buffer filepath mapping
vim.api.nvim_create_autocmd({ "BufWinEnter", "BufFilePost" }, {
  group = augroup("cache_buf_filepath"),
  callback = function(event)
    local bufnr = event.buf ---@type integer
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    stl.nvim.buf.on_buf_open(bufnr, filepath)
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  group = augroup("cache_buf_filepath_delete"),
  callback = function(event)
    local bufnr = event.buf ---@type integer
    stl.nvim.buf.on_buf_close(bufnr)
  end,
})
