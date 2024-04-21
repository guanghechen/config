local function recursively_toggle(state, toggle_directory)
  require("ghc.plugin.neo-tree.util").neotree_recursive_toggle(state, toggle_directory, false)
end

local function recursively_toggle_all(state, toggle_directory)
  require("ghc.plugin.neo-tree.util").neotree_recursive_toggle(state, toggle_directory, true)
end

return {
  sources = { "filesystem", "buffers", "git_status", "document_symbols" },
  open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline" },
  filesystem = {
    bind_to_cwd = false,
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true,
  },
  window = {
    commands = {
      recursively_toggle = function(state, toggle_directory)
        require("ghc.plugin.neo-tree.util").neotree_recursive_toggle(state, toggle_directory, false)
      end,
      recursively_toggle_all = function(state, toggle_directory)
        require("ghc.plugin.neo-tree.util").neotree_recursive_toggle(state, toggle_directory, true)
      end,
    },
    default_component_configs = {
      indent = {
        with_expanders = true, -- if nil and file nesting is enabled, will enable expanders
        expander_collapsed = "",
        expander_expanded = "",
        expander_highlight = "NeoTreeExpander",
      },
    },
    mappings = {
      -- Reset
      ["<space>"] = "none",
      ["[g"] = "none",
      ["]g"] = "none",
      ["A"] = "none",
      ["C"] = "none",
      ["D"] = "none",
      ["f"] = "none",
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
}
