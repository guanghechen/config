import { collectIntervals } from '@guanghechen/std'
import type { Code, Root } from '@yozora/ast'
import { CodeType } from '@yozora/ast'
import { shallowMutateAstInPreorderAsync } from '@yozora/ast-util'
import Parser from '@yozora/parser'
import { existsSync, statSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import state from '../state'
import { toSearch } from './url'

const srcEncoding: BufferEncoding = 'utf8'
const srcFileRegex: RegExp = new RegExp(`(?:^|\\b)${'sourcefile'}="([^"]+)"`, 'i')
const srcLineRegex: RegExp = new RegExp(`(?:^|\\b)${'sourceline'}="([^"]+)"`, 'i')
const indentRegex: RegExp = /^\s*/
const lineRegex: RegExp = /\r|\n|\n\r/g

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

async function parseMarkdown(filepath: string): Promise<Root> {
  if (!existsSync(filepath)) throw new Error(`File not found: ${filepath}.`)

  const stat = statSync(filepath)
  if (stat.isDirectory()) {
    // eslint-disable-next-line no-param-reassign
    filepath = path.join(filepath, 'index.md')
    if (!existsSync(filepath))
      throw new Error(`Cannot resolve index.md for the given path ${filepath}.`)
  }

  const dirpath: string = path.dirname(filepath)
  const content: string = await fs.readFile(filepath, 'utf8')
  let ast: Root = parser.parse(content, {
    formatUrl: (url: string) => {
      if (url[0] === '.' || url[0] === '/') {
        const targetFilepath: string = path.normalize(path.resolve(dirpath, url))
        const { workspace, relativePath } = state.sharpFilepath(targetFilepath)
        const search: string = toSearch({ workspace, filepath: relativePath })
        if (targetFilepath.endsWith('.md')) return `/page${search}`
        return `/api/file${search}`
      }
      return url
    },
  })
  ast = await shallowMutateAstInPreorderAsync(ast, [CodeType], async o => {
    const { meta } = o as Code
    if (meta == null) return o

    const sourcefileMatch = srcFileRegex.exec(meta!)
    if (sourcefileMatch == null) return o

    const relativeSrcPath: string = sourcefileMatch[1]
    const refPath: string | null = await resolveRefPath(dirpath, relativeSrcPath)
    if (refPath === null) return o

    const rawContent = await fs.readFile(refPath)
    if (rawContent === null) return o

    const content = rawContent.toString(srcEncoding)
    let value: string = content

    const srcLineMatch = srcLineRegex.exec(meta!)
    if (srcLineMatch != null) {
      const lineIntervals: Array<[number, number]> = collectIntervals(srcLineMatch[1])

      let commonIndent = Number.MAX_SAFE_INTEGER
      if (lineIntervals.length > 0) {
        const lines: string[] = content.split(lineRegex)
        const requiredLines: string[] = []
        for (const [x, y] of lineIntervals) {
          if (x < 0) continue
          if (x >= lines.length) break
          for (let i = x - 1; i < y; ++i) {
            if (commonIndent > 0) {
              const indent = indentRegex.exec(lines[i])![0].length
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

  return ast
}

export default parseMarkdown
