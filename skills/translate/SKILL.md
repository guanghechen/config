---
name: translate
description: Translate the current supplied text between Chinese and English while preserving meaning, formatting, terminology, code snippets, identifiers, and paths. Use when the user asks to translate, render in Chinese or English, or requests bilingual wording.
argument-hint: "[text | file[:range]]"
---

# Translate

Translate only the current user-supplied text. Do not enter a persistent translation mode, and do not treat later user messages as text to translate unless the skill is invoked again or the user asks again.

## Direction

- If the user specifies a target language, follow it.
- First classify the input:
  - Prose or prose-dominant text: apply the default language direction below.
  - Code, commands, logs, config, paths, URLs, or structured artifacts: preserve structure and protected spans; translate only natural-language comments, messages, or string content when the request clearly asks for that.
- Default direction for prose:
  - If the prose contains Chinese characters, translate it into English.
  - If the prose is clearly English, translate it into Simplified Chinese.
- For another language, mixed-language input, or non-prose input where the target or intended editable portion is unclear, ask a brief clarification instead of translating the whole artifact.

## Output

- Output only the translation unless the user asks for notes, alternatives, or explanation.
- Preserve Markdown structure, tables, lists, headings, links, code fences, frontmatter, and line breaks when practical.
- Preserve code, commands, identifiers, API names, URLs, and file paths exactly unless the user explicitly asks otherwise.
- For Chinese to English, prefer natural, idiomatic English, but do not add new meaning or make claims stronger.
- For English to Chinese, use clear Simplified Chinese and keep established technical terms in English when that is more precise.

## Optional Vocabulary Mode

Only provide IPA, vocabulary tables, word-by-word glosses, or pronunciation notes when the user explicitly asks for pronunciation, IPA, vocabulary, dictionary-style output, or word study.

When producing an IPA table, align Markdown table columns and omit outer pipes:

```markdown
Word          | IPA Notation     | Chinese
------------- | ---------------- | -------
example       | /ɪɡˈzæmpəl/      | 示例
```

## File Targets

If the user provides a readable file path, `file://` URI, or path with line/range syntax and clearly asks to translate that file content, edit the target in place. Otherwise treat the provided content as literal text and return the translation.

Do not access or edit secret-looking files such as `.env*`, `.ssh/`, credential files, or request/response dumps.
