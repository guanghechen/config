print(fml.path.is_absolute("/a/b/c"))
print(vim.inspect(fml.path.split("/a/b/c")))
print(fml.path.relative("/a/b/c", "/a/b/c/d/e.txt", true))
print(fml.path.relative("/a/b/c", "/a/b/c/e.txt", true))
print(fml.path.relative("/a/b/c", "/a/b/e.txt", true))
print(fml.path.relative("/a/b/c", "e.txt", true))
print(fml.path.relative("a/b/c", "/a/b/c/e.txt", true))
print(fml.path.normalize("a/b/c"))
print(fml.path.normalize("a/b/..//c"))
print(fml.path.normalize("/../a/../../../b/d/e/..//c"))
