return {
  window = {
    mappings = {
      ["<2-LeftMouse>"] = "open",
      ["<cr>"] = "open",
      ["<esc>"] = "cancel", -- close preview or floating neo-tree window
      ["<space>"] = "none",
      ["P"] = {
        "toggle_preview",
        config = {
          use_float = true,
          use_image_nvim = true,
        },
      },
      ["w"] = "open_with_window_picker",
      ["C"] = "close_all_subnodes",
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
      ["q"] = "none",
      ["R"] = "refresh",
    },
  },
}
