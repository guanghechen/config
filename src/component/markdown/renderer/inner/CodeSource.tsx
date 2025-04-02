import cn from 'clsx'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { CodeHighlighter, vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { CodeIcon } from '@/component/icon/material'
import { PRESET_CLASSES } from '@/constant/classes'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { CopyButton } from '../../../CopyButton'
import { useMarkdownDarken } from '../../context'

interface IProps {
  readonly code: string
  readonly lang: string | null
  readonly meta: ICodeMetaData
  readonly showLineno: boolean
  readonly initialExpanded?: boolean
}

export const CodeSource: React.FC<IProps> = props => {
  const { code, lang, meta, showLineno, initialExpanded } = props
  const darken: boolean = useMarkdownDarken()

  const themeScheme: IPrismThemeScheme = darken ? vscDarkTheme : vscLightTheme
  const title: string = (meta.filename || meta.title || '') as string
  const lineCount = React.useMemo(() => code.split('\n').length, [code])

  const [expanded, setExpanded] = React.useState(initialExpanded ?? lineCount < 16)
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
        {title && <span className="text-sm text-gray-600 dark:text-gray-400">{title}</span>}
        <div className="ml-auto flex items-center gap-2">
          <span className="text-xs text-gray-500 dark:text-gray-400">
            {lineCount} {lineCount === 1 ? 'line' : 'lines'}
          </span>
          <div className="h-4 w-px mx-1 bg-gray-300 dark:bg-gray-600" />
          <CopyButton calcContentForCopy={calcContentForCopy} nopadding={true} />
        </div>
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
            themeScheme={themeScheme}
            highlightLinenos={meta.highlights}
            lang={lang ?? ''}
            code={code}
            collapsed={false}
            showLineno={showLineno}
          />
        </div>
      )}
    </div>
  )
}

CodeSource.displayName = 'CodeSource'
