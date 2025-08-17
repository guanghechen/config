import { collectIntervals } from '@guanghechen/std'
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
import { existsSync, statSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import { parse as parseYaml } from 'yaml'
import { toSearch } from '../../shared/util'
import state from '../state'

const regexes = {
  frontmatter: /^\s*[-]{3,}\n\s*([\s\S]*?)[-]{3,}\n/,
  indent: /^\s*/,
  line: /\r|\n|\n\r/g,
  srcFile: new RegExp(`(?:^|\\b)${'sourcefile'}="([^"]+)"`, 'i'),
  srcLine: new RegExp(`(?:^|\\b)${'sourceline'}="([^"]+)"`, 'i'),
}

const parser = new Parser({
  defaultParseOptions: {
    shouldReservePosition: false,
  },
})

async function resolveRefPath(curDir: string, refPath: string): Promise<string | null> {
  const absoluteSrcPath: string = path.isAbsolute(refPath) ? refPath : path.join(curDir, refPath)
  if (existsSync(absoluteSrcPath)) return absoluteSrcPath

  state.reporter.warn(
    '[AssetResolverApi.resolveRefPath] cannot find the file. refPath: {}, curDir: {}',
    refPath,
    curDir,
  )
  return null
}

async function parseMarkdown(filepath: string): Promise<{
  readonly ast: Root
  readonly toc: IHeadingToc
  readonly frontmatter: Record<string, unknown>
}> {
  if (!existsSync(filepath)) throw new Error(`File not found: ${filepath}.`)

  const stat = statSync(filepath)
  if (stat.isDirectory()) {
    // eslint-disable-next-line no-param-reassign
    filepath = path.join(filepath, 'index.md')
    if (!existsSync(filepath))
      throw new Error(`Cannot resolve index.md for the given path ${filepath}.`)
  }

  const dirpath: string = path.dirname(filepath)
  const rawContent: string = await fs.readFile(filepath, 'utf8')

  const match: string[] | null = regexes.frontmatter.exec(rawContent) ?? ['', '']
  const frontmatter: Record<string, unknown> = match[1] ? parseYaml(match[1]) : {}
  const content: string = rawContent.slice(match[0].length)

  let ast: Root = parser.parse(content, {
    formatUrl: (url: string) => {
      if (url[0] === '.' || url[0] === '/') {
        const targetFilepath: string = path.normalize(path.resolve(dirpath, url))
        const { workspace, relativePath } = state.sharpFilepath(targetFilepath)
        const search: string = toSearch({ workspace, filepath: relativePath })
        if (targetFilepath.endsWith('.md')) return `/workspace${search}`
        return `/api/file${search}`
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
