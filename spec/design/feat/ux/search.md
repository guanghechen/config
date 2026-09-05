# Native Search Winline Feedback

## Scope

This design covers Neovim's native `/`, `?`, `n`, and `N` search feedback. It does not cover
`era.m.searcher` or picker result positions.

Neovim remains responsible for the active search pattern and formatted count. The search register
is the pattern source of truth. Native `search_count` payloads provide the terminal bracketed
count, including boundary forms such as `[1/>99]` and `[?/??]`.

## Ownership and Data Flow

```text
Neovim ext_messages
  └─ msg_show(search_cmd/search_count)
       └─ era.m.ui_attach.messages
            └─ dot.state.status search state
                 ├─ dirty_winline_nr
                 └─ era.m.nvimbar.component.nvim.search_count
                      └─ source window winline (right)
```

`dot.state.status` owns one transient search snapshot:

```lua
{
  winnr = winnr,
  bufnr = bufnr,
  pattern = "query",
  count = "index/total", -- nil until Neovim publishes search_count
}
```

Mutation is restricted to `set_search()` and `clear_search()`. Consumers use
`get_search(winnr)`, which returns the pattern and count as separate values rather than exposing
the stored table.

The value is visible only when the requested window is still valid and still displays the source
buffer. Replacing the value redraws both the previous window and the new window when they differ.

## Event Lifecycle

| Event | Transition |
|:------|:-----------|
| `search_cmd` | Set `searching = true`, read the new pattern from register `/`, and publish it with a nil count. |
| `search_count` | Set `searching = true`, read register `/` again, extract the terminal count from either composite or count-only native content, and publish a complete snapshot. |
| `<Esc>` while searching or while `v:hlsearch == 1` | Set `searching = false`, clear the search snapshot, then schedule `:nohlsearch`. |
| Status reset/dispose | Clear the transient search snapshot. |

Because every event publishes a complete snapshot, `n/N` count-only events cannot erase the
pattern. An empty pattern or invalid window/buffer publication clears the previous value instead of
retaining stale feedback.

## Winline Rendering

Search feedback is a width-adaptive right-side winline component with priority `120`. Hunk
navigation uses priority `110`. When both are present, the order is:

```text
[hunk-index/hunk-total] <search-icon> pattern search-index/search-total
```

The search item remains rightmost and receives width before the hunk item. Before a count arrives,
it renders as `<search-icon> pattern`. Long values are truncated in the middle so the icon and
terminal count remain identifiable. The component uses the yellow `f_wl_nvim_search_count`
foreground and the normal winline background.

Search feedback does not use buffer virtual text or extmarks. Line length, horizontal scrolling,
and inline blame therefore cannot move or cover it.

## Verification

- `__test__/specs/dot/state/status_spec.lua`: ownership, window/buffer scope, publish, and clear.
- `__test__/specs/era/m/ui_attach/messages_spec.lua`: native event transitions.
- `__test__/specs/era/m/ui_attach/init_spec.lua`: `<Esc>` cleanup.
- `__test__/specs/era/m/nvimbar/component/nvim_spec.lua`: rendering and window scope.
- Nvimbar component tests verify the search icon, persistent pattern, unbracketed count, truncation,
  right-side placement, and source-window scope.
- UI attach tests verify complete snapshots for `search_cmd`, composite `search_count`, and
  count-only `n/N` events.
