return {
  window = {
    mappings = {
      ["<2-LeftMouse>"] = "open",
      ["<cr>"] = "open",
      ["<esc>"] = "cancel", -- close preview or floating neo-tree window
      ["P"] = {
        "toggle_preview",
        config = {
          use_float = true,
          use_image_nvim = true,
        },
      },
      ["l"] = "focus_preview",
      ["S"] = "split_with_window_picker",
      ["s"] = "vsplit_with_window_picker",
      ["t"] = "open_tabnew",
      ["w"] = "open_with_window_picker",
      ["C"] = "close_all_subnodes",
      ["a"] = {
        "add", -- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
        config = {
          show_path = "relative", -- "none", "relative", "absolute"
        },
      },
      ["A"] = "add_directory", -- also accepts the optional config.show_path option like "add". this also supports BASH style brace expansion.
      ["d"] = "delete",
      ["r"] = "rename",
      ["y"] = "copy_to_clipboard",
      ["x"] = "cut_to_clipboard",
      ["p"] = "paste_from_clipboard",
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
      ["q"] = "close_window",
      ["R"] = "refresh",
      ["?"] = "show_help",
      ["<"] = "prev_source",
      [">"] = "next_source",
      ["i"] = "show_file_details",
    },
  },
}