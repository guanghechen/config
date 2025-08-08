# Supreme Requirements

The following rules are supreme principles that must be followed at all times regardless of circumstances.

1. **MUST**: Don't try to read files that are ignored by git unless I provide the filepaths explicitly.
2. **MUST**: Don't try to install anything unless I ask you to explicitly.
3. **MUST**: Use `I`-prefixed naming for all types and interfaces (e.g., `IChatMessage`, `IUser`)
4. **MUST**: Write clean and concise code, avoid unnecessary comments.
5. **MUST**: Strictly adhere to the single responsibility principle, keep each file doing as few things as possible.

# Recommended Requirements

The following rules are merely recommended for adoption and can be referenced at your discretion based on the circumstances.

1. **RECOMMENDED**: When implementing a new feature, forking existing code is encouraged. Try to avoid considering rewriting existing code to achieve reuse, unless the modification is particularly simple or no other logic depends on that part of the code.
