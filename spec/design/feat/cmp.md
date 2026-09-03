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
- Keep one popupmenu surface owned by `era.m.ui_attach`. Completion controllers
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
- Completion publishes the current local snapshot immediately. Local async and
  upstream results refresh the same generation incrementally; a two-second
  deadline publishes the final available snapshot and cancels unfinished work.
- The insert controller refreshes incomplete results while the menu is open;
  Backspace restores an active preview before requesting the shortened prefix.
- `era.m.cmp` is the single trigger owner: keyword and provider trigger
  characters request completion, ordinary punctuation hides it, and unrelated
  buffer mutations do not open the menu.
- The completion list preselects the first item without changing the buffer.
  Tab or directional navigation inserts a Blink-style preview and cycling
  replaces it. Mid-token previews temporarily consume the selected item's
  replacement suffix; cancellation or cycling back to the original text restores
  it, while continued typing commits the preview. Both `C-h` and `C-e`
  cancellation are owned so restoration does not depend on completion event
  metadata. Snippets preview the first parsed line up to brackets, quotes,
  assignment, or whitespace while preserving balanced leading delimiters, so
  scalar snippets show their value while function snippets show the callable
  name. Only explicit acceptance applies snippets, additional edits, and commands.
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
- Selection and acceptance are synchronous from the keymap caller's point of
  view; asynchronous work happens only before the menu is published or during
  LSP resolve side effects.
- LSP acceptance preserves snippet expansion, additional text edits, resolve,
  commands, and replacement suffixes for `TextEdit`/`InsertReplaceEdit`.
- Friendly snippet expansion preserves the replaced Blink provider's builtin
  variable set; file, workspace, selection, and comment values resolve from the
  completion request buffer while date/time and random values resolve lazily.
- Snippet documentation previews the exact normalized insertion snapshot above
  the provider description, including dynamic date/time and random values.
  Preview and documentation sections use an internal explicit separator, so
  snippet Markdown fences and horizontal rules remain literal content.
- Selection resolves upstream documentation with cancellation and updates only
  the still-active candidate; stale resolve responses cannot replace popup text.
- LSP signature help opens automatically on server trigger and retrigger
  characters, including when insert mode starts immediately after a trigger.
  `C-p` toggles a rounded translucent label-only popup with active-parameter
  highlighting.
- While the menu is visible, `C-space` toggles documentation and `C-b`/`C-f`
  scroll it by a page. Missing documentation preserves the original insert-mode
  mapping fallback.
- Known initial edits and commands apply synchronously at acceptance; only
  side effects first returned by resolve remain behind stale-buffer guards.
- Auto-bracket applies only to Function and Method items and follows the locked
  Blink filetype blocklist, import/pseudo-selector exceptions, and per-filetype
  bracket shape. Existing delimiters and snippets with a final `$0` tabstop are
  not modified.
- Ordinary paths resolve relative to the request buffer, while `@` paths and
  finder paths resolve relative to the workspace/CWD. Hidden entries remain
  visible by default, matching the replaced Blink path provider.
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
  init     -> composition root and explicit controller/surface wiring
  insert   -> insert context, generation, ranked list, preview, and acceptance intent
  cmdline  -> cmdline context, candidate cache, ranked list, preview, and acceptance
  signature -> LSP context, request, active-result, projection, and popup lifecycle
  trigger  -> insert typed-character classification and trigger state
  bridge   -> insert local-first fan-out, deadline, range normalization, and resolve
  accept   -> insert primary edit/snippet and delayed resolved side effects
  source/* -> fixed insert providers; path filesystem work is cancellable async
  keymap   -> synchronous controller actions with captured mapping fallbacks

yoz.cmp
  keyword range and word extraction
  immutable compact candidate index
  fuzzy matching, top-k ranking, and frecency

era.m.ui_attach.popupmenu
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
that base rather than editing the previous preview. Controller-originated
mutations carry a suppression token so their resulting editor events do not
start a competing generation. A genuine user edit commits the visible preview
and starts a new session. Cancellation restores the base only while its buffer
or command-line invariants still hold.

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

The insert bridge remains the single owner of upstream request state. It
publishes local snapshots first, refreshes the same generation as providers
settle, converts upstream positions to the internal UTF-8 contract, and routes
resolve and command side effects to the originating client. Matching upstream
candidates remain cached while the same token grows and its suffix stays
unchanged. Complete responses are reused; only incomplete or newly attached
clients are queried in the background. Acceptance expands the primary snippet
and applies known edits and commands synchronously before later typeahead. Only
side effects first returned by resolve remain behind buffer, mode, cursor,
changedtick, and generation guards.

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
- Completion acceptance checks buffer, mode, cursor, and changedtick before
  applying delayed resolve side effects.
- Missing `yoz.cmp` is a startup error because the repository ships and owns the
  native module.

## Verification

- Focused pure tests for keyword range, fuzzy ordering, native index reuse,
  selection transitions, command-line replacement ranges, provider selection,
  and stale response rejection.
- Integration tests for LSP item conversion/acceptance, transactional preview
  restoration, command-line adapters, popup owner isolation, and custom sources.
- Existing IM lifecycle tests plus a completion regression covering rapid
  `InsertLeave -> InsertEnter` transitions.
- Matched real-TUI insert and command-line sequences against the Blink baseline,
  including cold publication, cached incremental refresh, selection/preview,
  acceptance, and 50/200/2000-candidate p50/p95 measurements. Query-only refresh
  must reuse its native index; selection must not rerank or reformat rows.
- `cargo test`, full Lua suite, Stylua, Rustfmt, and headless Neovim startup.
