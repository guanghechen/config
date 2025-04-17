local sources = { "filesystem", "buffers", "git_status" } ---@type string[]

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
    sort_case_insensitive = true,
    sources = sources,
    source_selector = {
      winbar = false,
      statusline = false,
      show_scrolled_off_parent_node = false,
      show_separator_on_edge = true,
      content_layout = "center",
      tabs_layout = "center",
      padding = 2,
      highlight_background = "NeoTreeWinbar",
      highlight_separator = "NeoTreeTabSeparator",
      highlight_separator_active = "NeoTreeTabSeparatorActive",
      highlight_tab = "NeoTreeTab",
      highlight_tab_active = "NeoTreeTabActive",
      separator = {
        left = eve.icon.symbols.sep_left,
        right = eve.icon.symbols.sep_right,
      },
      sources = {
        {
          source = "filesystem",
          display_name = string.format(" %s Files ", eve.icon.filetype.File),
        },
        {
          source = "buffers",
          display_name = string.format(" %s Buffers ", eve.icon.ui.Buffer),
        },
        {
          source = "git_status",
          display_name = string.format(" %s Git ", eve.icon.git.Git),
        },
      },
    },
    sort_function = function(a, b)
      if a.type == b.type then
        return a.path < b.path
      end
      return a.type < b.type
    end,
    commands = {
      avante_add_files = function(state)
        local node = state.tree:get_node()
        if node.type ~= "file" and node.type ~= "directory" then
          return
        end

        local filepath = node:get_id()
        local relative_path = require("avante.utils").relative_path(filepath)
        local sidebar = require("avante").get()
        if not sidebar then
          return
        end

        local open = sidebar:is_open()
        -- ensure avante sidebar is open
        if not open then
          require("avante.api").ask()
          sidebar = require("avante").get()
        end
        sidebar.file_selector:add_selected_file(relative_path)
        sidebar.file_selector:remove_selected_file("neo-tree filesystem [1]")
      end,
      copy_filepath = function(state)
        local node = state.tree:get_node()
        if node.type ~= "file" and node.type ~= "directory" then
          return
        end

        local filepath = node:get_id()
        eve.ux.fn.select_copy_filepath({
          filepath = filepath,
          winopts = {
            relative = "cursor",
            row = 1,
            col = 4,
          },
        })
      end,
      goto_next_source = function(state)
        local source = vim.b[eve.var.Names.NEO_TREE_SOURCE] ---@type string|nil
        if type(source) ~= "string" then
          return
        end

        local index = eve.table.find_index(sources, source) ---@type integer |nil
        if index == nil then
          return
        end

        local next_source = sources[index == #sources and 1 or index + 1] ---@type string
        require("neo-tree.command").execute({
          source = next_source,
          position = state.current_position,
          action = "focus",
        })
      end,
      goto_prev_source = function(state)
        local source = vim.b[eve.var.Names.NEO_TREE_SOURCE] ---@type string|nil
        if type(source) ~= "string" then
          return
        end

        local index = eve.table.find_index(sources, source) ---@type integer |nil
        if index == nil then
          return
        end

        local next_source = sources[index == 1 and #sources or index - 1] ---@type string
        require("neo-tree.command").execute({
          source = next_source,
          position = state.current_position,
          action = "focus",
        })
      end,
      open_ghc_file_explorer = function(state)
        local node = state.tree:get_node()
        if node.type ~= "file" and node.type ~= "directory" then
          return
        end

        local filepath = node:get_id() ---@type string
        vim.cmd(eve.command.definitions.find.explorer.uuid .. " " .. filepath)
      end,
      open_ghc_file_finder = function(state)
        local node = state.tree:get_node()
        if node.type ~= "file" and node.type ~= "directory" then
          return
        end

        local filepath = node:get_id() ---@type string
        vim.cmd(eve.command.definitions.find.files_directory.uuid .. " " .. filepath)
      end,
      open_ghc_replacer = function(state)
        local node = state.tree:get_node()
        if node.type ~= "file" and node.type ~= "directory" then
          return
        end

        local filepath = node:get_id() ---@type string
        vim.cmd(eve.command.definitions.replace.files_in_directory.uuid .. " " .. filepath)
      end,
      open_ghc_searcher = function(state)
        local node = state.tree:get_node()
        if node.type ~= "file" and node.type ~= "directory" then
          return
        end

        local filepath = node:get_id() ---@type string
        vim.cmd(eve.command.definitions.search.files_in_directory.uuid .. " " .. filepath)
      end,
      recursively_toggle_all = function(neotree_state)
        local node = neotree_state.tree:get_node()
        if not node or (node.type ~= "file" and node.type ~= "directory") then
          return
        end

        if node.type == "directory" then
          if node:is_expanded() then
            neotree_state.commands.close_all_subnodes(neotree_state)
          else
            neotree_state.commands.expand_all_nodes(neotree_state, node)
          end
          return
        end

        neotree_state.commands.open(neotree_state)
      end,
      refresh_filesystem = function(neotree_state)
        require("neo-tree.sources.manager").refresh(neotree_state.name)
      end,
      show_file_info = function()
        local state = require("neo-tree.sources.manager").get_state("filesystem")
        local node = state.tree:get_node()

        if not node or node.type ~= "file" then
          return
        end

        local filepath = node.path
        local stat = vim.loop.fs_stat(filepath)
        if not stat then
          vim.notify("Failed to get file stats", vim.log.levels.ERROR)
          return
        end

        -- Format file info
        local size = string.format("%.2f KB", stat.size / 1024)
        local created = os.date("%Y-%m-%d %H:%M:%S", stat.ctime.sec)
        local modified = os.date("%Y-%m-%d %H:%M:%S", stat.mtime.sec)
        local mode = string.format("%o", stat.mode)

        local filepath_relative = eve.path.relative(eve.path.cwd(), filepath, false) ---@type string
        local filename = eve.path.basename(filepath) ---@type string
        local icon = eve.fn.fileicon(filename)

        local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
        vim.bo[bufnr].bufhidden = "wipe"
        vim.bo[bufnr].buflisted = false
        vim.bo[bufnr].buftype = "nofile"
        vim.bo[bufnr].filetype = "markdown"
        vim.bo[bufnr].swapfile = false

        ---@type eve.t.IKeymap[]
        local keymaps = {
          {
            modes = { "n" },
            key = "q",
            callback = function()
              vim.cmd.close()
              pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
            end,
            desc = "quit",
          },
        }
        eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })

        eve.ux.Printer
          .new({ name = "File info", indent = "" })
          :line("Size:      " .. size)
          :line("Created:   " .. created)
          :line("Modified:  " .. modified)
          :line("Mode:      " .. mode)
          :render(bufnr)

        vim.bo[bufnr].modifiable = false
        vim.bo[bufnr].readonly = true

        local wincfg = {
          relative = "cursor",
          width = vim.api.nvim_strwidth(filepath_relative) + 12,
          height = 4,
          row = 1,
          col = 4,
          style = "minimal",
          border = "rounded",
          title_pos = "center",
          title = " " .. icon .. " " .. filepath_relative .. " ",
        }
        local winnr = vim.api.nvim_open_win(bufnr, true, wincfg) ---@type integer
        vim.wo[winnr].number = false
        vim.wo[winnr].relativenumber = false
        vim.wo[winnr].signcolumn = "yes"
        vim.wo[winnr].winfixbuf = true
        vim.wo[winnr].wrap = false
      end,
    },
    default_component_configs = {
      container = {
        enable_character_fade = true,
      },
      diagnostics = {
        symbols = {
          hint = eve.icon.diagnostic.Hint .. " ",
          info = eve.icon.diagnostic.Information .. " ",
          warn = eve.icon.diagnostic.Warning .. " ",
          error = eve.icon.diagnostic.Error .. " ",
        },
        highlights = {
          hint = "DiagnosticSignHint",
          info = "DiagnosticSignInfo",
          warn = "DiagnosticSignWarn",
          error = "DiagnosticSignError",
        },
      },
      indent = {
        expander_collapsed = eve.icon.ui.ArrowClosed,
        expander_expanded = eve.icon.ui.ArrowOpen,
        indent_size = 2,
        indent_marker = "│",
        last_indent_marker = "╰",
        padding = 1,
        with_expanders = true,
        with_markers = true,
      },
      icon = {
        folder_closed = eve.icon.filetype.Folder,
        folder_open = eve.icon.filetype.FolderOpen,
        folder_empty = eve.icon.filetype.FolderEmpty,
        default = eve.icon.filetype.File,
      },
      modified = {
        symbol = eve.icon.ui.Modified,
      },
      name = {
        trailing_slash = false,
        use_git_status_colors = true,
      },
      git_status = {
        symbols = {
          -- Change type
          added = "", -- or "✚", but this is redundant info if you use git_status_colors on the name
          modified = "", -- or "", but this is redundant info if you use git_status_colors on the name
          deleted = eve.icon.git.Remove, -- this can only be used in the git_status source
          renamed = eve.icon.git.Rename, -- this can only be used in the git_status source
          untracked = eve.icon.git.Untracked,
          ignored = eve.icon.git.Ignore,
          unstaged = eve.icon.git.Unstaged,
          staged = eve.icon.git.Staged,
          conflict = eve.icon.git.Conflict,
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
          local keymaps = { { modes = { "i" }, key = "<esc>", callback = vim.cmd.stopinsert } } ---@type eve.t.IKeymap[]
          eve.nvim.bindkeys(keymaps, { bufnr = args.bufnr, noremap = true })
          vim.cmd.stopinsert()
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
        ["R"] = "none",
        ["S"] = "none",
        ["Z"] = "none",
        ["s"] = "none",
        ["t"] = "none",

        -- Close the window
        ["q"] = "close_window",
        ["<C-a>q"] = "close_window",
        ["<D-q>"] = "close_window",
        ["<M-q>"] = "close_window",

        -- Open file
        ["L"] = "vsplit_with_window_picker",
        ["J"] = "split_with_window_picker",
        ["w"] = "open_with_window_picker",

        -- Tree node toggle collapse
        ["<2-LeftMouse>"] = "open",
        ["<cr>"] = "open",
        ["z"] = "recursively_toggle_all",

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

        ["<leader>["] = "goto_prev_source",
        ["<leader>]"] = "goto_next_source",
        ["[["] = "goto_prev_source",
        ["]]"] = "goto_next_source",
        ["oa"] = "avante_add_files",
        ["oc"] = "copy_filepath",
        ["oe"] = "open_ghc_file_explorer",
        ["of"] = "open_ghc_file_finder",
        ["oi"] = "show_file_info",
        ["or"] = "open_ghc_replacer",
        ["os"] = "open_ghc_searcher",

        ---Sort
        ["o"] = { "show_help", nowait = false, config = { title = "Order by", prefix_key = "o" } },
        ["od"] = { "order_by_diagnostics", nowait = false },
        ["og"] = { "order_by_git_status", nowait = false },
        ["om"] = { "order_by_modified", nowait = false },
        ["on"] = { "order_by_name", nowait = false },
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
          ["h"] = "close_node",
          ["l"] = "open",
          ["<C-a>r"] = "refresh_filesystem",
          ["<D-r"] = "refresh_filesystem",
          ["<M-r>"] = "refresh_filesystem",
          ["<bs>"] = "navigate_up",
          ["."] = "set_root",
          ["H"] = "toggle_hidden",
          ["/"] = "none",
          ["D"] = "none",
        },
        fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
          ["<Down>"] = "move_cursor_down",
          ["<Up>"] = "move_cursor_up",
        },
      },
    },
    buffers = {
      follow_current_file = {
        enabled = false,
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
        return eve.editor.pick_projectable_win(winnr_source)
      end,
    }

    local function on_move(data)
      eve.lsp.on_rename(data.source, data.destination)
    end

    local events = require("neo-tree.events")

    opts.event_handlers = opts.event_handlers or {}
    vim.list_extend(opts.event_handlers, {
      { event = events.FILE_MOVED, handler = on_move },
      { event = events.FILE_RENAMED, handler = on_move },
    })
    require("neo-tree").setup(opts)
    vim.api.nvim_create_autocmd("TermClose", {
      group = eve.nvim.augroup("neotree_refresh_gitstatus"),
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
