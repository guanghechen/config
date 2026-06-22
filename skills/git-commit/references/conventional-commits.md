# Conventional Commits + Gitmoji

The header convention for both **commit messages** and **PR titles**.

## Header Format

```
:gitmoji: <type>(<scope>): <description>
```

- **gitmoji** first, then type.
- **type**: prefer a standard Conventional Commits type over a custom one (`improve`, `i18n`, `move`, `rename`, `wip`); reach for a custom type only when repo history already uses it. Pick `<type>` and `:gitmoji:` from the mapping table below.
- **scope** (optional): a noun for the affected area in parentheses, e.g. `:bug: fix(parser):`.
- **description**: concise imperative in English ("add", not "added"); plain vocabulary, technical terms allowed.

## Breaking Change

Append `!` after the type/scope and/or lead with `:boom:`, then spell out `BREAKING CHANGE:` in the body when detail is needed:

```
:boom: feat(api)!: change response format

BREAKING CHANGE: `data` is now nested under `result`.
```

## Body / Footer (optional)

Add a "why" body and footers (`Refs`, `Closes`) per Conventional Commits when the change warrants it.

## Type and Gitmoji Mapping

Standard Conventional Commits types plus optional repo-specific ones; consult `git log` for which custom types this repo actually uses.

| Type       | Gitmoji                  | Description                             |
|------------|--------------------------|-----------------------------------------|
| `feat`     | `:sparkles:`             | A new feature                           |
| `feat`     | `:bento:`                | Add or update assets                    |
| `fix`      | `:bug:`                  | A bug fix                               |
| `fix`      | `:ambulance:`            | Critical hotfix                         |
| `fix`      | `:alien:`                | Update code due to external API changes |
| `docs`     | `:memo:`                 | Documentation changes                   |
| `style`    | `:lipstick:`             | UI and style updates                    |
| `refactor` | `:recycle:`              | Refactor code                           |
| `refactor` | `:coffin:`               | Remove dead code                        |
| `perf`     | `:zap:`                  | Performance improvement                 |
| `test`     | `:white_check_mark:`     | Add or update tests                     |
| `chore`    | `:wrench:`               | Configuration changes                   |
| `chore`    | `:fire:`                 | Remove code or files                    |
| `chore`    | `:arrow_up:`             | Upgrade dependencies                    |
| `chore`    | `:arrow_down:`           | Downgrade dependencies                  |
| `chore`    | `:heavy_plus_sign:`      | Add a dependency                        |
| `chore`    | `:heavy_minus_sign:`     | Remove a dependency                     |
| `chore`    | `:pushpin:`              | Pin dependencies to specific versions   |
| `chore`    | `:see_no_evil:`          | Add or update .gitignore                |
| `revert`   | `:rewind:`               | Revert changes                          |
| `improve`  | `:recycle:`              | Refactor / improve existing code        |
| `improve`  | `:art:`                  | Improve structure/format of code        |
| `i18n`     | `:globe_with_meridians:` | Internationalization and localization   |
| `move`     | `:truck:`                | Move files/resources                    |
| `rename`   | `:truck:`                | Rename files/resources                  |
| `wip`      | `:construction:`         | Temporary save, incomplete work         |

## Additional Gitmoji Modifiers (Not Commit Types)

These refine *how* a change is marked rather than naming a type. When one applies, it takes the header's gitmoji slot in place of the type's mapped gitmoji (the type word stays), e.g. `:lock: fix(auth): rotate leaked session secret`, `:pencil2: docs(readme): fix typo`. `:boom:` follows the Breaking Change rule above.

| Gitmoji                   | Description           |
|---------------------------|-----------------------|
| `:boom:`                  | Breaking changes      |
| `:building_construction:` | Architectural changes |
| `:lock:`                  | Fix security issues   |
| `:pencil2:`               | Fix typos             |

