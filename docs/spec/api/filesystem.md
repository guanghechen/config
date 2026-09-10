# Filesystem roots and workspaces

The server owns file access permissions. The browser owns its workspace list and
selected root. Every root and file path exchanged through the API is an absolute
path in the server's filesystem; selecting a workspace never grants access.

## Server configuration

Configuration is loaded once at server startup. Values already present in the
process environment take precedence, followed by `.env.local`, then `.env`; restart
the server after changing any of them. Use `.env.local` for credentials and other
machine-local values. Both `.env.local` and `.env` are local configuration files and
must remain ignored by Git.

Root variables are JSON arrays, even when they contain one path:

```dotenv
YOZ_ALLOWED_ROOTS='["/home/user/projects"]'
YOZ_DEFAULT_WORKSPACE_ROOTS='["/home/user/projects/example/docs"]'
```

Quoted dotenv values may span lines when a longer list is easier to read:

```dotenv
YOZ_ALLOWED_ROOTS='[
  "/home/user/projects",
  "~/private-projects"
]'
```

- `YOZ_ALLOWED_ROOTS`: directories within which files may be read, listed, watched,
  switched to or saved. `[]` explicitly denies all user-file access.
- `YOZ_DEFAULT_WORKSPACE_ROOTS`: initial browser workspace entries. Each must be an
  existing directory inside the allowlist. When omitted, defaults are the allowed
  roots. An explicit `[]` supplies no initial entries.
- Configuration accepts `~` and `~/...` and resolves symlinks to canonical absolute
  paths. Relative roots, missing directories and malformed JSON fail startup.
- File requests require absolute paths, use component-aware containment and check
  the real symlink target. Paths outside the allowlist return 403; missing paths
  inside it return 404; malformed paths and wrong file/directory kinds return 400.
  Save only updates existing regular files.

Existing authentication remains in place; missing or expired credentials return 401,
while denied filesystem access returns 403. The editor's `/api/file/switch` endpoint
keeps its existing public status, but now validates the path before publishing a
switch or opening a browser. These roots govern user-file APIs, not the application's
own templates, transform configuration or Vite development assets.

## Browser and API

- The browser persists workspace roots locally and can add or remove any authorized
  subdirectory. Server defaults seed a new browser list; they do not overwrite it.
- Workspace URL: `/ws?root=<absolute directory>&filepath=<absolute file>`.
- Standalone file URL: `/file?filepath=<absolute file>`.
- `GET /api/workspaces` returns `data.defaultWorkspaceRoots` and
  `data.legacyWorkspaces` (`{tag, path}` entries for bookmark migration).
- `GET /api/workspace/files?root=...` returns canonical `data.root` and
  `data.files`, an absolute-path list.
- File/raw requests take `filepath`; save takes `{filepath, content}`. WebSocket
  file events carry `{filepath}` and are delivered only after the socket
  authenticates with the application's JWT. The workspace is no longer part of
  file identity.
- Query values use standard `URLSearchParams` encoding, exactly once.
- Markdown local links/images resolve against the Markdown file's directory;
  resource requests and `sourcefile` inclusions are authorized independently.

## Legacy configuration

If `YOZ_ALLOWED_ROOTS` is absent, the bundled demo directory and existing
`YOZ_WORKSPACE_<TAG>` directories become allowed roots and default workspace roots.
An explicit `YOZ_ALLOWED_ROOTS='[]'` does not use that fallback: it denies all
user-file access. Likewise, a missing `YOZ_DEFAULT_WORKSPACE_ROOTS` defaults to the
allowed roots, while an explicit `YOZ_DEFAULT_WORKSPACE_ROOTS='[]'` seeds no browser
workspace entries.

The legacy fallback exists for migration. New configurations should set
`YOZ_ALLOWED_ROOTS` and `YOZ_DEFAULT_WORKSPACE_ROOTS` explicitly. Keep a
`YOZ_WORKSPACE_<TAG>` variable only while its old `/ws/<tag>` bookmarks still need a
mapping.

When an explicit allowlist is present, legacy workspace tags only provide bookmark
mappings for authorized directories; they never extend the allowlist. Old
`/ws/<tag>` bookmarks migrate to the absolute-root URL. Unknown or unauthorized tags
fail explicitly. External API callers must send absolute `filepath` values and
remove the former `workspace` parameter.
