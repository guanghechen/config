# Statusline Consolidation Architecture Spec

## 1. Module Boundary (SRP)

| Module                  | Responsibility                         | Public Ports              | Private Runtime             |
|-------------------------|----------------------------------------|---------------------------|-----------------------------|
| `load-theme.sh`         | Select status mode and source theme    | `@GHC_SL_MODE`            | mode branching              |
| `status-layout.sh`      | Select wide/narrow layout for status02/12     | `@GHC_SL_MODE` global option | width detection/cache check |
| `status02.tmux.conf`    | Define adaptive two-line status content formats | tmux source-file          | tmux format strings         |
| `tmux.hbs` theme source | Define colors and symbols              | `ghc-theme gen/apply`     | theme generation templates  |

## 2. Dependency Graph

- one-way dependencies:
  - `tmux.conf` -> `load-theme.sh` -> `status02.tmux.conf` -> generated theme variables
  - `load-theme.sh` -> `status-layout.sh`
- forbidden reverse dependencies:
  - Theme files must not call `load-theme.sh`.
  - Generated theme variables must not depend on runtime tmux state.

## 3. Interaction Lifecycle Model

### Lifecycle

- init: `load-theme.sh` reads `@GHC_SL_MODE`.
- start: Adaptive mode sources `status02.tmux.conf`, registers resize hook, and runs `status-layout.sh` once.
- stop: Switching to another mode overwrites `status`, `status-position`, and status formats.
- dispose: No persistent process; only tmux options remain.

### Interaction Transitions

| From       | To         | Event         | Guard              | Timeout | Error Handling              |
|------------|------------|---------------|--------------------|---------|-----------------------------|
| init       | start      | theme load    | mode `02` or `12`  | none    | fallback by manual reload   |
| start      | start      | client resize | mode still active  | none    | no-op if layout unchanged   |
| start      | stop       | mode changed  | mode not adaptive  | none    | clear adaptive hook command |

## 4. Interface Contracts

| Port                | Input          | Output               | Idempotency | Timeout | Error Contract                      |
|---------------------|----------------|----------------------|-------------|---------|-------------------------------------|
| `status-layout.sh`  | none; reads `@GHC_SL_MODE` | tmux status options  | idempotent  | none    | invalid width degrades to wide      |
| `status02.tmux.conf`| source-file    | format definitions   | idempotent  | none    | tmux parse failure blocks sourcing  |
| `tmux.hbs`          | theme data     | generated tmux theme | idempotent  | external| generator failure leaves old theme  |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: status01 works without status02.
- works without optional plugins: true

### Plugin Contract

No plugin architecture is required. This feature is a direct tmux theme extension.

## 6. Observability and Degrade Strategy

- `@GHC_SL_LAYOUT` records selected layout: `wide` or `narrow`.
- Manual inspection: `tmux show -gqv @GHC_SL_LAYOUT`.
- Degrade: width detection failure uses wide one-line layout.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
