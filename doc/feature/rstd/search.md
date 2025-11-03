Since I'm very family with the typescript, so I will use typescript to represent the data types I wished shaped as.

First, let's consider what's the result we deliver to the lua, I believe the result should be like:


```typescript
export interface ITextMatch {
  readonly lx: number // the line number of the leftest pos of the matched content (start from 1)
  readonly ly: number // the line number of the rightest pos of the matched content (start from 1)
  readonly cx: number // the column index of the leftest pos of the matched content (start from 0)
  readonly cy: number // the column index of the rightest pos of the matched content (start from 0)
  readonly ox: number // the offset of the leftest pos of the matched content (start from 0)
  readonly oy: number // the offset of the rightest pos of the matched content (start from 0)

  readonly s: string // the preview text for the search match, it should be sliced the original text from [min{L,ox-16}, max{R,oy+16}], while the L is the offset of the first pos of the lx line, and R is the the last pos of the ly line. to make things simple, the `s` should better pre replace the '\n' to `↲`, since each `↲` take two byte,
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
  readonly elapsed_time: number (ms)
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
  readonly elapsed_time: number (ms)
}
```
