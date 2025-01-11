local fn = require("eve.builtin.fn")
local icons = require("eve.constant.icon")

---@return nil
local function recursively_toggle_all(state)
  local node = state.tree:get_node()
  if not node then
    return
  end

  if node.type == "directory" then
    if node:is_expanded() then
      state.commands.close_all_subnodes(state)
    else
      state.commands.expand_all_nodes(state, node)
    end
    return
  end

  state.commands.open(state)
end

---@return nil
local function refresh_filesystem(state)
  require("neo-tree.sources.manager").refresh(state.name)
end

-- Sorts files and directories descendantly.
local function sort_function(a, b)
  if a.type == b.type then
    return a.path < b.path
  end
  return a.type < b.type
end

return {
  name = "neo-tree.nvim",
  cmd = "Neotree",
  deactivate = function()
    vim.cmd([[Neotree close]])
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
      diagnostics = {
        symbols = {
          hint = icons.diagnostic.Hint .. " ",
          info = icons.diagnostic.Information .. " ",
          warn = icons.diagnostic.Warning .. " ",
          error = icons.diagnostic.Error .. " ",
        },
        highlights = {
          hint = "DiagnosticSignHint",
          info = "DiagnosticSignInfo",
          warn = "DiagnosticSignWarn",
          error = "DiagnosticSignError",
        },
      },
      indent = {
        indent_size = 2,
        padding = 1, -- extra padding on left hand side
        with_markers = true,
        indent_marker = "│",
        last_indent_marker = "└",
        highlight = "NeoTreeIndentMarker",
        with_expanders = true,
        expander_collapsed = icons.ui.ArrowClosed,
        expander_expanded = icons.ui.ArrowOpen,
        expander_highlight = "NeoTreeExpander",
      },
      icon = {
        folder_closed = icons.filetype.Folder,
        folder_open = icons.filetype.FolderOpen,
        folder_empty = icons.filetype.FolderEmpty,
        default = icons.filetype.File,
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

          ---@type eve.t.IKeymap[]
          local keymaps = {
            { modes = { "i" }, key = "<esc>", callback = vim.cmd.stopinsert },
          }
          fn.bindkeys(keymaps, { bufnr = args.bufnr, noremap = true })
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
        ["B"] = "none",
        ["C"] = "none",
        ["D"] = "none",
        ["q"] = "none",
        ["R"] = "none",
        ["S"] = "none",
        ["Z"] = "none",
        ["s"] = "none",
        ["t"] = "none",

        -- Open file
        ["L"] = "vsplit_with_window_picker",
        ["J"] = "split_with_window_picker",
        ["w"] = "open_with_window_picker",

        -- Tree node toggle collapse
        ["<2-LeftMouse>"] = "open",
        ["<cr>"] = "open",
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

        ---Sort
        ["o"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "o" } },
        ["oc"] = { "order_by_created", nowait = false },
        ["od"] = { "order_by_diagnostics", nowait = false },
        ["og"] = { "order_by_git_status", nowait = false },
        ["om"] = { "order_by_modified", nowait = false },
        ["on"] = { "order_by_name", nowait = false },
        ["os"] = { "order_by_size", nowait = false },
        ["ot"] = { "order_by_type", nowait = false },

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
        enabled = false,
        leave_dirs_open = true,
      },
      group_empty_dirs = true, -- when true, empty folders will be grouped together
      window = {
        mappings = {
          ["<M-r>"] = refresh_filesystem,
          ["<C-a>r"] = refresh_filesystem,
          ["<bs>"] = "navigate_up",
          ["."] = "set_root",
          ["H"] = "toggle_hidden",
          ["/"] = "none",
          ["D"] = "none",
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
          ["gu"] = "none",
          ["ga"] = "none",
          ["gr"] = "none",
          ["gc"] = "none",
          ["gp"] = "none",
          ["gg"] = "none",
        },
      },
    },
  },
  config = function(_, opts)
    package.loaded["window-picker"] = {
      pick_window = function()
        local winnr_source = vim.api.nvim_get_current_win() ---@type integer
        local winpicker = require("eve.module.winpicker")
        return winpicker.pick_window(winpicker.filters.project, winnr_source, false)
      end,
    }

    local function on_move(data)
      require("guanghechen.lsp.common").on_rename(data.source, data.destination)
    end

    local events = require("neo-tree.events")

    opts.event_handlers = opts.event_handlers or {}
    vim.list_extend(opts.event_handlers, {
      { event = events.FILE_MOVED, handler = on_move },
      { event = events.FILE_RENAMED, handler = on_move },
    })
    require("neo-tree").setup(opts)
    vim.api.nvim_create_autocmd("TermClose", {
      group = fn.augroup("neotree_refresh_gitstatus"),
      pattern = "*lazygit",
      callback = function()
        if package.loaded["neo-tree.sources.git_status"] then
          require("neo-tree.sources.git_status").refresh()
        end
      end,
    })
  end,
  dependencies = {
    "mini.icons",
    "nui.nvim",
    "plenary.nvim",
  },
}
