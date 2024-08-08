local filepaths = fml.oxi.find({
  cwd = fml.path.workspace(),
  use_regex = false,
  case_sensitive = false,
  search_pattern = ".lua",
  search_paths = "lua/,rust/",
  exclude_patterns = "",
})

fml.debug.log("filepaths:", filepaths or "nil")
