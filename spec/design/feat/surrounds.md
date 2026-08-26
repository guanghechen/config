# Surrounds Feature

## Scope

`era.m.surrounds` is the repository-owned surround implementation. It replaces the external
`mini.surround` plugin while preserving the locally used behavior and removing runtime customization.
It is an independent local implementation informed by `mini.surround` behavior.

## Module Boundaries

```text
init.lua       -> public facade and module composition
action.lua     -> surrounding actions, dot-repeat cache, and operator callbacks
keymap.lua     -> fixed mappings and buffer attachment lifecycle
definition.lua -> surrounding identifier input and fixed input/output definitions
search.lua     -> composed-pattern and span search
buffer.lua     -> Neovim marks, regions, cursor movement, mutation, and highlighting
types.lua      -> shared LuaLS types
```

All modules remain inside the `era` layer. They may depend on `dot`, `stl`, `yoz`, and Neovim APIs;
lower layers must not depend on surrounds.

## Stable Behavior

The fixed keymap surface is:

- `gsa` in Normal and Visual modes: add surrounding.
- `gsd`: delete surrounding.
- `gsr`: replace surrounding.
- `gsf` / `gsF`: find the right / left surrounding edge.
- `gsh`: temporarily highlight surrounding edges.

All mappings are buffer-local. Normal-mode mutation uses `operatorfunc` so add, delete, and replace
remain dot-repeatable and respect counts. Linewise and blockwise selections preserve the behavior of
`respect_selection_type = true`.

The builtin identifiers are brackets, `b`, `q`, `f`, `t`, `?`, and the default symmetric character.
Search uses `cover_or_next` semantics within 50 neighboring lines. Highlight duration is 500 ms.

## Buffer Eligibility and Keymap Ownership

A buffer is eligible when it is valid, modifiable, not readonly, and its filetype passes
`stl.filetype.is_surround_enabled()`. The initial filetype exclusion is
`stl.filetype.DIFFVIEW_CHANGES`, which covers the staged and unstaged Changes buffers without
disabling surrounds in other diffview buffers or real files shown in diff windows.

`setup()` refreshes buffer-local mappings on `BufEnter`, `FileType`, and changes to `modifiable` or
`readonly`. Public actions repeat the eligibility check before mutation because `OptionSet` does not
identify a non-current target buffer. Attachment records each installed mapping's callback or normalized
RHS identity; detach removes it only while that identity still matches, so a later buffer-local override
is preserved even when it reuses the same description. Attachment state is released after `BufWipeout`
only when a deferred validity check confirms actual destruction, because Neovim also emits that event
while renaming a buffer.

## Non-goals

- Runtime or buffer-local configuration.
- Custom surrounding definitions or Tree-sitter generators.
- Search-method selection, previous/next suffix mappings, or runtime `n_lines` updates.
- Backward compatibility with older Neovim versions.

Blockwise operations retain the upstream limitation around mixed multibyte and single-byte text.
