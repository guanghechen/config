local lines = fc.fs.read_file_as_lines({ filepath = fc.path.join(fc.path.workspace(), "README.md"), silent = true }) ---@type string[]
local text = table.concat(lines, "\n")

local preview_result_1 = fc.oxi.replace_text_preview_with_matches({
  flag_case_sensitive = true,
  flag_regex = true,
  keep_search_pieces = true,
  search_pattern = "lazygit",
  replace_pattern = "__waw__",
  text = text,
})

fml.debug.log({
  preview_result_1 = fc.oxi.replace_text_preview_with_matches({
    flag_case_sensitive = true,
    flag_regex = true,
    keep_search_pieces = true,
    search_pattern = "lazygit",
    replace_pattern = "__waw__",
    text = text,
  }),
  preview_result_2 = fc.oxi.replace_text_preview_with_matches({
    flag_case_sensitive = true,
    flag_regex = false,
    keep_search_pieces = true,
    search_pattern = "lazygit",
    replace_pattern = "__waw__",
    text = text,
  }),
})
