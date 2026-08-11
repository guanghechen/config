# Yoz Search

## Boundaries

`yoz.search` owns filesystem traversal, matching, cancellation checkpoints, and native search
job state. It has no Neovim dependency and never calls Lua from a worker thread.

The `era.m.searcher` layer owns debounce, request generations, polling, result publication, and
UI lifecycle. A request snapshot flows in one direction:

```text
composer -> Lua file-search controller -> Rust job -> controller -> composer
```

The synchronous `search_in_files` API remains the compatibility and semantic reference. The
background API must return exactly the same ordered result for a request that is not cancelled.

## Search Result Types

Since I'm very familiar with TypeScript, I will use TypeScript to represent the data types I wish to have.

First, let's consider what's the result we deliver to Lua. I believe the result should be like:

```typescript
export interface ITextMatch {
  readonly lx: number // The line number of the leftest pos of the matched content (start from 1)
  readonly ly: number // The line number of the rightest pos of the matched content (start from 1)
  readonly cx: number // The column index of the leftest pos of the matched content (start from 0)
  readonly cy: number // The column index of the rightest pos of the matched content (start from 0)
  readonly ox: number // The offset of the leftest pos of the matched content (start from 0)
  readonly oy: number // The offset of the rightest pos of the matched content (start from 0)

  // The preview text for the search match, it should be sliced the original text from [min{L,ox-16}, max{R,oy+16}],
  // while the L is the offset of the first pos of the lx line, and R is the the last pos of the ly line.
  // to make things simple, the `s` should better pre replace the '\n' to `↲`, since each `↲` take two byte,
  //
  // but if the matched content is not include the last lineending of the `s` (the sy position),
  // then we should exclude it from the `s`, to avoid confuse.
  // e.g., if the text is `hello\nworld\n`, and we matched `llo\nworld`, then the `s` should be `hello↲world`, not `hello↲world↲`.
  // trailing line-ending glyphs should be omitted even when the match captures them,
  // so `llo\nworld\n` becomes `hello↲world`.
  readonly s: string
  readonly sx: number // the leftest matched pos offset of the leftest pos of the s.
  readonly sy: number // the rightest matched pos offset of the rightest pos of the s.
}

export interface IFileMatch {
  readonly p: string // relative filepath
  readonly matches: ITextMatch[]
}

// This result is for the search_in_files* api.
export interface ISearchFileResult {
  readonly items: IFileMatch[]
  readonly elapsed_time: number // milliseconds
  // True when traversal stopped at max_matches before exhaustiveness was established.
  readonly limit_reached: boolean
}

export interface ISearchInLinesMatchPoint {
  readonly l: number
  readonly r: number
}

export interface ISearchInLinesLineMatch {
  readonly lnum: number
  readonly score: number
  readonly matches: ISearchInLinesMatchPoint[]
}

// This result is for the search_in_lines* / search_in_text api.
export interface ISearchTextResult {
  readonly matches: ITextMatch[]
  readonly lines: ISearchInLinesLineMatch[]
  readonly elapsed_time: number // milliseconds
}
```

## Background Search Job

### Lua API

```lua
local job = yoz.search.start_search_in_files(options)

local status, result, err = job:poll()
-- status: "running" | "completed" | "cancelled" | "failed"

job:cancel()
job:dispose()
```

`start_search_in_files` converts the Lua options to owned Rust data and resolves a missing, empty,
or relative `cwd` against the call-time current directory before spawning the worker. Option
conversion and thread-spawn failures are Lua errors. The Lua controller catches them and reports a
current request once.

The worker owns no `Lua`, `LuaTable`, callback, or `vim.*` value. It sends one terminal Rust
outcome through a one-shot channel:

```text
Completed(ISearchFileResult) | Cancelled | Failed(ISearchFailedResult)
```

The job caches the terminal outcome. `poll()` is repeatable and does not consume the cached
payload; a Lua allocation or conversion error can therefore be handled without losing terminal
state. The controller disposes the job after the first successful terminal poll.

### Lifecycle

- `cancel()` is idempotent and only requests cooperative cancellation. The job remains
  `running` until the worker acknowledges cancellation with a terminal outcome. Calling it after
  a terminal outcome is a no-op.
- `dispose()` is idempotent and non-blocking. It marks the job disposed, requests cancellation,
  and drops the receiver without joining the worker. Other methods on a disposed job are misuse
  errors.
- `Drop` requests cancellation as a leak-safety fallback, not as the normal lifecycle.
- A disconnected channel or worker panic becomes one cached `failed` outcome; it must not leave
  the job permanently `running`.

## Cancellation

Cancellation uses an `Arc<AtomicBool>` and is checked during setup, around directory entries and
file boundaries, between file read chunks, from the match sink, and immediately before terminal
publication.

The cancellation-aware reader returns a typed, non-retriable sentinel error. It must not return
`io::ErrorKind::Interrupted`, because standard readers retry `Interrupted` and could spin after
cancellation. Once cancellation is requested, cancellation dominates an ordinary I/O failure
observed by that request. The synchronous path uses a token that is never cancelled and retains
its existing failure semantics.

Cancellation is cooperative and has no physical latency guarantee. Directory sorting, an active
filesystem syscall, and regex evaluation over an already-loaded multiline file cannot be forcibly
interrupted. Lua checks request freshness synchronously at the terminal boundary, so a superseded
request never publishes or reports even before its queued input observer requests physical
cancellation.

## Lua Request Controller

Each file-search composer owns one concrete controller. The controller is the only writer of:

- the current generation;
- one active native job;
- one latest pending immutable request;
- the scheduled poll timer.

`Observable` values update synchronously but notify subscribers on the Neovim event loop. The
composer coalesces all search-affecting notifications in one event-loop burst. The first observer
callback runs before the 64 ms debounce and:

1. increment the generation;
2. request cancellation of the active job;
3. clear any pending request;
4. schedule a debounced snapshot and submit.

The immutable request snapshot contains root/cwd/specified path, copied include and exclude
patterns, query and replacement, all search flags, `max_filesize`, and `max_matches`. Completion
uses only this snapshot for normalization and publication. Immediately before any request-scoped
publication or error report, the controller compares the snapshot identity with a fresh composer
input snapshot. This freshness check is the only terminal read of Observables.

At most one physical worker is active per controller. While A is active, submitting B stores B as
pending and cancels A. Submitting C replaces B. C starts only after A reaches a terminal state.
This bounds worker accumulation; the accepted tradeoff is that the latest request may wait for a
slow physical cancellation.

All start, poll, terminal, error, and publication callbacks require a live controller, a matching
generation, and a request snapshot equal to the current search inputs. The snapshot equality guard
closes the interval between a synchronous `Observable:next()` and its queued subscriber callback.
It also applies to callbacks already queued on the Neovim main loop. Stale results and stale errors
are discarded without publication or reporting.

An empty query becomes terminally stale as soon as the Observable value changes. On the first
queued input-observer turn, it invalidates the active request and clears the search projection and
ordered result list while preserving root context. It does not restore a pre-search file snapshot,
because the current result reset replaces that data. The accepted tradeoff is one event-loop turn
of physical cancellation and projection-clear latency without any stale publication window.

The last successful non-empty projection may remain visible while a newer request runs or fails,
but it is read-only once its immutable input snapshot differs from the current search inputs.
Destructive replace actions must compare the published snapshot with a fresh input snapshot before
any native file write. A mismatch rejects the action with a warning; old match locations must never
be reinterpreted using a newer query, replacement, root, or flag set.

The composer owns one presentation-only busy interval for the latest logical search. It starts on
the first non-empty search-affecting notification, before debounce and physical submission, remains
active while an older job acknowledges cancellation or the latest request is pending, and stops
only on a current completion or failure, an empty query, or disposal. Stale terminal callbacks
cannot stop it. The Finder title shows a spinner only after 120 ms to avoid flicker for fast
searches, decorates the current dynamic title, cycles a theme-aware accent color when its frame
advances, and preserves title changes made while searching. Only the spinner prefix receives the
accent; the title text retains the Finder title highlight.
Animation reuses the controller's scheduled running-poll heartbeat and never creates a second timer
or redraws the result tree. A heartbeat callback failure is reported once and disables further
animation callbacks without changing the native job lifecycle.

## Polling and Terminal Failure Policy

Polling runs through a `vim.schedule_wrap`-equivalent timer callback so Neovim API use never occurs
in a fast-event context. Timer creation must succeed before a job is allowed to remain active; a
timer setup failure cancels and disposes a newly started job.

Every route out of an active job uses one detach/cleanup/advance sequence, including normal
completion, cancellation, worker failure, disconnected channel, `poll()` error, timer failure,
start failure, and controller disposal:

1. detach the active identity and job;
2. best-effort dispose the job and clear active state regardless of disposal or reporting errors;
3. report an infrastructure error exactly once only when its generation is still current;
4. start the current pending request, or stop polling when idle.

Every `poll()` call is protected by `pcall`. Successful terminal polling performs controller and
job cleanup before invoking UI publication. The publication callback runs under `xpcall`, so an UI
exception cannot strand active or pending work.

The controller guarantees retention of the last published result for option conversion, start,
worker, poll, and pre-apply normalization failures. Once UI mutation begins, publication is not
transactional; an apply exception is caught and reported as an invariant failure without a
rollback guarantee.

Controller disposal is synchronous in this order:

1. mark disposed;
2. stop and close the poll timer;
3. invalidate the generation;
4. cancel and dispose the active job;
5. clear pending work and callback references.

This happens before the composer's existing scheduled UI teardown.

## Match Limit and Result Completeness

File search has one persisted `flag_limit_matches` switch and one persisted positive-integer
`max_matches` value. The switch defaults to enabled. An enabled request passes `max_matches` to
Rust; a disabled request passes `nil`, which means unlimited traversal. Zero, negative,
fractional, and out-of-range limits are rejected at the Lua settings boundary, while the native
API accepts only `nil` or a positive 32-bit integer.

`ISearchFileResult.limit_reached` is true only when traversal stops at `max_matches` before the
engine establishes exhaustiveness. It means that the published projection is not known to be
complete; it does not claim that a further match exists. The synchronous and background APIs
return the same flag for the same request.

The result winline owns two separate presentations of this state:

- an interactive limit flag shows whether future requests are bounded;
- a persistent orange `LIMIT <max_matches>` status marks the currently published projection when
  `limit_reached` is true.

The status belongs to the published projection rather than the live settings. It remains while a
newer request is pending or fails, and disappears only when that projection is replaced or
cleared. Toggling the flag invalidates the current request and schedules a new search. Disabling
the flag retains the positive limit value for later re-enablement.

Global `replace all` is rejected with a warning when the current projection has
`limit_reached = true`; the user must disable the limit and publish an exhaustive result first.
Node-scoped and individual replacement remain explicit operations over visible matches and are
not blocked by this guard. On a limited projection, node-scoped replacement must use explicit
match offsets and must not take the whole-file replacement fast path, because the cutoff file may
contain undiscovered matches. Existing stale-projection checks still run before every destructive
replacement.

## Publication and Performance Boundary

The first implementation publishes one final result and preserves deterministic ordering and the
current filetree reset/apply behavior. It does not use Rust file-level parallel traversal or a
streaming UI.

The supported responsiveness boundary is the current default `max_filesize = "1M"` and
`max_matches = 500`. The full main-thread publication measurement includes:

- terminal Rust-to-Lua conversion in `job:poll()`;
- search-result normalization and replacement preview;
- sorting;
- filetree reset, location construction, and ancestor updates;
- synchronously triggered render work.

Normal and replacement-preview worst-case fixtures must remain below a 50 ms hard ceiling at 500
matches before the implementation is considered complete. A 5000-match run is recorded as a
stress result, but has no responsiveness guarantee and introduces no silent result cap. If the
500-match boundary fails, chunked conversion and time-sliced publication become required work.

Internal parallel search is deferred. It improves throughput rather than main-loop responsiveness
and would require a separate decision for deterministic ordering, global match limits, resource
use, and cancellation coordination.
