local icons = {
  ui = require("ghc.core.icons").get("ui", true),
}

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

local opts = {
  defaults = {
    prompt_prefix = icons.ui.Telescope .. " ",
    selection_caret = icons.ui.ChevronRight, --" ",
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
    mapping = {
      n = { s = flash },
      i = { ["<c-s>"] = flash },
    },
  },
  extensions = {
    file_browser = {},
    frecency = {
      auto_validate = true,
      db_safe_mode = true,
      db_validate_threshold = 5,
      use_sqlite = false,
      show_scores = false,
      show_unindexed = true,
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
      case_mode = "smart_case",
    },
    live_grep_args = {
      auto_quoting = true, -- enable/disable auto-quoting
    },
  },
}

return opts
