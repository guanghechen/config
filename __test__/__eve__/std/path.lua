std.debug.log("path", {
  std.path.is_absolute("/a/b/c"),
  vim.inspect(std.path.split("/a/b/c")),
  std.path.relative("/a/b/c", "/a/b/c/d/e.txt", true),
  std.path.relative("/a/b/c", "/a/b/c/e.txt", true),
  std.path.relative("/a/b/c", "/a/b/e.txt", true),
  std.path.relative("/a/b/c", "e.txt", true),
  std.path.relative("a/b/c", "/a/b/c/e.txt", true),
  std.path.normalize("a/b/c"),
  std.path.normalize("a/b/..//c"),
  std.path.normalize("/../a/../../../b/d/e/..//c"),
})
