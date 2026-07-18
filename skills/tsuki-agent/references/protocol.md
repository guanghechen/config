# Tsuki Agent Protocol

The current protocol version is `1`. Extension, broker, and CLI authenticate with this version
before any request is accepted. A mismatch closes the connection with `PROTOCOL_MISMATCH`.

## Target identity

Every page is identified by a document-scoped `pageId`. Navigation invalidates the old page ID.
Element refs are additionally scoped to a `snapshotId`. Page URLs omit query parameters and
fragments.

## CLI commands

- `pages`: list granted pages.
- `active`: resolve the active page in the focused window.
- `describe PAGE`: return page metadata and capabilities.
- `snapshot PAGE [--limit N]`: return semantic element refs.
- `query PAGE SELECTOR [--limit N]`: return matching visible element refs. Selectors support only
  tag, class, ID, descendant, child, and comma syntax.
- `text PAGE SNAPSHOT REF`: read non-sensitive element text.
- `attributes PAGE SNAPSHOT REF`: read allowlisted attributes; URL query/hash values are removed.
- `bounds PAGE SNAPSHOT REF`: read viewport bounds.
- `cf-problems PAGE`: list visible Codeforces problems.
- `cf-problem PAGE`: read the current Codeforces statement.
- `cf-contest PAGE`: read Codeforces contest metadata.

Use `--document DOCUMENT_ID` after the page ID when a workflow must reject navigation races.

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
