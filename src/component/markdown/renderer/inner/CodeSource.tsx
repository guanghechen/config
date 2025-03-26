import CodeHighlighter from '@yozora/react-code-highlighter'
import cn from 'clsx'
import React from 'react'
import { CodeIcon } from '@/component/icon/material'
import { PRESET_CLASSES } from '@/constant/classes'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { CopyButton } from '../../../CopyButton'
import { useMarkdownDarken } from '../../context'

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
            'border-b border-gray-300 dark:border-gray-600': !expanded,
          },
        )}
        onClick={() => setExpanded(v => !v)}
      >
        <CodeIcon className="h-[18px] w-[18px] opacity-80" />
        <span className="rounded bg-gray-200 px-1.5 py-0.5 text-xs dark:bg-[#444]">{lang}</span>
        {title && <span className="text-sm text-indigo-600 dark:text-indigo-400">{title}</span>}
      </div>
      {expanded && (
        <div
          className={cn(
            'group relative box-border block max-h-[40rem] overflow-auto rounded-[4px]  pb-2 font-[var(--fontFamilyCode)]',
            PRESET_CLASSES.scrollbar,
          )}
        >
          <div className="sticky right-0 top-0 float-right h-2 w-full opacity-0 transition-opacity group-hover:opacity-100">
            <div className="relative">
              <div className="absolute right-0 top-2">
                <CopyButton calcContentForCopy={calcContentForCopy} />
              </div>
            </div>
          </div>
          <CodeHighlighter
            darken={darken}
            lang={lang}
            value={code}
            collapsed={false}
            showLineNo={showLineNo}
            className={PRESET_CLASSES.scrollbar}
            codesClassName={PRESET_CLASSES.scrollbar}
          />
        </div>
      )}
    </div>
  )
}

CodeSource.displayName = 'CodeSource'
