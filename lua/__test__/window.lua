local function test_window_mouse_click()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nowrite"
  vim.bo[bufnr].filetype = "lua"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false

  ---@type string[]
  local lines = {
    "  local _render_scheduler = scheduler.debounce({",
    '    name = "fml.ui.search.main.render",',
    "    delay = _render_delay,",
    "    fn = function(callback)",
    "      local ok, error = pcall(function()",
    "        local bufnr = self:create_buf_as_needed() ---@type integer",
    "        vim.bo[bufnr].modifiable = true",
    "        vim.bo[bufnr].readonly = false",
    "",
    "        local lines = {} ---@type string[]",
    "        for i, item in ipairs(state.items) do",
    "          lines[i] = item.text",
    "        end",
    "        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)",
    "        self:place_lnum_sign()",
    "",
    "        vim.bo[bufnr].modifiable = false",
    "        vim.bo[bufnr].readonly = true",
    "",
    "        local items = state.items ---@type fml.types.ui.search.IItem[]",
    "        for lnum, item in ipairs(items) do",
    "          local highlights = item.highlights ---@type fml.types.ui.IInlineHighlight[]",
    "          for _, hl in ipairs(highlights) do",
    "            vim.api.nvim_buf_add_highlight(bufnr, 0, hl.hlname, lnum - 1, hl.coll, hl.colr)",
    "          end",
    "        end",
    "      end)",
    "      callback(ok, error)",
    "    end,",
    "    callback = function()",
    "      state.dirty_main:next(false)",
    "      _on_rendered()",
    "    end,",
    "  })",
  }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  vim.schedule(function()
    vim.cmd("stopinsert")
  end)

  local height = 40 ---@type integer
  local width = 80 ---@type integer
  ---@type vim.api.keyset.win_config
  local wincfg_main = {
    relative = "editor",
    anchor = "NW",
    height = height,
    width = width,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    focusable = true,
    title = "",
    border = "rounded",
    style = "minimal",
  }

  local winnr = vim.api.nvim_open_win(bufnr, true, wincfg_main)
  local WIN_HIGHLIGHT = table.concat({
    "Cursor:f_us_main_current",
    "CursorColumn:f_us_main_current",
    "CursorLine:f_us_main_current",
    "CursorLineNr:f_us_main_current",
    "FloatBorder:f_us_main_border",
    "Normal:f_us_main_normal",
  }, ",")

  vim.wo[winnr].cursorline = true
  vim.wo[winnr].number = true
  vim.wo[winnr].relativenumber = true
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].winblend = 0
  vim.wo[winnr].winhighlight = WIN_HIGHLIGHT
  vim.wo[winnr].wrap = false
  vim.wo[winnr].cursorline = true

  local actions = {
    on_close = function()
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end,
    on_mouse_click = function()
      local cursor = vim.fn.getmousepos()
      fml.debug.log("mouse click", { cursor = cursor })
    end,
    on_mouse_dbclick = function()
      local cursor = vim.fn.getmousepos()
      fml.debug.log("mouse double click", { cursor = cursor })
    end,
  }

  ---@type fml.types.IKeymap[]
  local keymaps = {
    { modes = { "n", "v" }, key = "q", callback = actions.on_close, desc = "close" },
    {
      modes = { "i", "n" },
      key = "<LeftMouse>",
      callback = actions.on_mouse_click,
      desc = "mouse click",
      nowait = true,
    },
    {
      modes = { "i", "n", "v" },
      key = "<2-LeftMouse>",
      callback = actions.on_mouse_dbclick,
      desc = "mouse double click",
      nowait = true,
    },
  }
  fml.util.bind_keys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

test_window_mouse_click()
