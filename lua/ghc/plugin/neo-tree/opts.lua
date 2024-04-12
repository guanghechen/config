local function recursively_toggle(state, toggle_directory)
  require("ghc.plugin.neo-tree.util").neotree_recursive_toggle(state, toggle_directory, false)
end

local function recursively_toggle_all(state, toggle_directory)
  require("ghc.plugin.neo-tree.util").neotree_recursive_toggle(state, toggle_directory, true)
end

return {
  window = {
    commands = {
      recursively_toggle = function(state, toggle_directory)
        require("ghc.plugin.neo-tree.util").neotree_recursive_toggle(state, toggle_directory, false)
      end,
      recursively_toggle_all = function(state, toggle_directory)
        require("ghc.plugin.neo-tree.util").neotree_recursive_toggle(state, toggle_directory, true)
      end,
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
      ["P"] = {
        "toggle_preview",
        config = {
          use_float = true,
          use_image_nvim = true,
        },
      },
      ["R"] = "refresh",
    },
  },
}
