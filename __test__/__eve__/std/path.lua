local path = require("eve.lib.path")
local debug = require("eve.builtin.debug")

debug.log({
  path.is_absolute("/a/b/c"),
  vim.inspect(path.split("/a/b/c")),
  path.relative("/a/b/c", "/a/b/c/d/e.txt", true),
  path.relative("/a/b/c", "/a/b/c/e.txt", true),
  path.relative("/a/b/c", "/a/b/e.txt", true),
  path.relative("/a/b/c", "e.txt", true),
  path.relative("a/b/c", "/a/b/c/e.txt", true),
  path.normalize("a/b/c"),
  path.normalize("a/b/..//c"),
  path.normalize("/../a/../../../b/d/e/..//c"),
})
