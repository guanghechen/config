eve.debug({
  eve.path.is_absolute("/a/b/c"),
  vim.inspect(eve.path.split("/a/b/c")),
  eve.path.relative("/a/b/c", "/a/b/c/d/e.txt", true),
  eve.path.relative("/a/b/c", "/a/b/c/e.txt", true),
  eve.path.relative("/a/b/c", "/a/b/e.txt", true),
  eve.path.relative("/a/b/c", "e.txt", true),
  eve.path.relative("a/b/c", "/a/b/c/e.txt", true),
  eve.path.normalize("a/b/c"),
  eve.path.normalize("a/b/..//c"),
  eve.path.normalize("/../a/../../../b/d/e/..//c"),
})
