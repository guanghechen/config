import type { IHeadingToc } from '@yozora/ast-util'
import React from 'react'
import { MarkdownTocItem } from './MarkdownTocItem'

interface IProps {
  readonly toc: IHeadingToc | undefined
}

export const MarkdownToc: React.FC<IProps> = props => {
  const { toc } = props

  return (
    <div className="h-full overflow-auto p-4">
      {toc ? (
        <div className="toc-container">
          {toc.children.map(item => (
            <MarkdownTocItem key={item.identifier} item={item} depth={0} />
          ))}
        </div>
      ) : (
        <div className="flex h-[calc(100%-2rem)] flex-col items-center justify-center rounded-lg border-2 border-dashed border-gray-300 p-6 text-center dark:border-gray-700">
          <svg
            className="mb-4 h-12 w-12 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
            />
          </svg>
          <p className="text-sm text-gray-500 dark:text-gray-400">
            No table of contents available for this document.
          </p>
          <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
            Add headings to your document to generate a table of contents.
          </p>
        </div>
      )}
    </div>
  )
}
