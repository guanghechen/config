---@class ghc.plugins.gitsigns.config
local config = {
  win = {
    preview_hunk = {
      title = " git hunk preview ",
      highlight = table.concat({
        "Cursor:f_ghp_cursor",
        "CursorColumn:f_ghp_cursor",
        "CursorLine:f_ghp_cursor",
        "CursorLineNr:f_ghp_cursor",
        "FloatBorder:FloatActiveBorder",
        "FloatTitle:FloatActiveTitle",
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

---@param lnum                          integer
---@param filepath                      string
---@return string[]
---@return string[]
local function get_diff_lines_from_git(lnum, filepath)
  local output =
    vim.fn.system(string.format("git --no-pager log --no-color --oneline -n 1 -u -L %d,+1:%s", lnum, filepath))
  local lines = vim.split(output, "\n", { plain = true })

  local index = 1 ---@type integer
  while index <= #lines do
    if lines[index]:sub(1, 4) == "@@ -" then
      break
    end
    index = index + 1
  end

  if index > #lines then
    return {}, {}
  end

  local dels = {} ---@type string[]
  local adds = {} ---@type string[]
  for i = index + 1, #lines, 1 do
    local line = lines[i]
    if line:sub(1, 1) == "-" then
      dels[#dels + 1] = line
    elseif line:sub(1, 1) == "+" then
      adds[#adds + 1] = line
    end
  end
  return dels, adds
end

---@type eve.t.IKeymap[]
local keymaps = {
  {
    modes = { "n" },
    key = "[H",
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
    key = "]H",
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
    key = "[h",
    desc = "git: goto prev hunk (all)",
    callback = function()
      require("gitsigns").nav_hunk("prev", { foldopen = true, target = "all" })
    end,
  },
  {
    modes = { "n" },
    key = "]h",
    desc = "git: goto next hunk (all)",
    callback = function()
      require("gitsigns").nav_hunk("next", { foldopen = true, target = "all" })
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
      local lines = vim.split(blame_info, "\n", { plain = true }) ---@type string[]

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

      local dels = {} ---@type string[]
      local adds = {} ---@type string[]
      local content_previous = get_previous_line_by_hunk(lnum) ---@type string|nil
      if content_previous ~= nil then
        dels = { "- " .. content_previous } ---@type string[]
        adds = { "+ " .. content_current } ---@type string[]
      else
        dels, adds = get_diff_lines_from_git(lnum, filepath)
      end

      local commit_message = "Uncommitted changes" ---@type string
      if commit_hash ~= "0000000000000000000000000000000000000000" then
        commit_message = vim.trim(vim.fn.system("git log -1 " .. commit_hash .. ' --pretty=format:"%s%n%n%b"')) ---@type string
      end

      local width = 84 ---@type integer
      local separate_line = string.rep("─", width - 4) ---@type string

      local printer = eve.ux.Printer.new({ name = "blame line", indent = "  " }) ---@type eve.ux.IPrinter
      printer
        :lf()
        :line(
          string.format("%s, %s (%s)", author_name, eve.fn.time_ago(author_timestamp or os.time()), author_date),
          { { hlname = "Title", coll = 0, colr = -1 } }
        )
        :line(separate_line, { { hlname = "VertSplit", coll = 0, colr = -1 } })
        :lines(
          vim.split(commit_message, "\n", { plain = true }),
          { { lnum = -1, hlname = "Comment", coll = 0, colr = -1 } }
        )
        :lines(dels, { { lnum = -1, hlname = "DiffDelRight", coll = 0, colr = -1 } })
        :lines(adds, { { lnum = -1, hlname = "DiffAddRight", coll = 0, colr = -1 } })
        :line(separate_line, { { hlname = "VertSplit", coll = 0, colr = -1 } })
        :line(string.format("Changes added in %s | <remote url>", commit_hash), {})
        :lf()

      local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      vim.bo[bufnr].buflisted = false
      vim.bo[bufnr].buftype = "nofile"
      vim.bo[bufnr].filetype = eve.filetype.TEMP_VIEWER
      vim.bo[bufnr].swapfile = false
      printer:render(bufnr)

      ---@type eve.t.IKeymap[]
      local keymaps = {
        {
          modes = { "i", "n", "v" },
          key = "<C-a>q",
          aliases = { "<D-q>", "<M-q>" },
          callback = function()
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
          end,
        },
        {
          modes = { "n" },
          key = "q",
          callback = function()
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
          end,
        },
      }
      eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

      local height = printer:count_lines() ---@type integer
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

      vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true
      vim.w[winnr][eve.var.Names.FLAG_SOURCEFILE] = false

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
      require("gitsigns").preview_hunk() ---! Second call for trigger the focus

      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
      if
        wincfg.relative ~= nil
        and wincfg.relative ~= ""
        and type(wincfg.title) == "table"
        and type(wincfg.title[1]) == "table"
        and wincfg.title[1][1] == config.win.preview_hunk.title
      then
        local winblend = eve.state.theme.get_float_winblend() ---@type integer
        vim.wo[winnr].number = false
        vim.wo[winnr].relativenumber = false
        vim.wo[winnr].signcolumn = "yes"
        vim.wo[winnr].winblend = winblend
        vim.wo[winnr].winhighlight = config.win.preview_hunk.highlight
        vim.wo[winnr].wrap = false

        vim.api.nvim_set_current_win(winnr)
      end
    end,
  },
  {
    modes = { "n" },
    key = "<leader>ghr",
    desc = "git: reset hunk",
    callback = function()
      require("gitsigns").reset_hunk()
    end,
  },

  {
    modes = { "v" },
    key = "<leader>ghr",
    desc = "git: reset hunk",
    callback = function()
      require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end,
  },
  {
    modes = { "n" },
    key = "<leader>ghs",
    desc = "git: stage hunk",
    callback = function()
      require("gitsigns").stage_hunk()
    end,
  },
  {
    modes = { "v" },
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
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
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
      vim.keymap.set({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<cr>", {
        buffer = bufnr,
        noremap = true,
        silent = true,
        desc = "git: select hunk",
      })
    end,
  },
}
