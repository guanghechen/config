# Native Search Winline Feedback

## Scope

This design covers Neovim's native `/`, `?`, `n`, and `N` search feedback. It does not cover
`era.m.searcher`, picker result positions, or minimap search markers.

Neovim remains responsible for computing and formatting the search count. The UI preserves the
native payload, including boundary forms such as `[1/>99]` and `[?/??]`.

## Ownership and Data Flow

```text
Neovim ext_messages
  └─ msg_show(search_cmd/search_count)
       └─ era.m.ui_attach.messages
            └─ dot.state.status search-count state
                 ├─ dirty_winline_nr
                 └─ era.m.nvimbar.component.nvim.search_count
                      └─ source window winline (right)
```

`dot.state.status` owns one transient search-count value:

```lua
{
  winnr = winnr,
  bufnr = bufnr,
  text = "[index/total]",
}
```

Mutation is restricted to `set_search_count()` and `clear_search_count()`. Consumers use
`get_search_count(winnr)` and cannot mutate the stored value.

The value is visible only when the requested window is still valid and still displays the source
buffer. Replacing the value redraws both the previous window and the new window when they differ.

## Event Lifecycle

| Event | Transition |
|:------|:-----------|
| `search_cmd` | Set `searching = true` and clear the previous count. The command text is not rendered as an index. |
| `search_count` | Set `searching = true`, concatenate the trimmed native content chunks, and publish the count for the current window and buffer. |
| `<Esc>` while searching or while `v:hlsearch == 1` | Set `searching = false`, clear the count, then schedule `:nohlsearch`. |
| Status reset/dispose | Clear the transient count. |

An empty or invalid publication clears the previous value instead of retaining stale feedback.

## Winline Rendering

The count is an atomic right-side winline component with priority `120`. Hunk navigation uses
priority `110`. When both are present, the order is:

```text
[hunk-index/hunk-total] [search-index/search-total]
```

The search count remains the rightmost item and receives width before the hunk item. The component
uses `f_wl_nvim_search_count` and the normal winline background.

Search feedback does not use buffer virtual text or extmarks. Line length, horizontal scrolling,
and inline blame therefore cannot move or cover it.

## Verification

- `lua/__test__/dot/state/status.lua`: ownership, window/buffer scope, publish, and clear.
- `lua/__test__/era/m/ui_attach/messages.lua`: native event transitions.
- `lua/__test__/era/m/ui_attach/init.lua`: `<Esc>` cleanup.
- `lua/__test__/era/m/nvimbar/component/nvim.lua`: rendering and window scope.
- Headless winline integration verifies `[hunk] [search]` ordering and `search_cmd` clearing.
