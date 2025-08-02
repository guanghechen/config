return {
  name = "blink.pairs",
  event = "VeryLazy",
  build = "cargo build --release",
  opts = {
    mappings = {
      enabled = true,
      cmdline = true,
      disabled_filetypes = eve.filetype.list_not_sourcefile_filetypes(),
    },
    highlights = {
      enabled = true,
      cmdline = true,
      groups = {
        "f_matched_pairs_1",
        "f_matched_pairs_2",
        "f_matched_pairs_3",
        "f_matched_pairs_4",
        "f_matched_pairs_5",
        "f_matched_pairs_6",
        "f_matched_pairs_7",
      },
      unmatched_group = "f_unmatched_pairs",
      matchparen = {
        enabled = true,
        cmdline = false,
        group = "f_matched_pairs_0",
      },
    },
    debug = false,
  },
}
