local icons = require("ghc.core.setting.icons")

local function recursively_toggle(state, toggle_directory)
  require("ghc.core.util.neo-tree").neotree_recursive_toggle(state, toggle_directory, false)
end

local function recursively_toggle_all(state, toggle_directory)
  require("ghc.core.util.neo-tree").neotree_recursive_toggle(state, toggle_directory, true)
end

-- Sorts files and directories descendantly.
local function sort_function(a, b)
  if a.type == b.type then
    return a.path < b.path
  end
  return a.type < b.type
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  cmd = "Neotree",
  deactivate = function()
    vim.cmd([[Neotree close]])
  end,
  init = function()
    -- Initial open the neo-tree if nvim enter with a directory.
    -- if vim.fn.argc(-1) == 1 then
    --   local stat = vim.uv.fs_stat(vim.fn.argv(0))
    --   if stat and stat.type == "directory" then
    --     require("neo-tree")
    --   end
    -- end
  end,
  keys = {},
  opts = {
    close_if_last_window = false,
    enable_git_status = true,
    enable_diagnostics = true,
    open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline" },
    popup_border_style = "rounded",
    sort_case_insensitive = true, -- used when sorting files and directories in the tree
    sort_function = sort_function,
    sources = { "filesystem", "buffers", "git_status", "document_symbols" },
    default_component_configs = {
      container = {
        enable_character_fade = true,
      },
      indent = {
        indent_size = 2,
        padding = 1, -- extra padding on left hand side
        with_markers = true,
        indent_marker = "│",
        last_indent_marker = "└",
        highlight = "NeoTreeIndentMarker",
        with_expanders = true,
        expander_collapsed = "",
        expander_expanded = "",
        expander_highlight = "NeoTreeExpander",
      },
      icon = {
        folder_closed = icons.ui.Folder,
        folder_open = icons.ui.FolderOpen,
        folder_empty = icons.ui.EmptyFolder,
        default = icons.ui.File,
        highlight = "NeoTreeFileIcon",
      },
      modified = {
        symbol = icons.ui.Modified,
        highlight = "NeoTreeModified",
      },
      name = {
        trailing_slash = false,
        use_git_status_colors = true,
        highlight = "NeoTreeFileName",
      },
      git_status = {
        symbols = {
          -- Change type
          added = "", -- or "✚", but this is redundant info if you use git_status_colors on the name
          modified = "", -- or "", but this is redundant info if you use git_status_colors on the name
          deleted = icons.git.Remove, -- this can only be used in the git_status source
          renamed = icons.git.Rename, -- this can only be used in the git_status source
          -- Status type
          untracked = icons.git.Untracked,
          ignored = icons.git.Ignore,
          unstaged = icons.git.Unstaged,
          staged = icons.git.Staged,
          conflict = icons.git.Conflict,
        },
      },
      -- If you don't want to use these columns, you can set `enabled = false` for each of them individually
      file_size = {
        enabled = false,
      },
      type = {
        enabled = false,
      },
      last_modified = {
        enabled = false,
      },
      created = {
        enabled = false,
      },
      symlink_target = {
        enabled = false,
      },
    },
    event_handlers = {
      {
        event = "neo_tree_popup_input_ready",
        ---@param args { bufnr: integer, winid: integer }
        handler = function(args)
          vim.cmd("stopinsert")
          vim.keymap.set("i", "<esc>", vim.cmd.stopinsert, { noremap = true, buffer = args.bufnr })
        end,
      },
    },
    window = {
      position = "left",
      width = 40,
      mapping_options = {
        noremap = true,
        nowait = true,
      },
      mappings = {
        -- Reset
        ["<space>"] = "none",
        ["[g"] = "none",
        ["]g"] = "none",
        ["A"] = "none",
        ["C"] = "none",
        ["D"] = "none",
        ["B"] = "none",
        ["q"] = "none",
        ["S"] = "none",
        ["s"] = "none",
        ["t"] = "none",
        ["Z"] = "none",

        -- Open file
        ["L"] = "vsplit_with_window_picker",
        ["J"] = "split_with_window_picker",
        ["w"] = "open_with_window_picker",

        -- Tree node toggle collapse
        ["<2-LeftMouse>"] = "open",
        ["<cr>"] = recursively_toggle,
        ["z"] = recursively_toggle_all,

        -- Add / Copy / Move
        ["a"] = {
          "add", -- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
          config = {
            show_path = "relative", -- "none", "relative", "absolute"
          },
        },
        ["c"] = {
          "copy",
          config = {
            show_path = "relative", -- "none", "relative", "absolute"
          },
        },
        ["m"] = {
          "move",
          config = {
            show_path = "relative", -- "none", "relative", "absolute"
          },
        },

        -- Misc
        ["<esc>"] = "cancel", -- close preview or floating neo-tree window
        ["O"] = {
          function(state)
            require("lazy.util").open(state.tree:get_node().path, { system = true })
          end,
          desc = "Open with System Application",
        },
        ["P"] = {
          "toggle_preview",
          config = {
            use_float = true,
            use_image_nvim = true,
          },
        },
        ["R"] = "refresh",
        ["Y"] = {
          function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            vim.fn.setreg("+", path, "c")
          end,
          desc = "Copy Path to Clipboard",
        },
      },
    },
    filesystem = {
      bind_to_cwd = false,
      use_libuv_file_watcher = true,
      filtered_items = {
        visible = false, -- when true, they will just be displayed differently than normal items
        hide_dotfiles = false,
        hide_gitignored = false,
        hide_hidden = false, -- only works on Windows for hidden files/directories
        hide_by_name = {
          ".git",
          --"node_modules"
        },
        hide_by_pattern = { -- uses glob style patterns
          --"*.meta",
          --"*/src/*/tsconfig.json",
        },
        always_show = { -- remains visible even if other settings would normally hide it
          ".editorconfig",
          ".eslintrc",
          ".gitignore",
          ".prettierrc",
        },
        never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
          --".DS_Store",
          --"thumbs.db"
        },
        never_show_by_pattern = { -- uses glob style patterns
          --".null-ls_*",
        },
      },
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
      group_empty_dirs = true, -- when true, empty folders will be grouped together
      window = {
        mappings = {
          ["<bs>"] = "navigate_up",
          ["."] = "set_root",
          ["H"] = "toggle_hidden",
          ["/"] = "fuzzy_finder",
          ["D"] = "fuzzy_finder_directory",
          ["o"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "o" } },
          ["oc"] = { "order_by_created", nowait = false },
          ["od"] = { "order_by_diagnostics", nowait = false },
          ["og"] = { "order_by_git_status", nowait = false },
          ["om"] = { "order_by_modified", nowait = false },
          ["on"] = { "order_by_name", nowait = false },
          ["os"] = { "order_by_size", nowait = false },
          ["ot"] = { "order_by_type", nowait = false },
        },
        fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
          ["<down>"] = "move_cursor_down",
          ["<up>"] = "move_cursor_up",
        },
      },
    },
    buffers = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
      group_empty_dirs = true, -- when true, empty folders will be grouped together
      show_unloaded = true,
      window = {
        position = "float",
        mappings = {
          ["bd"] = "buffer_delete",
          ["<bs>"] = "navigate_up",
          ["."] = "set_root",
          ["o"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "o" } },
          ["oc"] = { "order_by_created", nowait = false },
          ["od"] = { "order_by_diagnostics", nowait = false },
          ["om"] = { "order_by_modified", nowait = false },
          ["on"] = { "order_by_name", nowait = false },
          ["os"] = { "order_by_size", nowait = false },
          ["ot"] = { "order_by_type", nowait = false },
        },
      },
    },
    git_status = {
      follow_current_file = {
        enabled = true,
        leave_dirs_open = true,
      },
      group_empty_dirs = true, -- when true, empty folders will be grouped together
      window = {
        position = "float",
        mappings = {
          ["A"] = "git_add_all",
          ["gu"] = "git_unstage_file",
          ["ga"] = "git_add_file",
          ["gr"] = "git_revert_file",
          ["gc"] = "git_commit",
          ["gp"] = "git_push",
          ["gg"] = "git_commit_and_push",
          ["o"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "o" } },
          ["oc"] = { "order_by_created", nowait = false },
          ["od"] = { "order_by_diagnostics", nowait = false },
          ["om"] = { "order_by_modified", nowait = false },
          ["on"] = { "order_by_name", nowait = false },
          ["os"] = { "order_by_size", nowait = false },
          ["ot"] = { "order_by_type", nowait = false },
        },
      },
    },
  },
  config = function(_, opts)
    local function on_move(data)
      require("ghc.core.lsp.common").on_rename(data.source, data.destination)
    end

    local events = require("neo-tree.events")

    -- Set icons for diagnostic errors, you'll need to define them somewhere:
    vim.fn.sign_define("DiagnosticSignError", { text = icons.diagnostics.Error .. " ", texthl = "DiagnosticSignError" })
    vim.fn.sign_define("DiagnosticSignWarn", { text = icons.diagnostics.Warning .. " ", texthl = "DiagnosticSignWarn" })
    vim.fn.sign_define("DiagnosticSignInfo", { text = icons.diagnostics.Information .. " ", texthl = "DiagnosticSignInfo" })
    vim.fn.sign_define("DiagnosticSignHint", { text = icons.diagnostics.Hint .. " ", texthl = "DiagnosticSignHint" })

    opts.event_handlers = opts.event_handlers or {}
    vim.list_extend(opts.event_handlers, {
      { event = events.FILE_MOVED, handler = on_move },
      { event = events.FILE_RENAMED, handler = on_move },
    })
    require("neo-tree").setup(opts)
    vim.api.nvim_create_autocmd("TermClose", {
      pattern = "*lazygit",
      callback = function()
        if package.loaded["neo-tree.sources.git_status"] then
          require("neo-tree.sources.git_status").refresh()
        end
      end,
    })
  end,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "nvim-window-picker",
  },
}
