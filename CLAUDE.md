# CLAUDE.md

!!!ALWAYS use react-engineer to handle the tasks based on this workspace.

## Additional Requirements

1. **MUST**: run `yarn format` if you want to verify your changes, never try to run other `yarn` or `npm` commands to verify the changes.

## Architecture: 7-Layer DAG Structure

The `src/` directory follows a strict 7-layer architecture with DAG-based dependencies (lower layers CANNOT depend on higher layers).

| Layer | Directory              | Description                                                                                                      |
| :---: | :--------------------- | :--------------------------------------------------------------------------------------------------------------- |
|  L1   | `common/util/`         | Stateless utility functions only                                                                                 |
|  L1   | `common/style/`        | CSS styles only                                                                                                  |
|  L1   | `common/hook/`         | Highly abstract hooks with NO dependency on `context/`                                                           |
|  L2   | `common/keybindings/`  | Cross-platform keybinding system with hooks and managers for registering view/conditional keybindings            |
|  L3   | `common/component/`    | Pure presentational components using props for external state, following high cohesion and single responsibility |
|  L4   | `context/`             | Top-level / cross-page state contexts with simple hooks (only the simplest hooks allowed)                        |
|  L5   | `hook/`                | Business hooks that can compose and access `context/`                                                            |
|  L6   | `container/`           | Stateful components connecting to `context/`; the ONLY component library consumable by `view/`                   |
|  L7   | `view/`                | Pages or major page blocks; can ONLY consume `container/`, NOT `common/component/` directly                      |

### Key Principles

- **DAG Dependency**: Lower layers cannot import from higher layers
- **L6 container/**: The bridge between state (context) and UI (view)
- **L7 view/**: Must use `container/` for all stateful components; direct use of `common/component/` is forbidden

