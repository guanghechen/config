import CodeHighlighter from '@yozora/react-code-highlighter'
import cn from 'clsx'
import React from 'react'
import { CodeIcon } from '@/component/icon/material'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { useMarkdownDarken } from '../../context'
import { CopyButton } from './CopyButton'

interface IProps {
  readonly code: string
  readonly lang: string | null
  readonly meta: ICodeMetaData
  readonly showLineNo: boolean
  readonly initialExpanded?: boolean
}

export const CodeSource: React.FC<IProps> = props => {
  const { code, lang, meta, showLineNo, initialExpanded = false } = props
  const title: string = (meta.filename || meta.title || '') as string
  const darken: boolean = useMarkdownDarken()

  const [expanded, setExpanded] = React.useState(initialExpanded)
  const calcContentForCopy = React.useCallback(() => code, [code])

  return (
    <div className="flex flex-col">
      <div
        className={cn(
          'flex items-center gap-2 p-2 px-4 cursor-pointer select-none bg-gray-100 dark:bg-[#2d2d2d]',
          {
            'border-b border-gray-300 dark:border-gray-700': !expanded,
          },
        )}
        onClick={() => setExpanded(v => !v)}
      >
        <CodeIcon className="h-[18px] w-[18px] opacity-80" />
        <span className="rounded bg-gray-200 px-1.5 py-0.5 text-xs dark:bg-[#444]">{lang}</span>
        {title && <span className="text-sm text-indigo-600 dark:text-indigo-400">{title}</span>}
      </div>
      {expanded && (
        <div className="group relative box-border block max-h-[40rem] overflow-auto rounded-[4px] font-[var(--fontFamilyCode)] [&[data-wrap='true']>div]:whitespace-pre-wrap [&[data-wrap='true']>div]:break-keep">
          <CodeHighlighter
            darken={darken}
            lang={lang}
            value={code}
            collapsed={false}
            showLineNo={showLineNo}
          />
          <div className="absolute right-1 top-1 opacity-0 transition-opacity group-hover:opacity-100">
            <CopyButton calcContentForCopy={calcContentForCopy} />
          </div>
        </div>
      )}
    </div>
  )
}

CodeSource.displayName = 'CodeSource'
