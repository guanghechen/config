---
name: refine
description: Polish, proofread, or lightly rewrite supplied text in its own language while preserving meaning, tone, formatting, code snippets, identifiers, and paths. Use when the user asks to refine, improve wording, fix typos, or make prose clearer. To render the text in a different language, use translate instead.
---

# Refine

Lightly polish supplied material while preserving the original meaning and authorial voice. Prefer minimal, high-signal changes over rewriting from scratch.

## Input

The user may provide:

- Literal text
- A file path, absolute or relative
- A `file://` URI
- A path with position or range, such as `doc.md:10`, `doc.md:10-20`, `doc.md#L10-L20`, or `@doc.md :L10:C1-L20:C5`

Treat an argument as a path only when it is readable or clearly uses file/position syntax. Otherwise treat it as literal text.

## Language

- Refine within the source language; preserve it.
- This skill does not change the text's language. If the user wants the text rendered in another language, that is a translation task — defer to the `translate` skill instead of refining across languages.
- Do not translate code, commands, identifiers, API names, URLs, or file paths.

## Behavior

- For literal text: output only the refined text unless the user asks for explanation or comparison.
- For a file or range: edit the target content in place with the smallest reasonable diff, then report the edited path.
- Preserve Markdown structure, tables, lists, headings, links, code fences, frontmatter, and surrounding formatting.
- Keep technical claims intact. Do not add facts, examples, citations, caveats, or stronger claims that were not present.
- Fix typos, grammar, punctuation, awkward phrasing, and unnecessary repetition.
- Keep the same level of formality unless the user asks for a different tone.

## Safety

- Do not access or edit secret-looking files such as `.env*`, `.ssh/`, credential files, or request/response dumps.
- If the requested target is ambiguous or spans generated/large content, ask before editing.
