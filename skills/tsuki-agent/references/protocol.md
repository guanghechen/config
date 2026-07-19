# Tsuki Agent Protocol

The current protocol version is `1`. Extension, broker, and CLI authenticate with this version
before any request is accepted. A mismatch closes the connection with `PROTOCOL_MISMATCH`.

## Runtime boundaries

Requests flow one way: CLI → loopback broker → Extension background → one explicitly targeted
content adapter, with responses returning along the same path. The broker owns pairing tokens and
pending transport requests; the Extension background is the single writer for grants, page
registration, and Tsuki-owned notes; each content adapter owns its current snapshot and highlight.

Requests use bounded 100–10000 ms deadlines and are never replayed automatically. A disconnect,
navigation, revocation, queue overflow, or timeout fails closed; callers re-list pages or retry with
a fresh snapshot. Broker or bridge failure does not stop Tsuki's appearance features.

## Target identity

Every page is identified by a document-scoped `pageId`. Document navigation invalidates the old page
ID; same-document URL changes retain it and increment the page revision. Element refs are
additionally scoped to a `snapshotId`. Page URLs omit query parameters and fragments.

## CLI commands

- `pages`: list granted pages.
- `active`: resolve the active page in the focused window.
- `describe PAGE`: return page metadata, capabilities, and memory/action permission state.
- `snapshot PAGE [--limit N]`: return semantic element refs.
- `query PAGE SELECTOR [--limit N]`: return matching visible element refs. Selectors support only
  tag, class, ID, descendant, child, and comma syntax.
- `text PAGE SNAPSHOT REF`: read non-sensitive element text.
- `attributes PAGE SNAPSHOT REF`: read allowlisted attributes; URL query/hash values are removed.
- `bounds PAGE SNAPSHOT REF`: read viewport bounds.
- `scroll PAGE SNAPSHOT REF [--block POSITION]`: scroll a referenced element into view.
- `highlight PAGE SNAPSHOT REF [--duration MS]`: show a temporary pointer-free overlay for an
  in-viewport element; the overlay tracks scrolling and resizing.
- `memory-list PAGE SCOPE`: list Tsuki-owned session notes for `origin` or `page` scope.
- `memory-get PAGE SCOPE KEY`: read one scoped note.
- `memory-set PAGE SCOPE KEY VALUE`: write one scoped note, up to 2048 characters.
- `memory-delete PAGE SCOPE KEY`: delete one scoped note.
- `cf-problems PAGE`: list visible Codeforces problems.
- `cf-problem PAGE`: read the current Codeforces statement.
- `cf-contest PAGE`: read Codeforces contest metadata.

Use `--document DOCUMENT_ID` after the page ID when a workflow must reject navigation races.

Read, memory, and action grants are independent per origin. Memory and action grants require read
access. Disabling read access revokes all three.

Agent memory accepts up to 16 notes per scope, 32 per origin, and 64 per browser session. Keys use
letters, digits, `.`, `_`, or `-`, and values are limited to 2048 characters. Page scope uses an
HMAC-derived opaque identity for the complete URL with a browser-session key; query/hash values are
never exposed or stored with the note.

## Expected errors

- `PERMISSION_DENIED`: origin has not been granted.
- `PROTOCOL_MISMATCH`: Extension and companion protocol versions differ.
- `PAGE_NOT_FOUND`: page is not registered.
- `PAGE_STALE`: document changed or disconnected.
- `CAPABILITY_UNAVAILABLE`: adapter does not provide the operation.
- `STALE_SNAPSHOT`: snapshot has been replaced.
- `STALE_ELEMENT`: referenced node is detached.
- `SENSITIVE_ELEMENT`: form or editable content is intentionally redacted.
- `TIMEOUT`: request exceeded its deadline.
- `PAYLOAD_TOO_LARGE`: response exceeded the extension limit.
