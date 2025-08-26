import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import { calcHeadingToc } from '@yozora/ast-util'
import Parser from '@yozora/parser'
import React from 'react'
import type { IMarkdownFileData } from '@/shared/types/api'
import { MarkdownView } from '@/view/filetype/markdown/View'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly storageKeyScope: string
}

const parser = new Parser({
  defaultParseOptions: {
    shouldReservePosition: false,
  },
})

export const WhiteboardMarkdownAdaptor: React.FC<IProps> = ({
  content,
  contentError,
  storageKeyScope,
}) => {
  const data = React.useMemo<IMarkdownFileData | null>(() => {
    if (!content) return null

    try {
      const ast: Root = parser.parse(content)
      const toc: IHeadingToc = calcHeadingToc(ast, 'heading-')
      return {
        ast,
        toc,
        frontmatter: {},
      }
    } catch (error) {
      console.error('Failed to parse markdown:', error)
      return null
    }
  }, [content])

  const dataError = contentError || (content && !data ? 'Failed to parse markdown content' : null)

  return <MarkdownView data={data} dataError={dataError} storageKeyScope={storageKeyScope} />
}
