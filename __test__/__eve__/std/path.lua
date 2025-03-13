local debug = require("eve.std.debug")

debug.log({
  eve.std.path.is_absolute("/a/b/c"),
  vim.inspect(eve.std.path.split("/a/b/c")),
  eve.std.path.relative("/a/b/c", "/a/b/c/d/e.txt", true),
  eve.std.path.relative("/a/b/c", "/a/b/c/e.txt", true),
  eve.std.path.relative("/a/b/c", "/a/b/e.txt", true),
  eve.std.path.relative("/a/b/c", "e.txt", true),
  eve.std.path.relative("a/b/c", "/a/b/c/e.txt", true),
  eve.std.path.normalize("a/b/c"),
  eve.std.path.normalize("a/b/..//c"),
  eve.std.path.normalize("/../a/../../../b/d/e/..//c"),
})
