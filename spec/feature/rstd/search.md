# Search Result Types

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
