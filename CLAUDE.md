# Supreme Requirements

The following rules are supreme principles that must be followed at all times regardless of circumstances.

1. **CRITICAL**: Don't try to read files that are ignored by git unless I provide the filepaths explicitly.
2. **CRITICAL**: Never read, access, or reference any environment variable files including `.env.local`, `.env.*.local`, `*.http_request`, `*.http_response`, and any files containing sensitive information like secrets, passwords, or credentials.

## Coding Guidances

1. **MUST**: Don't try to install anything unless I ask you to explicitly.
2. **MUST**: Use `I`-prefixed naming for all types and interfaces (e.g., `IChatMessage`, `IUser`)
3. **MUST**: Write clean and concise code, avoid unnecessary comments.
4. **MUST**: Strictly adhere to the single responsibility principle, keep each file doing as few things as possible.
5. **MUST**: Keep processing until the task is completed or an unsolvable problem is encountered, without stopping in between.
6. **MUST**: You are not allowed to run any npm or yarn script except the `yarn format`, `yarn lintfix` and the `yarn add`.

## Recommended Requirements

The following rules are merely recommended for adoption and can be referenced at your discretion based on the circumstances.

1. **RECOMMENDED**: use `fd` instead of `find` command to search files.
2. **RECOMMENDED**: use `rg` instead of `grep` command to search contents from files or piped-contents.
3. **RECOMMENDED**: When implementing a new feature, forking existing code is encouraged. Try to avoid considering rewriting existing code to achieve reuse, unless the modification is particularly simple or no other logic depends on that part of the code.

