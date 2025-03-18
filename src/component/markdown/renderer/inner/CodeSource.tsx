import CodeHighlighter from '@yozora/react-code-highlighter'
import cn from 'clsx'
import React from 'react'
import { CodeIcon } from '@/component/icon/material'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { CopyButton } from './CopyButton'

interface IProps {
  readonly darken: boolean
  readonly code: string
  readonly lang: string | null
  readonly meta: ICodeMetaData
  readonly showLineNo: boolean
  readonly initialExpanded?: boolean
}

export const CodeSource: React.FC<IProps> = props => {
  const { darken, code, lang, meta, showLineNo, initialExpanded = false } = props
  const title: string = (meta.filename || meta.title || '') as string

  const [expanded, setExpanded] = React.useState(initialExpanded)
  const calcContentForCopy = React.useCallback(() => code, [code])

  return (
    <div className="flex flex-col" onClick={() => setExpanded(v => !v)}>
      <div
        className={cn('flex items-center gap-2 p-2 px-4 cursor-pointer select-none', {
          'bg-[#2d2d2d]': darken,
          'bg-gray-100': !darken,
          'border-b border-gray-300': !expanded,
        })}
      >
        <CodeIcon className="w-[18px] h-[18px] opacity-80" />
        <span
          className={cn('px-1.5 py-0.5 rounded text-xs', {
            'bg-[#444]': darken,
            'bg-gray-200': !darken,
          })}
        >
          {lang}
        </span>
        {title && <span className="text-sm text-indigo-600 dark:text-indigo-400">{title}</span>}
      </div>
      {expanded && (
        <div className="relative group block box-border rounded-[4px] font-[var(--fontFamilyCode)] [&[data-wrap='true']>div]:whitespace-pre-wrap [&[data-wrap='true']>div]:break-keep">
          <CodeHighlighter
            lang={lang}
            value={code}
            collapsed={false}
            showLineNo={showLineNo}
            darken={darken}
          />
          <div className="absolute right-1 top-1 opacity-0 group-hover:opacity-100 transition-opacity">
            <CopyButton calcContentForCopy={calcContentForCopy} />
          </div>
        </div>
      )}
    </div>
  )
}

CodeSource.displayName = 'CodeSource'
