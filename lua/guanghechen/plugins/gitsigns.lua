---@class guanghechen.plugins.gitsigns.config
local config = {
  win = {
    preview_hunk = {
      title = " git hunk preview ",
      highlight = table.concat({
        "Cursor:f_ghp_cursor",
        "CursorColumn:f_ghp_cursor",
        "CursorLine:f_ghp_cursor",
        "CursorLineNr:f_ghp_cursor",
        "FloatBorder:f_ghp_border",
        "Normal:f_ghp_normal",
      }, ","),
    },
  },
}

---@param lnum                          integer
---@return string|nil
local function get_previous_line_by_hunk(lnum)
  local hunks = require("gitsigns").get_hunks()
  if hunks then
    for _, hunk in ipairs(hunks) do
      local line_start = hunk.added.start ---@type integer
      local line_end = hunk.added.start + hunk.added.count ---@type integer
      if lnum >= line_start and lnum < line_end then
        local offset = lnum - line_start ---@type integer
        return hunk.removed.lines[offset + 1]
      end
    end
  end
end

---@type eve.t.IKeymap[]
local keymaps = {
  {
    modes = { "n" },
    key = "[H",
    desc = "git: goto prev hunk (all)",
    callback = function()
      require("gitsigns").nav_hunk("prev", { foldopen = true, target = "all" })
    end,
  },
  {
    modes = { "n" },
    key = "]H",
    desc = "git: goto next hunk (all)",
    callback = function()
      require("gitsigns").nav_hunk("next", { foldopen = true, target = "all" })
    end,
  },
  {
    modes = { "n" },
    key = "[h",
    desc = "git: goto prev hunk (unstaged)",
    callback = function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        require("gitsigns").nav_hunk("prev", { foldopen = true, target = "unstaged" })
      end
    end,
  },
  {
    modes = { "n" },
    key = "]h",
    desc = "git: goto next hunk (unstaged)",
    callback = function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        require("gitsigns").nav_hunk("next", { foldopen = true, target = "unstaged" })
      end
    end,
  },
  {
    modes = { "n" },
    key = "<leader>gb",
    desc = "git: blame line",
    callback = function()
      local lnum = vim.fn.line(".") ---@type integer
      local content_current = vim.fn.getline(lnum) ---@type string
      local filepath = vim.fn.expand("%") ---@type string
      local blame_info = vim.fn.system(string.format("git blame --porcelain -slL %d,%d %s", lnum, lnum, filepath)) ---@type string
      local lines = vim.split(blame_info, "\n") ---@type string[]

      local commit_hash = string.match(lines[1], "^([0-9a-fA-F]+)")

      ---author information
      local author_name = vim.trim(string.match(lines[2], "author%s+(.+)")) ---@type string
      local author_time = vim.trim(string.match(lines[4], "author%-time%s+(%d+)")) ---@type string
      -- local author_tz = vim.trim(string.match(lines[5], "author%-tz%s+([+-]%d%d%d%d)")) ---@type string
      -- local author_tz_offset_hours = tonumber(string.sub(author_tz, 1, 3)) or 0 ---@type integer
      -- local author_tz_offset_minutes = tonumber(string.sub(author_tz, 4, 5)) or 0 ---@type integer
      -- local author_tz_offset_seconds = (author_tz_offset_hours * 3600) + (author_tz_offset_minutes * 60) ---@type integer
      -- local author_timestamp = tonumber(author_time) - author_tz_offset_seconds ---@type integer
      local author_timestamp = tonumber(author_time) ---@type integer|nil
      local author_date = os.date("%Y-%m-%d %H:%M:%S", author_timestamp)

      ---committer information
      -- local committer_name = vim.trim(string.match(lines[6], "committer%s+(.+)")) ---@type string
      -- local committer_time = vim.trim(string.match(lines[8], "committer%-time%s+(%d+)")) ---@type string
      -- local committer_tz = vim.trim(string.match(lines[9], "committer%-tz%s+([+-]%d%d%d%d)")) ---@type string
      -- local committer_tz_offset_hours = tonumber(string.sub(committer_tz, 1, 3)) or 0 ---@type integer
      -- local committer_tz_offset_minutes = tonumber(string.sub(committer_tz, 4, 5)) or 0 ---@type integer
      -- local committer_tz_offset_seconds = (committer_tz_offset_hours * 3600) + (committer_tz_offset_minutes * 60) ---@type integer
      -- local committer_timestamp = tonumber(committer_time) - committer_tz_offset_seconds ---@type integer
      -- local committer_date = os.date("%Y-%m-%d %H:%M:%S", committer_timestamp)

      local content_previous = get_previous_line_by_hunk(lnum) ---@type string|nil
      local commit_message = "Uncommitted changes" ---@type string
      if commit_hash ~= "0000000000000000000000000000000000000000" then
        commit_message = vim.trim(vim.fn.system("git log -1 " .. commit_hash .. ' --pretty=format:"%s%n%n%b"')) ---@type string
      end

      local width = 84 ---@type integer
      local separate_line = string.rep("─", width - 4) ---@type string
      local prefix_indent = "  " ---@type string
      local lines_commit_message = vim.split(commit_message, "\n") ---@type string[]

      ---@type string[]
      local v_lines = {
        "",
        string.format("%s, %s (%s)", author_name, eve.util.time_ago(author_timestamp or os.time()), author_date),
        separate_line,
      }
      vim.list_extend(v_lines, lines_commit_message)
      if content_previous ~= nil then
        vim.list_extend(v_lines, {
          " - " .. content_previous,
          " + " .. content_current,
        })
      end
      vim.list_extend(v_lines, {
        separate_line,
        string.format("Changes added in %s | <remote url>", commit_hash),
        "",
      })

      for index, v_line in ipairs(v_lines) do
        v_lines[index] = prefix_indent .. v_line
      end

      local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, v_lines)

      ---@type eve.t.IKeymap[]
      local keymaps = {
        {
          modes = { "n" },
          key = "q",
          callback = function()
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
          end,
        },
      }
      eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

      -- Apply highlights
      vim.api.nvim_buf_add_highlight(bufnr, 0, "Title", 1, 2, -1)
      vim.api.nvim_buf_add_highlight(bufnr, 0, "VertSplit", 2, 2, -1)
      local lnum_offset = 2 ---@type integer
      for _ = 1, #lines_commit_message do
        lnum_offset = lnum_offset + 1
        vim.api.nvim_buf_add_highlight(bufnr, 0, "Comment", lnum_offset, 2, -1)
      end
      lnum_offset = lnum_offset + 1
      if content_previous ~= nil then
        vim.api.nvim_buf_add_highlight(bufnr, 0, "DiffDelRight", lnum_offset, 2, -1)
        lnum_offset = lnum_offset + 1
        vim.api.nvim_buf_add_highlight(bufnr, 0, "DiffAddRight", lnum_offset, 2, -1)
        lnum_offset = lnum_offset + 1
      end
      vim.api.nvim_buf_add_highlight(bufnr, 0, "VertSplit", lnum_offset, 2, -1)

      local height = #v_lines
      local opts = {
        relative = "cursor",
        width = width,
        height = height,
        col = 1,
        row = 1,
        style = "minimal",
        border = "rounded",
      }
      local winnr = vim.api.nvim_open_win(bufnr, true, opts)
      vim.wo[winnr].wrap = false
      vim.wo[winnr].number = false
      vim.wo[winnr].relativenumber = false
      vim.wo[winnr].signcolumn = "no"
    end,
  },
  {
    modes = { "n" },
    key = "<leader>ghd",
    desc = "git: diff current file",
    callback = function()
      require("gitsigns").diffthis("~")
    end,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ghp",
    desc = "git: preview hunk inline",
    callback = function()
      require("gitsigns").preview_hunk()
      vim.defer_fn(function()
        local winnrs = vim.api.nvim_list_wins() ---@type integer[]
        for _, winnr in ipairs(winnrs) do
          local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
          if
            wincfg.relative ~= nil
            and wincfg.relative ~= ""
            and type(wincfg.title) == "table"
            and type(wincfg.title[1]) == "table"
            and wincfg.title[1][1] == config.win.preview_hunk.title
          then
            vim.api.nvim_set_current_win(winnr)
            vim.wo[winnr].number = false
            vim.wo[winnr].relativenumber = false
            vim.wo[winnr].signcolumn = "yes"
            vim.wo[winnr].winblend = 10
            vim.wo[winnr].winhighlight = config.win.preview_hunk.highlight
            vim.wo[winnr].wrap = false
            return
          end
        end
      end, 50)
    end,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ghr",
    desc = "git: reset hunk",
    callback = function()
      require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ghs",
    desc = "git: stage hunk",
    callback = function()
      require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ghu",
    desc = "git: undo stage hunk",
    callback = function()
      require("gitsigns").undo_stage_hunk()
    end,
  },
}

-- git signs highlights text that has changed since the list
-- git commit, and also lets you interactively stage & unstage
-- hunks in a commit.
return {
  name = "gitsigns.nvim",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  opts = {
    current_line_blame = true,
    current_line_blame_formatter = "    <author>, <author_time:%Y-%m-%d %H:%M:%S> - <summary>",
    numhl = false,
    linehl = false,
    culhl = false,
    signcolumn = true,
    signs_staged_enable = true,
    word_diff = false,
    max_file_length = 3000, -- Disable if file is longer than this (in lines)
    diff_opts = {
      algorithm = "minimal",
      ignore_blank_lines = false,
      ignore_whitespace = false,
      ignore_whitespace_change = false,
      ignore_whitespace_change_at_eol = false,
    },
    preview_config = {
      relative = "cursor",
      row = 0,
      col = 1,

      title = config.win.preview_hunk.title,
      title_pos = "center",
      border = { " ", " ", " ", " ", " ", " ", " ", " " },
      style = "minimal",
      width = 124,

      focusable = true,
    },
    signs = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "▁" },
      topdelete = { text = "▔" },
      changedelete = { text = "󱕖" },
      untracked = { text = "┆" },
    },
    signs_staged = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "▁" },
      topdelete = { text = "▔" },
      changedelete = { text = "󱕖" },
      untracked = { text = "┆" },
    },
    on_attach = function(bufnr)
      eve.nvim.bindkeys(keymaps, { buffer = bufnr, noremap = true, silent = true })
      vim.keymap.set({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = "git: select hunk",
      })
    end,
  },
}
