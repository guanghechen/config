# Completion Subsystem

## Problem

`blink.cmp` v1 conflicts with the input-method lifecycle, while v2 is not a
stable dependency and introduces an additional runtime/build dependency chain.
The configuration already owns custom path, dictionary, and slash sources, so
the remaining external boundary is larger than the behavior actually used.

## Scope

- Target the repository's current Neovim version only. No compatibility layer.
- Own insert and command-line completion controllers, provider composition,
  trigger policy, ranking, selection, preview, acceptance, keymaps, and
  frecency in `era.m.cmp`.
- Keep insert and command-line semantic items and mutation rules mode-specific;
  share only compact ranking projections, list transitions, and the popupmenu
  presentation contract.
- Keep one popupmenu surface owned by `era.dressing.ui_attach`. Completion controllers
  drive it directly with owner and generation tokens; native popupmenu events
  remain an adapter for completion outside the owned contexts.
- Put keyword matching, word extraction, immutable candidate indexes, fuzzy
  scoring, top-k ordering, and frecency in the existing `yoz` native module.
- Reuse `stl.reporter` and existing `yoz.path`, `yoz.fs`, and `yoz.dict`
  primitives.
- Keep `friendly-snippets` as mirrored data; do not add another snippet engine.
- Do not download native libraries or add third-party packages.

## Required Behavior

- Insert-mode completion for LSP, path, `@` path, snippets, buffers,
  dictionary entries, and slash commands.
- Command-line completion for Ex commands, paths, buffers, options, help,
  mappings, environment variables, shell commands, command-line windows, and
  `input()` custom completion. Search command lines use buffer-word candidates.
- Ex command completion opens automatically and projects the first prefix
  candidate as ghost text without mutating the command line. Search and
  `input()` completion remain explicit. Command-line Tab opens a hidden list
  and previews its first item. Filename references expose `%` / `#`
  modifiers with their expanded insertion and a short description.
- Provider selection follows the current filetype sets.
- Requests have one immutable context and one cancellation generation.
- Late responses cannot replace a newer completion session.
- Completion coalesces the initial snapshot for at most 40ms, publishing earlier
  when all providers settle. A reusable snapshot may publish immediately while
  incomplete providers refresh. Local async and upstream results publish through
  the same callback in the same generation; a two-second deadline publishes the
  final available snapshot and cancels unfinished work.
- The insert controller refreshes incomplete results while the menu is open;
  Backspace restores an active preview before requesting the shortened prefix.
- `era.m.cmp` is the single trigger owner: keyword and provider trigger
  characters request completion, ordinary punctuation hides it, and unrelated
  buffer mutations do not open the menu.
- The completion list preselects the first item without changing the buffer.
  Tab or directional navigation inserts a Blink-style preview and cycling
  replaces it. Mid-token previews temporarily consume the selected item's
  replacement suffix; cancellation or cycling back to the original text restores
  it, while continued typing or `Escape`/`InsertLeave` commits the preview without
  applying acceptance side effects. Both `C-h` and `C-e`
  cancellation are owned so restoration does not depend on completion event
  metadata. Snippets preview the first parsed line up to brackets, quotes,
  assignment, or whitespace while preserving balanced leading delimiters, so
  scalar snippets show their value while function snippets show the callable
  name. Only explicit acceptance applies snippets, additional edits, and commands.
- Incremental publication preserves an explicitly selected semantic candidate
  while it remains in the ranked Top-200, including its preview; selecting the
  original input remains selected across refreshes. Requests retain the canonical
  input rather than interpreting a controller-owned preview as new user input.
- Accepting an item that ends on a provider trigger character starts the next
  completion generation after finalization; queued user input takes precedence.
- Cmdline selection previews the candidate in the command line without
  accumulating edits across cycles. Cancellation restores the immutable base
  snapshot, continued typing commits the preview, and directory acceptance
  invalidates the old session before requesting its child candidates.
- Insert and command-line popup rows project strict fuzzy-match byte ranges from
  the same query used for ranking; path completion matches the displayed basename
  rather than the stable directory prefix.
- Completion labels and label detail/description fields normalize CR/LF to `↲`
  in a single-line display snapshot before matching, semantic parsing, and popup
  rendering. Original LSP payloads and insertion text remain unchanged.
- Ordering uses source priority, a small nearby-word proximity bonus,
  allocation-free ASCII / streaming Unicode
  subsequence scoring, bounded adaptive typo repair, exactness, continuously
  decayed frecency, and `sortText`. Queries of 4-7 characters allow one repair;
  queries of 8-32 characters allow one non-prefix repair or up to two repairs when
  the repaired query matches a contiguous candidate prefix. Queries of 33-64
  characters retain only the prefix repair path so short and ordinary queries use
  a smaller fixed hot-path scratch. Longer queries remain strict-only. A repair
  may substitute one character, discard one extra input character, or transpose
  adjacent characters; missing input characters already match through subsequence
  gaps. The two-edit prefix search carries bounded state and does not materialize
  edit combinations. Strict and repaired candidates compete in one ranking, with
  each additional repair receiving a larger penalty. Output limits are applied
  only after complete ranking.
- The ranked completion list is capped at 200 items, matching Blink's default
  global list bound and avoiding work for candidates the UI cannot practically
  reach.
- Ranking preserves same-label candidates from different providers and LSP
  overloads that differ in visible fields, edits, or commands. Candidates that
  differ only in opaque resolve `data` or documentation are coalesced; newer
  resolve data/docs win. Usage identity uses a canonical semantic projection:
  effective `filterText`, `sortText`, insertion text, and plain-text defaults
  are normalized; visible deprecation state, command name/arguments, and
  additional-edit text are included; opaque data, documentation, and absolute
  positions are excluded. Additional edits are projected in stable range order
  so their text-to-target-order mapping remains distinct. Dedupe extends that
  identity with full edit ranges and remaining behavior-affecting fields, so
  candidates whose application differs are preserved without fragmenting
  persisted frecency when only absolute positions move.
- Frecency persists a fixed-point usage score and timestamp. Rust applies a
  seven-day continuous half-life through a precomputed integer decay table,
  saturates repeated usage, prunes entries with no remaining ranking effect,
  and combines the bonus with priority and fuzzy score. Stable semantic keys
  distinguish LSP overloads, snippet filetypes, and path directories. Only
  explicit acceptance records usage.
- Selection and primary acceptance finish within the keymap caller. An uncached
  resolve receives a 100ms event-loop waiting budget before primary mutation,
  matching the locked Blink acceptance budget; cached results do not wait. This
  is a resolve budget, not a bound on total acceptance CPU or scheduling latency.
  Later input stays queued until the primary transaction finishes. Native redo
  bookkeeping uses guarded internal keys, never deferred body replay; multi-stop
  snippet selection remains owned by `vim.snippet`.
- LSP acceptance preserves snippet expansion, additional text edits, resolve,
  and commands. Explicit `TextEdit` ranges define their own suffix boundary;
  `InsertReplaceEdit` uses `insert`, matching the Blink prefix configuration.
  Items without an explicit range replace only the keyword prefix. Buffer,
  dictionary, slash, and snippet providers also use prefix ranges; path providers
  retain their explicit filename replacement ranges.
- Friendly snippet expansion preserves the replaced Blink provider's builtin
  variable set; file, workspace, selection, and comment values resolve from the
  completion request buffer while date/time and random values resolve lazily.
- Snippet documentation previews the exact normalized insertion snapshot above
  the provider description, including dynamic date/time and random values.
  Preview and documentation sections use an internal explicit separator, so
  snippet Markdown fences and horizontal rules remain literal content.
- Selection resolves upstream documentation with cancellation and updates only
  the still-active candidate; stale resolve responses cannot replace popup text.
- Documentation and acceptance share a candidate's in-flight resolve and its
  complete successful result, including imports and commands. Acceptance starts
  or joins resolve after restoring the original input and before inserting text.
- LSP signature help opens automatically on server trigger and retrigger
  characters, including when insert mode starts immediately after a trigger.
  `C-p` toggles a rounded translucent label-only popup with active-parameter
  highlighting.
- While the menu is visible, `C-space` toggles documentation and `C-b`/`C-f`
  scroll it by a page. Missing documentation preserves the original insert-mode
  mapping fallback.
- Initial or budget-ready edits and commands apply in the primary transaction.
  Still-pending edits require nonconflicting ranges and an intact accepted
  prefix; commands additionally require the original post-accept cursor and
  changedtick. The selected primary insertion never changes on resolve.
- Acceptance creates an undo boundary after the typed prefix. Plain-text
  completion, multiline literal text, Unicode, and final-tabstop auto-brackets
  preserve native dot repeat and subsequent typing without replacing `.` or the
  original insert/change command. Preview replacement and explicit cancellation
  update native redo as well, without recording acceptance-only side effects.
- Kind-based brackets apply to Function and Method items and follow the locked
  Blink filetype blocklist, import/pseudo-selector exceptions, and per-filetype
  bracket shape. Existing opening delimiters are reused, with the cursor placed
  inside them rather than before them; intervening whitespace is preserved.
  Snippets with a final `$0` tabstop retain their declared text and cursor.
- When kind-based insertion does not add brackets, an already-active Neovim
  semantic highlighter may prove that the accepted identifier is a function or
  method. This includes Variable completion items and kind-blocked TSX functions.
  The semantic blocklist still excludes Java and the shared blocked filetypes.
  The continuation has a 400ms lifetime, never waits for tokens in the keymap,
  and drops its edit after typing, cursor/window/mode changes, or cancellation.
  Fresh semantic brackets join the primary undo block and native dot repeat.
- Ordinary paths resolve relative to the request buffer, while `@` paths and
  finder paths resolve relative to the workspace/CWD. Hidden entries remain
  visible by default, matching the replaced Blink path provider.
- Path and `@` path documentation asynchronously prefetch at most 1024 bytes for
  the selected/preselected regular file. Enumeration only attaches its absolute
  path; acceptance does not perform documentation IO. A NUL in the prefix yields
  `Binary file`; text uses an extension-based fenced preview with a complete
  trailing UTF-8 codepoint and a fence longer than any literal content fence.
  No content-probing filetype handler or ftplugin runs for this preview.
- Path documentation rejects recognized sensitive names before filesystem IO,
  including `.ssh`, `.env*`, `local/env.*`, credentials, private-key extensions,
  and HTTP request/response captures. It does not read directories, symbolic-link
  components, or hard-linked files; opened file identity is checked again before
  reading. These conservative exceptions intentionally differ from Blink's
  unrestricted path reader. They are path rules, not a general secret detector.
- `@` paths require an explicit token boundary. Path syntax is guaranteed for
  quoted paths, `./`, `../`, `~/`, `$VAR/`, line-leading absolute paths, shell
  command arguments, and finder paths. Lexical filters reject common comments,
  closing tags, URLs, and arithmetic forms; full parser-level disambiguation of
  ambiguous unquoted slash syntax is intentionally out of scope.
- Popupmenu and documentation geometry is constrained by the active window and
  input anchor on all four sides. South and north layouts keep both borders off
  the input row; side documentation beside a north menu cannot extend below
  that menu, and vertical splits cannot be covered. Menu rows give kind, label,
  optional label description, and one aligned source column distinct visual
  weight. Insert provider badges and command-line context badges use distinct
  semantic highlights; command-line labels remain concise, such as `[cmd]`,
  `[path]`, `[buf]`, and `[opt]`, instead of one generic source. Overflow exposes
  a scrollbar thumb on the right border, and both the completion menu and
  documentation preview borders use the active scheme's `unified.bg2`. Narrow
  layouts preserve and truncate the label before hiding the source. LSP labels
  receive cached Treesitter semantic captures, while strict fuzzy-match byte
  ranges use `PmenuMatch` at a higher priority; deprecated labels skip semantic
  captures and truncated labels never highlight the ellipsis. Side-by-side menu
  and documentation windows overlap their adjacent border by one screen column,
  presenting one shared divider without moving either content area.
- Input-method restoration may run on the next event-loop tick without racing
  scheduled completion keymap commands.

## Architecture

### Ownership

```text
era.m.cmp
  init                -> composition root and explicit controller/surface wiring
  insert              -> insert session, generation, preview, selection, and acceptance intent
  cmdline             -> cmdline context, candidate cache, ranked list, preview, and acceptance
  signature           -> LSP context, request, active-result, projection, and popup lifecycle
  trigger             -> insert typed-character classification and trigger state
  context             -> immutable request context and token-reuse predicates
  protocol            -> ingress validation, range conversion, semantic identity, item projection
  snapshot            -> immutable candidate/ranking snapshots and query-specific result views
  bridge              -> local-first fan-out, response ownership, deadline, history, command routing
  resolve             -> candidate-keyed RPC/cache ownership and cancellable subscriptions
  accept              -> preflight, primary transaction, and guarded resolved side effects
  brackets            -> bracket policy and guarded semantic-token continuation
  path_documentation  -> selected-file read budget, path safety, and descriptor lifecycle
  editor              -> buffer/snippet primitives, undo boundary, and native redo adapter
  source/*            -> fixed providers; per-buffer indexes and cancellable path filesystem work
  keymap              -> synchronous controller actions with captured mapping fallbacks

yoz.cmp
  keyword range and word extraction
  immutable compact candidate index
  fuzzy matching, top-k ranking, and frecency

era.dressing.ui_attach.popupmenu
  owner/generation-checked presentation surface
  content-sized, border-aware placement and documentation rendering

Neovim
  LSP transport and raw command-line completion metadata/candidates
  buffer, snippet, command-line, window, and highlight mutation primitives
```

Insert and command-line controllers each own one mode-specific session and are
the only writers of its generation, semantic items, selection, and preview
snapshot. Their domain items are not forced through a shared completion-item
type: insert items retain LSP edits, snippets, resolve data, and commands, while
command-line items retain only their context-specific replacement data. Shared
list logic operates on stable indices and selection transitions, not opaque
domain payloads. `era.m.cmp.init` injects controller actions into keymaps and the
popupmenu surface; renderers never depend back on a controller.

`bridge` composes `context`, `source`, `snapshot`, `protocol`, and `resolve`;
`snapshot` and `resolve` depend on `protocol`, never back on `bridge` or the
controllers. `accept` composes the bridge's resolve/command APIs with `editor`
and `brackets`; `brackets` depends on `editor`, never on acceptance or a controller.
The insert controller uses `brackets` for kind policy and `path_documentation`
for file previews. File documentation does not pass through acceptance resolve,
so a cold filesystem cannot delay inserting a path.
The editor adapter has no dependency on requests, providers, ranking, or popup
state. These are fixed modules, not a runtime provider/plugin framework.
The controller supplies request validity as a callback; the bridge streams
initial and incremental snapshots without calling back into a controller to
request another completion. Acceptance owns one pending transaction per buffer;
the editor owns its coordinate-change journal, not its resolve lifecycle.
Semantic eligibility is evaluated only for the accepted item, not stored in
every ranked item or obtained by querying tokens during menu projection.

Transport items are read-only across module boundaries. Ingress validation does
not deep-copy each response item; completion-list defaults require only a
shallow item copy. A candidate pairs the payload with its immutable source
context, instead of attaching request metadata to the payload. Snapshot entries
retain those candidates and a compact native ranking index. Only ranked output
items receive independent normalized views; resolve copies the selected payload
at the RPC boundary. Bridge alone mutates history, and snapshots read its usage,
known-key, and label indexes without taking ownership of them.

```text
editor event
  -> mode controller
  -> source fan-out or Neovim cmdline adapter
  -> mode-specific normalization and dedupe
  -> immutable yoz.cmp candidate index
  -> ranked stable indices
  -> controller session
  -> cached view rows and label-highlight projection
  -> popupmenu surface

keymap
  -> active controller select / accept / cancel
  -> transactional buffer or cmdline mutation
  -> popupmenu select / hide
```

The popupmenu surface validates both owner and generation. A late native UI
event, stale completion response, or previous-mode dismissal therefore cannot
replace or hide the active view. The surface owns only render resources and a
copy of the current presentation state; controller state remains authoritative.
Selection changes update only highlight, scroll position, and documentation.
They do not enumerate, normalize, rank, or reformat the candidate list.
The renderer consumes eager label-relative match ranges, invokes the controller's
opaque semantic resolver only for visible rows, and applies layout offsets,
truncation clipping, and highlight priorities. It does not own matching,
Treesitter parsing, or semantic caches. Selection is a low-priority whole-line
combine layer; field, semantic, and match ranges remain visible above it, and
the selected label's matched ranges receive the contrasting `PmenuMatchSel`
overlay without reformatting other rows.

Preview mutation is transactional. Each session keeps an immutable base line,
cursor, and replacement range. Cycling reconstructs the selected preview from
that base and tracks the selected candidate's consumed suffix. Precise byte-range
edits preserve unrelated marks and share the native redo adapter with acceptance.
Controller state is committed before recording preview bookkeeping. Request
validity accepts either the unchanged canonical input or the exact owned preview,
checking generation, buffer, line, cursor, and changedtick. Unrelated text/cursor
changes retire the view rather than restoring stale input. A genuine user edit
commits the visible preview and starts a new session. Explicit cancellation
restores the base only while its invariants hold; leaving insert mode keeps the
preview but cancels resolve acceptance. Incremental results compare semantic
candidate identity, not old row indices, before restoring and reapplying preview.

Command-line preview mutates Neovim through `setcmdline()` and then asks the
cmdline surface to synchronize its active state because programmatic edits do
not update the external UI eagerly. The sync path reuses the existing buffer,
window, layout, and syntax state; structural changes fall back to the full
renderer. Cycling keeps the existing replacement anchor, updates both surfaces,
and schedules one coalesced redraw after the key callback returns. It therefore
does not repeat `screenpos()` anchor discovery or block selection on a synchronous
TUI flush. The surface records the expected text and cursor for that preview;
the matching external-UI echo is consumed once without rendering the same state
again, while any mismatched user edit follows the normal render path. Before
selection, the controller sends only the first candidate's prefix continuation
to the cmdline surface as readonly ghost text; the surface does not own candidate
or ranking state.

The final owned paths do not use `vim.fn.complete()`, `pumvisible()`,
`CompleteChanged`, `CompleteDonePre`, or `wildtrigger()` as list lifecycle or
selection state. Neovim remains the source of LSP transport and raw command-line
completion through `getcmdcompltype()` and `getcompletion()`. Unsupported native
completion outside the owned contexts may still arrive through the popupmenu UI
adapter, but one generation never has two list owners.

The insert bridge owns completion RPC state, publishes the available snapshot
within the initial 40ms window, and refreshes the same generation as providers
settle through one streaming callback. Protocol conversion uses
an internal UTF-8 contract; range projection returns byte offsets directly,
without allocating temporary positions for every candidate. Matching upstream
candidates remain cached while the same token grows and its suffix stays
unchanged. Complete responses are reused; only incomplete or newly attached
clients are queried in the background. Same-label buckets are allocated only
when an actual overload needs semantic comparison.

Resolve owns a weak-key cache keyed by the stable candidate, not a particular
ranked view. Multiple consumers share one request; cancelling one subscription
does not cancel the others, and cancelling the last one retires the RPC. A
successful raw result is projected separately for each consumer's current
context, so reranking cannot reuse stale UTF-8 edit coordinates. RPC errors,
invalid payloads, send failures, and the two-second timeout are not cached.
Completion-session clearing does not cancel an acceptance subscription;
buffer disposal clears both completion and resolve state.

Documentation subscribes before writing a preview and activates publication
only after the selection/surface is ready. Replacing a view subscribes before
cancelling the previous listener, preserving a shared in-flight request.
Path documentation uses the same view-identity/generation guard with a separate
200ms read lifetime. It inspects path components without following links, opens
only a single-link regular file, and checks descriptor device/inode identity
before its single bounded read. Cancellation or timeout immediately revokes
publication; in-flight IO retains its descriptor until its callback can close it
safely. Missing, denied, replaced, and non-regular files yield no documentation.
Acceptance restores preview input, validates known edits, and starts or joins
resolve before mutating the primary text. The controller closes the completion
stream first, while the documentation subscription survives until acceptance
has subscribed. An uncached resolve may process events with `vim.wait` for up to
100ms without consuming queued input. Buffer/window, mode, cursor, changedtick,
and transaction ownership must remain unchanged; invalidation or interruption
cancels acceptance. This bounded wait keeps version-sensitive servers such as
rust-analyzer on the original document while resolving auto-imports.

Ready side effects are validated before primary mutation and share its undo
transaction. After timeout, the primary edit still executes in the original
keymap callback. A lazy snapshot provider copies pre-accept buffer text only
when resolve remains pending and additional edits are not already available;
late UTF-16/32 coordinates are normalized against that snapshot, never newer text.
Late edits first transform around the primary edit, then rebase through the
editor's precise UTF-8 `on_bytes` journal. A protected accepted prefix must remain
intact, and any overlapping target rejects the entire batch. Typing at the end
of the accepted prefix and nonconflicting cursor movement do not discard imports.
The journal closes on reload, detach, cancellation, protected-prefix changes,
or more than 256 changes. Its listener retires on the next buffer event without
detaching unrelated listeners.

Late side effects require the original buffer/window and an acceptance mode.
Commands additionally require the captured post-accept cursor and changedtick.
A new acceptance, `InsertLeave`, `BufLeave`, buffer disposal, or feature disable
cancels pending ownership and releases its snapshot/subscription. Resolve callbacks
that arrive during primary mutation wait until transaction commit; ownership is
released before external side effects run. Late results never replace the selected
insertion or replay body text over subsequent typing. If a version-sensitive
server computes resolve only after the 100ms budget and omits imports, the client
cannot reconstruct them; the bounded wait intentionally does not promise imports
under arbitrary server latency.

Semantic bracket requests are independent of resolve subscriptions. Completing
resolve releases only its own transaction; a new acceptance or lifecycle cancel
also retires the buffer's semantic continuation. The continuation checks the
originating client's token at the accepted identifier end. Its highlighter result
version must match both Neovim's document version and the captured changedtick,
with the original buffer, window, filetype, insert mode, cursor, and highlighter
still owned, and without an active snippet session.
Stale cached tokens cannot authorize an edit. Even benign changes such as a late
import invalidate this optional suffix rather than rebasing it over newer state.

The adapter reads only an already-loaded, active Neovim semantic highlighter; it
does not enable highlighting or create its own semantic RPC. After checking a
fresh cache, it uses the current Neovim highlighter's `send_request()` to advance
its existing, version-deduplicated request without forcing a cache reset. This
narrow private-API boundary targets the repository's current Neovim, not multiple
versions. `LspTokenUpdate` schedules at most one relevant continuation at a time.
Timeout/cancellation releases only the continuation's listener/timer, not the
highlighter's shared RPC. Primary text is never replayed on a token response.

The editor adapter alone owns undo and redo bookkeeping. It records a native
completion in a temporary, autocmd-suppressed buffer, then immediately releases
that buffer. Internal all-mode `<Plug>` mappings finalize only their owned
recording; they never send insert-only control keys in another mode. For
multiline literals, a temporary no-op paste handler records the remaining text
without modifying the body. Final-tabstop cursor movement is included in native
redo while preserving the synchronous acceptance cursor, including forward
movement over existing delimiters. The recorder validates the actual inserted
body before seeding redo. Buffer/window, cursor, and recorder-generation checks
discard stale bookkeeping. When changedtick advances, body-range and cursor
extmarks permit safe import-induced displacement only while the body and cursor
anchor remain intact. All paths release temporary marks, and editor globals and
the public `v:completed_item` are restored. General replay of
multi-stop snippet sessions is not implemented: expansion and navigation stay
with `vim.snippet`, and full snippet dot-repeat parity is not claimed.
`editor.extend` appends a guarded semantic suffix with `undojoin`. Its redo input
is the already-recorded accepted text, not the original typed prefix; recording
against that current input adds only the suffix delta. Reusing the original
prefix would incorrectly repeat text such as `alphapha()` instead of `alpha()`.

Command-line enumeration separates the stable source prefix from the fuzzy
query. Path completion therefore enumerates a directory snapshot and ranks its
basenames instead of asking native file completion to prefix-match the full
token. Raw candidates are cached by completion type and source prefix; changing
only the fuzzy query reuses the same snapshot. Command-line windows and
`input()` use context adapters over the same controller, while `/` and `?` use
buffer-word candidates.

### Native Performance Boundary

`yoz.cmp` is a pure data-plane component. It knows only UTF-8 strings, stable
indices, optional sort text and usage keys, numeric score offsets, and limits.
It never reads Neovim state and does not depend on LSP, `era`, editor modes,
preview semantics, or rendering.

Each stable candidate snapshot builds one immutable native index containing its
compact ranking projection. Query-only refresh calls the index directly and
does not rebuild Lua text, score-offset, usage-key, sort-text, or proximity-key
vectors. The
index may cache case-folded or boundary metadata internally, performs fuzzy
matching, frecency lookup, nearby-word lookup, partial top-k selection, and
final ordering in Rust,
and returns one flat array of ranked stable indices. Scores and exactness remain
inside Rust unless an explicit diagnostic path requests them, avoiding one Lua
table allocation per result. The index is rebuilt only when the semantic
candidate snapshot changes, not when selection or the query changes.

Buffer completion owns one immutable flat native index per eligible buffer,
not a merged tab-wide word array or matcher. Each shard returns at most 201
indices, reserving one slot for exclusion of the current query. Deduplication
and a final native rank operate on at most 2010 words for the ten-buffer bound
and publish Top-200. Usage keys are created only when a shard is built.

The active buffer's indexed snapshot excludes its current token. Buffer
listeners permit reuse only for single-line changes confined to that same
token; changes elsewhere, multiline edits, reloads, renames, or active-token
ownership changes rebuild the affected shard. An edit in another buffer never
rebuilds every tab buffer. Clearing drops the native index reference immediately;
retired listeners remove only themselves and cannot invalidate a replacement
entry or detach another module's listener.

The native usage index remains the scoring source of truth. Startup hydrates it
from JSON, explicit acceptance records usage in place, and shutdown snapshots
and prunes it. Ranking uses the integer decay table; low-frequency record and
snapshot mutations consume the complete elapsed interval with exact decay
before advancing the stored timestamp. Full semantic identities are computed
lazily in Lua only for history-relevant or accepted candidates. Resolve-only
detail, documentation, or absolute position changes do not fragment history.

Editor-bound work remains in Lua: source orchestration, LSP validation and
normalization, semantic identity and dedupe, command-line context parsing,
generation and cancellation, preview/accept transactions, and all Neovim API
calls. Moving these across the native boundary would marshal dynamic editor
tables, obscure lifecycle ownership, or require callbacks into Neovim. Popup
row projection and display-width calculation also remain in Lua because they
follow Neovim rendering semantics; labels, kinds, source text, documentation,
and widths are computed once per semantic snapshot and reused while only query
or selection changes.

All Lua/Rust calls are batched. Strict fuzzy-match byte ranges are projected by
one native call per published snapshot without changing ranking results; repaired
candidates may intentionally have no match highlight when the original query
cannot be aligned as a subsequence. Visible uncached LSP labels use independent
Treesitter string parsers and populate the bounded per-label cache; off-screen
labels are resolved only if scrolling exposes them.
There are no per-candidate Lua callbacks from
Rust or per-candidate native calls from Lua on query, selection, preview, or
acceptance hot paths. Buffer and snippet source caches reuse the same native
index contract and rebuild only when their source data changes.

Completion documentation buffers mark themselves before receiving the
`markdown` filetype. The render-markdown early-load configuration ignores that
marker, so ephemeral popup buffers never enter its persistent manager state.

## Explicit Non-goals

- External provider/plugin API.
- A shared semantic completion-item or provider abstraction across editor modes.
- `nvim-cmp` compatibility.
- Terminal completion or omnifunc adapters.
- Multiple snippet backends.
- Native library download, release asset resolution, or per-plugin build logic.
- A second popupmenu implementation.
- General-purpose configuration validation or compatibility shims.
- Parser-complete classification of regex/operator/path syntax in every code
  filetype.
- Distinguishing otherwise identical completion rows solely by opaque resolve
  `data` or documentation.
- Unquoted braced environment paths such as `${HOME}/...`; use `$HOME/...` or a
  quoted path instead.

## Failure Strategy

- Provider failure is isolated and reported once; other provider results remain
  publishable.
- Cancellation and stale generation are normal outcomes and are silent.
- A stalled provider cannot block already-available results and is cancelled at
  the request deadline.
- Invalid LSP items are skipped rather than aborting the full result set.
- A cancelled or invalidated resolve wait cannot apply the primary edit. Its
  timeout permits synchronous primary acceptance, not deferred body replay.
- Delayed edits require same buffer/window/mode, an intact accepted prefix, and
  nonconflicting rebased targets. Invalid or mutually overlapping edits reject
  the entire late batch. Delayed commands retain strict cursor/changedtick guards.
- Semantic-token failure or timeout never rejects primary acceptance; without
  fresh owning evidence the optional bracket suffix is omitted. File-preview
  cancellation/failure cannot affect acceptance or publish to another selection.
- Invalid known snippets/overlapping edits fail preflight without recording
  usage. A runtime snippet/edit failure may leave a partial edit; the acceptance
  undo boundary restores the original input. Repeat bookkeeping failure is
  reported without rejecting an already-applied primary edit.
- Missing `yoz.cmp` is a startup error because the repository ships and owns the
  native module.

## Verification

- Focused pure tests for keyword range, fuzzy ordering, native index reuse,
  selection transitions, command-line replacement ranges, provider selection,
  and stale response rejection.
- Integration tests for LSP item conversion/acceptance, transactional preview
  restoration, command-line adapters, popup owner isolation, and custom sources.
- Resolve subscription tests cover shared requests, cancellation, synchronous
  callbacks, retries, client replacement, complete-result caching, and
  context-specific projection.
- Real `nvim_feedkeys` tests cover native undo/dot repeat, queued typing, Unicode,
  `ciw`, multiline text, final-tabstop brackets, stale recorder guards, and
  temporary resource/global cleanup. Buffer tests perform actual buffer edits
  and count shard builds, rather than benchmarking unchanged changedticks only.
- Composed insert tests run the real controller, bridge, protocol, resolver,
  acceptance, and editor with mocked provider IO and popup presentation. They
  cover preview/typing/redo, cancellation and Escape, selection retention during
  streaming results, bounded resolve without consuming queued input, UTF-16 late
  edits after multiline Unicode input, and acceptance lifecycle cancellation.
- Path documentation tests cover real bounded reads, binary/UTF-8/fence handling,
  rejection before IO, symbolic-link components, hard links, open-time identity
  changes, and descriptor cleanup after cancellation/timeout at every IO stage.
  Composed tests carry path metadata through the real bridge into documentation,
  and verify that accepting a path never starts another read.
- Semantic continuation tests cover fresh/stale versions, client identity, token
  kind, Unicode methods, TSX policy, unsupported highlighters, timeout and user
  invalidation, and native undo/dot both before and after initial redo bookkeeping.
- Existing IM lifecycle tests plus a completion regression covering rapid
  `InsertLeave -> InsertEnter` transitions.
- Matched real-TUI insert and command-line sequences against the Blink baseline,
  including cold publication, cached incremental refresh, selection/preview,
  acceptance, and 50/200/2000-candidate p50/p95 measurements. Query-only refresh
  must reuse its native index; selection must not rerank or reformat rows.
- `cargo test`, full Lua suite, Stylua, Rustfmt, and headless Neovim startup.

### Non-blocking Verification Gaps

The matched baseline is the Blink configuration in `0886fe517`, using the local
Blink 1.10.2 build at `78336bc89ee5365633bcf754d93df01678b5c08f`. Synthetic
pipeline benchmarks end at ranked candidates; popup projection tests mock the
surface and do not measure actual GUI frame latency. Isolated live fixtures on
2026-09-08 verify rust-analyzer 0.3.3025 auto-imports within the acceptance budget
and vtsls 0.3.0 imports after deliberately delaying resolve callback delivery by
200ms, preserving subsequent input. These are small workspaces, not evidence for
all servers or project sizes. Real GUI/input-method switching and general
multi-stop snippet repeat remain separate verification work. On 2026-09-09 a live
vtsls TSX fixture also verifies initially unbracketed function acceptance followed
by brackets from real semantic tokens and continued typing. It starts with an
existing import and pauses before typing to allow token delivery; it does not
establish delayed-import/semantic composition or GUI frame latency. Wider typo
recall remains outside the implemented parity scope, and path previews retain
the deliberate safety exceptions above. No complete-replacement or end-to-end
latency claim follows from the headless fixtures alone.
