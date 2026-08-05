---
name: code-design
description: >-
  Core design principles for organizing code and modules, to consult when
  designing or refactoring. Not a process gate; forces no document. Covers
  pluggable peer modules, abstract-on-demand, single responsibility,
  self-explaining and similar structure, one-way data flow, single source and
  single writer, narrow interfaces, explicit over implicit, symmetric paired
  operations, and testability.
---

# Code Design

A set of core design principles for organizing code and modules. Not a process gate, and it forces no document; it is positive guidance to check against when designing or refactoring — aiming for code that is easy to debug, maintain, and extend, with low cognitive load.

## When to consult

- When deciding how to organize a new feature or module, or when refactoring existing structure.
- When a module boundary, data flow, or responsibility split is hard to articulate — hold it against these principles.

## File and module organization

1. **Prefer pluggable, uniform modules.** Let peer modules share one contract so they stay interchangeable: easy to debug, and a new one is written by copying an existing peer. The core runs without any optional plugin, and a plugin failure stays isolated and degrades gracefully.
2. **Abstract on demand, not ahead of it.** Extract the pattern when the 2nd or 3rd real peer shows up; with a single implementation, plain concrete code beats an empty extension point.
3. **Self-explaining structure, similar across modules.** The file/directory layout states intent; peer modules keep the same internal structure and naming — similarity is a natural index, so do not skimp on it.
4. **Single responsibility.** A module/function/component does one thing; if you need "and" to describe what it does, it usually should be split.

## Code and data flow

1. **One-way data flow.** Keep flow one-directional; when a cycle appears, introduce a higher-level module to own the data source and the connections (`A ↔ B` → `A → C ← B`).
2. **Single source, single writer.** Each piece of state has one owner and one write site; everyone else reads only — scattered writes are the hardest bugs to trace.
3. **Narrow interface, self-governed internals.** Expose as little as possible, and a cross-module interface states its input / output / error / timeout contract; no other module reads or writes its internal state directly.
4. **Explicit over implicit.** Dependencies, data flow, and side effects are visible at the boundary, not hidden in globals / singletons / implicit init.
5. **Symmetric paired operations.** `create / destroy`, `open / close`, `start / stop`, `init / dispose` appear in pairs and close together — a missing counterpart breeds resource leaks.
6. **Explicit failure paths.** Plan the failure branches (retry / rollback / degrade / abort) together with the normal flow, instead of writing only the happy path and patching it later.
7. **Testability as a design probe.** Hard to test usually signals a design smell; let "how testable is it" drive the design — pure functions plus dependency injection are both testable and decoupled.

## Applying it

No fixed template. Pick the principles that apply and put them into the code. If a change touches a module boundary, data flow, or plugin lifecycle, capture the key decisions (boundary / state owner / failure paths / open questions) in a short note that travels with the code — length matched to the change.
