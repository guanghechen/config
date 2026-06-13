# Statusline Runtime Refactor Implementation Plan

## 1. Scope Mapping

| Design Ref      | Design Source | Code Target                         | Test Target          |
|-----------------|---------------|-------------------------------------|----------------------|
| bounded cache   | flow §5       | `src/cache.rs`, components          | cache unit tests     |
| runtime split   | arch §1       | `src/runtime.rs`, `src/app.rs`      | apply/render tests   |
| composer SRP    | arch §1       | `src/composer.rs`                   | composer tests       |
| delta commit    | flow §3       | `src/commit.rs`, `src/tmux.rs`      | commit planner tests |
| left length     | flow §5       | `src/status_length.rs`, `src/commit.rs`, `src/composer.rs`, `src/tmux.rs` | unit tests           |
| metrics plugin  | arch §5       | `src/component/{cpu,memory,network}` | component tests      |
| duration native | flow §5       | `src/component/duration.rs`         | duration tests       |

## 2. Work Breakdown

| Step | Design Ref    | Change Area             | Inputs              | Outputs             | Verification              | Code Target               |
|------|---------------|-------------------------|---------------------|---------------------|---------------------------|---------------------------|
| 1    | bounded cache | cache API               | component id/value  | single-slot payload | cache tests               | `src/cache.rs`            |
| 2    | runtime split | runtime orchestration   | event               | render pipeline     | cargo test                | `src/runtime.rs`          |
| 3    | composer SRP  | compose rows            | component outputs   | rendered status     | composer tests            | `src/composer.rs`         |
| 4    | component API | component snapshots     | context/cache       | rendered segment    | component tests           | `src/status_component.rs` |
| 5    | metrics       | metrics cache           | provider samples    | bounded metrics     | metrics component tests   | `src/component/*.rs`      |
| 6    | duration      | remove shell duration   | session_created     | static rich text    | no duration.sh reference  | `src/component/duration.rs` |
| 7    | delta commit  | commit planner          | snapshot/rendered   | changed options     | planner tests             | `src/commit.rs`           |
| 8    | integration   | tmux adapter            | command plan        | tmux apply          | live apply + dump-state   | `src/tmux.rs`             |
| 9    | left length   | one-line clipping guard | faithful left width | dynamic length      | status length tests       | `src/status_length.rs`    |

## 3. Acceptance Criteria

- `cargo fmt --check` passes。
- `cargo test` passes。
- `cargo clippy -- -D warnings` passes。
- `cargo build --release` passes。
- `git diff --check` passes。
- No `duration.sh` reference in status02 Rust output。
- Repeated `apply tick` does not increase component cache record count。
- `@GHC_STATUS_COMPONENT_CACHE_*` total payload remains bounded after repeated ticks。
- status02 wide/narrow behavior remains unchanged。
- Wide status02 updates `status-left-length` from rendered left width, so the last session slant is not clipped by static 64。
- single-session mode still one row and renders the single session item。

## 4. Rollback Plan

- Revert Rust renderer changes as one commit if live apply fails。
- Keep `status01` fallback path unchanged。
- If delta commit fails, temporarily switch `TmuxAdapter` back to full commit while keeping bounded cache。
- If metrics cache fails, hide metrics components and preserve core statusline。

## 5. Progress

| Step | Status  | Notes                  |
|------|---------|------------------------|
| 1    | done    | single-slot cache     |
| 2    | done    | `runtime.rs` added    |
| 3    | done    | composer is assemble boundary |
| 4    | done    | snapshot updates component state |
| 5    | done    | metrics cache bounded; CPU native ticks |
| 6    | done    | duration is Rust-native |
| 7    | done    | `commit.rs` added     |
| 8    | done    | live apply verified   |
| 9    | done    | dynamic one-line left length |
