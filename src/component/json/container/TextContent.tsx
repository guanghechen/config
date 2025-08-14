import React from 'react'
import { ReactMarkdownContent } from '../../markdown/ReactMarkdownContent'

type TPrettierMode = 'plain' | 'md'

interface IProps {
  readonly value: string
  readonly prettier: boolean
  readonly prettierMode: TPrettierMode
  readonly expanded: boolean
  readonly textRef: React.RefObject<HTMLElement | null>
}

export const TextContent: React.FC<IProps> = props => {
  const { value, prettier, prettierMode, expanded, textRef } = props

  if (!prettier) {
    return (
      <code
        ref={textRef}
        className={`${expanded ? '' : 'line-clamp-6'} overflow-hidden text-emerald-600 dark:text-emerald-400 break-all`}
      >
        "{value.replace(/\n/g, '\\n')}"
      </code>
    )
  }

  if (prettierMode === 'md') {
    return (
      <div
        ref={textRef as any}
        className={`${expanded ? '' : 'line-clamp-6'} overflow-hidden text-emerald-600 dark:text-emerald-400  break-all`}
      >
        <ReactMarkdownContent content={value} />
      </div>
    )
  }

  return (
    <pre
      ref={textRef as any}
      className={`${expanded ? '' : 'line-clamp-6'} overflow-hidden text-emerald-600 dark:text-emerald-400 whitespace-pre-wrap break-all`}
    >
      <code>"{value}"</code>
    </pre>
  )
}
TextContent.displayName = 'TextContent'
