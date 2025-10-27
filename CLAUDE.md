# Supreme Principles

The following rules are **supreme principles** that must be followed at **all times** regardless of circumstances. Each item is an **absolute principle** that **supersedes all other guidelines** and is essential to the core workflow.

1. **CRITICAL**: **Never** try to read files that are ignored by git unless I provide the filepaths explicitly.
2. **CRITICAL**: **Never** read, access, or reference any environment variable files including `.env.local`, `.env.*.local`, `*.http_request`, `*.http_response`, and any files containing sensitive information like secrets, passwords, or credentials.
3. **CRITICAL**: **Never** stage or commit changes to git unless explicitly instructed to do so. All modifications, fixes, and changes must remain in the working directory for manual review and confirmation.

## Coding Guidances

1. **ALWAYS**: Only install packages when explicitly instructed.
2. **ALWAYS**: Use `I`-prefixed naming for all types and interfaces (e.g., `IChatMessage`, `IUser`)
3. **ALWAYS**: Write clean and concise code, avoid unnecessary comments.
4. **ALWAYS**: Strictly adhere to the single responsibility principle, keep each file doing as few things as possible.
5. **ALWAYS**: Keep processing until the task is completed or an unsolvable problem is encountered, without stopping in between.
6. **ALWAYS**: You are not allowed to run any npm or yarn script except `yarn format`, `yarn lintfix`, and `yarn add`.
7. **ALWAYS**: Recognize that the user is a skilled software engineer with strong engineering and algorithmic capabilities. When facing challenging problems or complex design decisions, proactively engage in discussion with the user to seek inspiration, explore ideas, and collaborate on better solutions.
8. **ALWAYS**: Implement code in a concise, elegant, and efficient manner. Performance is crucial. Prioritize simplicity and elegance in your implementations. Caching should be the lowest priority consideration unless explicitly requested.

## Recommended Requirements

The following rules are merely recommended for adoption and can be referenced at your discretion based on the circumstances.

1. **RECOMMENDED**: Use `fd` rather than `find` command to search files.
2. **RECOMMENDED**: Use `rg` rather than `grep` command to search contents from files or piped-contents.
3. **RECOMMENDED**: When implementing a new feature, forking existing code is encouraged. Avoid rewriting existing code for reuse purposes, unless the modification is particularly simple or no other logic depends on that part of the code.

----End of the Supreme Principles----

