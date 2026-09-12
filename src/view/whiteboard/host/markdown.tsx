import React from 'react'
import type { Root } from '@yozora/ast'
import { ReactMarkdown } from '@/container/markdown/ReactMarkdown'
import { useMarkdownTopViewmodel } from '@/container/markdown/context/top'
import type { IWhiteboardMarkdownProps } from '../contracts'

export const Markdown: React.FC<IWhiteboardMarkdownProps> = ({ content, renderData }) => {
  const top = useMarkdownTopViewmodel()
  const ast = React.useMemo(
    () => (renderData ? (renderData as Root) : top.parseMarkdown(content)),
    [top, content, renderData],
  )
  return <ReactMarkdown ast={ast} dontShowFirstHeading={false} />
}
