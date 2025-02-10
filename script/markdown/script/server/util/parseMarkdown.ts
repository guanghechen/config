import type { Root } from '@yozora/ast'
import Parser from '@yozora/parser'
import { existsSync, statSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'

const parser = new Parser({
  defaultParseOptions: {
    shouldReservePosition: false,
  },
})

async function parseMarkdown(filepath: string): Promise<Root> {
  if (!existsSync(filepath)) throw new Error(`File not found: ${filepath}.`)

  const stat = statSync(filepath)
  if (stat.isDirectory()) {
    // eslint-disable-next-line no-param-reassign
    filepath = path.join(filepath, 'index.md')
    if (!existsSync(filepath))
      throw new Error(`Canot resolve index.md for the given path ${filepath}.`)
  }

  const content: string = await fs.readFile(filepath, 'utf8')
  const ast: Root = parser.parse(content, {
    formatUrl: (url: string) => {
      if (url[0] === '.' || url[0] === '/') {
        const dirpath: string = path.dirname(filepath)
        const targetFilepath: string = path.normalize(path.resolve(dirpath, url))
        const query: Record<string, string> = { filepath: targetFilepath }
        const params = new URLSearchParams(query)
        if (targetFilepath.endsWith('.md')) return `/page/?${params}`
        return `/api/file?${params}`
      }
      return url
    },
  })
  return ast
}

export default parseMarkdown
