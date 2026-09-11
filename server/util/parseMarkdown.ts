import type { Code, Root, Text } from '@yozora/ast'
import { CodeType, TextType } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import {
  calcHeadingToc,
  shallowMutateAstInPreorder,
  shallowMutateAstInPreorderAsync,
} from '@yozora/ast-util'
import { stripChineseCharacters } from '@yozora/character'
import Parser from '@yozora/parser'
import fs from 'node:fs/promises'
import path from 'node:path'
import { parse as parseYaml } from 'yaml'
import type { IMarkdownFileData } from '../../shared/types/api'
import { toSearch } from '../../shared/util'
import state from '../state'

const regexes = {
  frontmatter: /^\s*[-]{3,}\n\s*([\s\S]*?)[-]{3,}\n/,
  indent: /^\s*/,
  line: /\r|\n|\n\r/g,
  srcFile: new RegExp(`(?:^|\\b)${'sourcefile'}="([^"]+)"`, 'i'),
  srcLine: new RegExp(`(?:^|\\b)${'sourceline'}="([^"]+)"`, 'i'),
}

const intervalRegex = /^(\d+)(?:-(\d+))?$/
const intervalSeparator = /[,\s]+/

/**
 * Parse a compact interval expression (e.g. `1-3,5,7-9`) into sorted, merged
 * closed integer intervals. Equivalent to the removed `collectIntervals` from
 * `@guanghechen/std@1`.
 */
function collectIntervals(text: string): Array<[number, number]> {
  const intervals: Array<[number, number]> = []
  for (const token of text.split(intervalSeparator)) {
    const match = intervalRegex.exec(token)
    if (!match) continue

    const [, lft, rht] = match
    const x = Number(lft)
    if (typeof rht !== 'string') {
      intervals.push([x, x])
      continue
    }
    const y = Number(rht)
    intervals.push(x < y ? [x, y] : [y, x])
  }

  intervals.sort((a, b) => (a[0] === b[0] ? a[1] - b[1] : a[0] - b[0]))
  if (intervals.length <= 1) return intervals

  const result: Array<[number, number]> = [intervals[0]]
  for (let i = 1; i < intervals.length; ++i) {
    const interval = intervals[i]
    const top = result[result.length - 1]
    if (top[1] + 1 >= interval[0]) {
      if (top[1] < interval[1]) top[1] = interval[1]
    } else {
      result.push(interval)
    }
  }
  return result
}

const parser = new Parser({
  defaultParseOptions: {
    shouldReservePosition: false,
  },
})

async function resolveRefPath(curDir: string, refPath: string): Promise<string | null> {
  const absoluteSrcPath: string = path.isAbsolute(refPath) ? refPath : path.join(curDir, refPath)
  return state.access.resolve(absoluteSrcPath, 'file')
}

async function parseMarkdown(filepath: string, sourceContent?: string): Promise<IMarkdownFileData> {
  const authorizedFilepath = state.access.resolve(filepath, 'file')
  const dirpath: string = path.dirname(authorizedFilepath)
  const rawContent: string = sourceContent ?? (await fs.readFile(authorizedFilepath, 'utf8'))

  const match: string[] | null = regexes.frontmatter.exec(rawContent) ?? ['', '']
  const frontmatter: Record<string, unknown> = match[1] ? parseYaml(match[1]) : {}
  const content: string = rawContent.slice(match[0].length)

  let ast: Root = parser.parse(content, {
    formatUrl: (url: string) => {
      if (
        url &&
        !url.startsWith('#') &&
        !url.startsWith('//') &&
        !/^[a-z][a-z\d+.-]*:/i.test(url)
      ) {
        const suffixAt = url.search(/[?#]/)
        const pathname = suffixAt < 0 ? url : url.slice(0, suffixAt)
        const suffix = suffixAt < 0 ? '' : url.slice(suffixAt)
        const targetFilepath = path.resolve(dirpath, decodeURIComponent(pathname))
        // The target endpoint authorizes each request; rewriting does not grant access.
        const search = toSearch({ filepath: targetFilepath })
        if (targetFilepath.toLowerCase().endsWith('.md')) {
          const hash = suffix.includes('#') ? suffix.slice(suffix.indexOf('#')) : ''
          return `/file${search}${hash}`
        }
        return `/api/file/raw${search}`
      }
      return url
    },
  })
  ast = await shallowMutateAstInPreorderAsync(ast, [CodeType], async o => {
    const { meta } = o as Code
    if (meta == null) return o

    const sourcefileMatch = regexes.srcFile.exec(meta!)
    if (sourcefileMatch == null) return o

    const relativeSrcPath: string = sourcefileMatch[1]
    const refPath: string | null = await resolveRefPath(dirpath, relativeSrcPath)
    if (refPath === null) return o

    state.watch(refPath)
    const content = await fs.readFile(refPath, 'utf8')
    let value: string = content

    const srcLineMatch = regexes.srcLine.exec(meta!)
    if (srcLineMatch != null) {
      const lineIntervals: Array<[number, number]> = collectIntervals(srcLineMatch[1])

      let commonIndent = Number.MAX_SAFE_INTEGER
      if (lineIntervals.length > 0) {
        const lines: string[] = content.split(regexes.line)
        const requiredLines: string[] = []
        for (const [x, y] of lineIntervals) {
          if (x < 0) continue
          if (x >= lines.length) break
          for (let i = x - 1; i < y; ++i) {
            if (commonIndent > 0) {
              const indent = regexes.indent.exec(lines[i])![0].length
              if (indent < lines[i].length && indent < commonIndent) {
                commonIndent = indent
              }
            }
            requiredLines.push(lines[i])
          }
        }

        // Trim common indents.
        if (commonIndent < Number.MAX_SAFE_INTEGER && commonIndent > 0) {
          value = requiredLines.map(x => x.slice(commonIndent)).join('\n')
        } else {
          value = requiredLines.join('\n')
        }
      }
    }

    return { ...o, value }
  })

  ast = shallowMutateAstInPreorder(ast, [TextType], node => {
    const text = node as Text
    const nextValue: string = text.value ? stripChineseCharacters(text.value) : text.value
    return text.value === nextValue ? node : { ...node, value: nextValue }
  })

  const toc: IHeadingToc = calcHeadingToc(ast, 'heading-')
  return { ast, toc, frontmatter }
}

export default parseMarkdown
