local function flash(prompt_bufnr)
  require("flash").jump({
    pattern = "^",
    label = { after = { 0, 0 } },
    search = {
      mode = "search",
      exclude = {
        function(win)
          return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "TelescopeResults"
        end,
      },
    },
    action = function(match)
      local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
      picker:set_selection(match.pos[1] - 1)
    end,
  })
end

local function open_with_trouble(...)
  require("trouble.sources.telescope").open(...)
end

local function close_telescope(...)
  require("telescope.actions").close(...)
end

local function cycle_history_prev(...)
  require("telescope.actions").cycle_history_prev(...)
end

local function cycle_history_next(...)
  require("telescope.actions").cycle_history_next(...)
end

local function preview_scrolling_up(...)
  require("telescope.actions").preview_scrolling_up(...)
end

local function preview_scrolling_down(...)
  require("telescope.actions").preview_scrolling_down(...)
end

return {
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = {
      prompt_prefix = ghc.ui.icons.ui.Telescope .. "  ",
      selection_caret = ghc.ui.icons.ui.ChevronRight .. " ", --" ",
      border = {},
      borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
      color_devicons = true,
      set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
      dynamic_preview_title = true,
      file_ignore_patterns = { ".git/", ".cache", "build/", "%.class", "%.pdf", "%.mkv", "%.mp4", "%.zip" },
      initial_mode = "insert",
      layout_config = {
        horizontal = {
          prompt_position = "top",
          preview_width = 0.55,
          results_width = 0.8,
        },
        vertical = {
          mirror = false,
        },
        width = 0.87,
        height = 0.80,
        preview_cutoff = 120,
      },
      layout_strategy = "horizontal",
      -- path_display = { "absolute" },
      results_title = false,
      scroll_strategy = "cycle",
      selection_strategy = "reset",
      sorting_strategy = "ascending",
      use_less = false,
      wrap_results = false,
      mappings = {
        i = {
          ["<c-s>"] = flash,
          ["<c-t>"] = open_with_trouble,
          ["<c-Up>"] = cycle_history_prev,
          ["<c-Down>"] = cycle_history_next,
          ["<c-b>"] = preview_scrolling_up,
          ["<c-f>"] = preview_scrolling_down,
        },
        n = {
          q = close_telescope,
          s = flash,
          ["<esc>"] = false,
          ["<c-t>"] = open_with_trouble,
        },
      },
      -- open files in the first window that is an actual file.
      -- use the current window if no other window is available.
      get_selection_window = function()
        local wins = vim.api.nvim_list_wins()
        table.insert(wins, 1, vim.api.nvim_get_current_win())
        for _, win in ipairs(wins) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].buftype == "" then
            return win
          end
        end
        return 0
      end,
    },
    extensions = {
      file_browser = {},
      frecency = {
        auto_validate = true,
        db_safe_mode = true,
        db_validate_threshold = 5,
        default_workspace = "CWD",
        use_sqlite = false,
        show_filter_column = false,
        show_scores = false,
        show_unindexed = true,
        workspace_scan_cmd = {
          "fd",
          "--hidden",
          "--type",
          "file",
          "--color=never",
          "--follow",
        },
        ignore_patterns = {
          "*.git/*",
          "*/tmp/*",
          "*/node_modules/*",
          ".yarn/*",

          -- for windows
          [[*.git\*]],
          [[*\tmp\*]],
          [[*\node_modules\*]],
          [[.yarn\*]],
        },
      },
      fzf = {
        fuzzy = false,
        override_generic_sorter = true,
        override_file_sorter = true,
        case_mode = "respect_case",
      },
    },
  },
  config = function(_, opts)
    dofile(vim.g.base46_cache .. "telescope")
    require("telescope").setup(opts)
  end,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "nvim-telescope/telescope-fzf-native.nvim",
  },
}
