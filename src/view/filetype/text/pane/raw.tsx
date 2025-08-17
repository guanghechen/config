import cn from 'clsx'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { CodeHighlighter } from '@/component/code-highlighter'
import { PRESET_CLASSES } from '@/shared/constant'

interface IProps {
  readonly content: string
  readonly themeScheme: IPrismThemeScheme
  readonly columns: number
}

export const RawPane: React.FC<IProps> = props => {
  const { content, themeScheme, columns } = props

  return (
    <div
      className={cn(
        'h-full w-[48rem] max-w-[100rem] flex-auto border border-gray-200 dark:border-gray-700',
        PRESET_CLASSES.scrollbar,
        {
          'p-2 overflow-auto': columns > 1,
          'p-8 overflow-auto': columns === 1,
        },
      )}
    >
      <div className="overflow-x-auto whitespace-nowrap">
        <CodeHighlighter
          themeScheme={themeScheme}
          lang="text"
          code={content}
          collapsed={false}
          showLineno={true}
        />
      </div>
    </div>
  )
}

RawPane.displayName = 'TextRawPane'
