-- https://www.lazyvim.org/configuration/recipes#change-comment-mappings
-- Change comment mappings
return {
  name = "mini.comment",
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
