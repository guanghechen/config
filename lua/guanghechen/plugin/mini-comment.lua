-- https://www.lazyvim.org/configuration/recipes#change-comment-mappings
-- Change comment mappings
return {
  url = "https://github.com/guanghechen/mirror.git",
  branch = "nvim@mini.comment",
  name = "mini.comment",
  main = "mini.comment",
  keys = {
    { "gc",  mode = { "n", "v" } },
    { "gcc", mode = { "n", "v" } },
  },
  opts = {
    mappings = {
      comment = "gc",
      comment_line = "gcc",
      comment_visual = "gc",
      textobject = "gcc",
    },
  },
}
