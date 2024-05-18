local icons = require("ghc.core.setting.icons")

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
  require("trouble.providers.telescope").open_with_trouble(...)
end

local function close_telescope(...)
  require("telescope.actions").close(...)
end

local function loadTelescopeExtension(ext)
  return function()
    require("telescope").load_extension(ext)
  end
end

return {
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        prompt_prefix = icons.ui.Telescope .. "  ",
        selection_caret = icons.ui.ChevronRight .. " ", --" ",
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
          },
          n = {
            q = close_telescope,
            s = flash,
            ["<esc>"] = false,
            ["<c-t>"] = open_with_trouble,
          },
        },
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
  },
  {
    "nvim-telescope/telescope-frecency.nvim",
    config = loadTelescopeExtension("frecency"),
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = vim.fn.executable("make") == 1 and "make"
      or "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
    enabled = vim.fn.executable("make") == 1 or vim.fn.executable("cmake") == 1,
    config = loadTelescopeExtension("fzf"),
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "nvim-telescope/telescope-file-browser.nvim",
    config = loadTelescopeExtension("file_browser"),
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
}
