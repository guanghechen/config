Help me to implement the `rstd` path module (I wish to use it as `require("rstd").path.xxx`), implement into the @rust/rstd/src/path.rs

## Implementation Specification

We want to implement a robust and performant path module in rust for lua use cases, since it used as my personal standard library, so must make the codes concise, performant and robust. It should have below interface for the path, I give you the typescript interface for reference, but you need to implement it in rust with robust and performant way. FYI, you can refer the @lua/std/path.lua module implementation:

```typescript
export const SEP: string // The platform-specific path segment separator (`'/'` or `'\'`)

export function is_absolute(filepath: string): boolean // Returns true if the path is absolute
export function is_dirpath(filepath: string): boolean // Returns true if the path is a directory path (ends with a separator, no need to check whether if it exists)
export function is_exist(filepath: string): boolean // Returns true if the path exists in the filesystem
export function is_exist_dirpath(filepath: string): boolean // Returns true if the directory path exists in the filesystem
export function is_descendant(from: string, to: string): boolean // Returns true if `to` path is a descendant of the `from` path

export function dirname(filepath: string): string // Returns the directory path of a path
export function basename(filepath: string): string // Returns the last portion of a path
export function extname(filepath: string): string // Returns the file extension of the path

export function split(filepath: string): string[] // Splits a path into its components by the '/' and '\' (must split both type separators since we cannot assume the input path use the platform-specific separator)
export function join(from: string, to: string, sep?: "/"|"\\"): string // Joins two paths together with the provided separator (falls back to platform separator when omitted)
export function relative(from: string, to: string, sep?: "/"|"\\") // Returns the relative path from `from` to `to`, using the provided separator or the platform separator when omitted
export function relative_dir(from: string, to: string, sep?: "/"|"\\") // Similar to the `relative` function, but if the `to` path is a dir path (with '/' or '\' suffix), then we keep the separator at the end of the result path)
export function normalize(filepath: string, sep?: "/"|"\\", keep_trailing_slash?: boolean): string // Normalizes a path, resolving `..` and `.` segments with the provided separator or the platform default. When keep_trailing_slash is true, preserves trailing slashes from the input (except for drive roots like "C:"). Defaults to false.

export function mkdirs(dirpath: string): void // Creates a directory and all its parent components if they do not exist
export function locate_nearest(start_dirpath: string, filenames: string[]): string|null // Locates the nearest file from the `start_dirpath` by searching upwards the directory tree, returns the found file path or null if not found
```

## Test Specification

Let's add test cases for the path module, the test file should placed at @rust/rstd/tests/path_tests.rs, please cover all the methods and edge cases.

## Requirements

1. **CRITICAL**: Since I would to like to implement a standard library for lua use cases, so please avoid to use neovim relative crates like the `nvim-oxi`, we don't need it in this module.
