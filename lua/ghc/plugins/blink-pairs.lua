---@see https://github.com/saghen/blink.pairs/tree/8e935d07ab6a3843565afd6a6d56456678cbf43f

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
      },
      unmatched_group = "f_unmatched_pairs",
      matchparen = {
        enabled = true,
        cmdline = false,
        include_surrounding = true,
        group = "f_matched_pairs_0",
      },
    },
    debug = false,
  },
}
