import cn from 'clsx'
import React from 'react'
import { TerminalIcon } from '@/component/icon/material'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { Embed } from '../embed'

interface IProps {
  readonly code: string
  readonly lang: string
  readonly meta: ICodeMetaData
}

export const CodeResult: React.FC<IProps> = props => {
  const { code, lang, meta } = props
  const [expanded, setExpanded] = React.useState(true)

  return (
    <div className="flex flex-col">
      <div
        className={cn(
          'box-border w-full justify-start items-center gap-2 p-2 px-4 cursor-pointer select-none flex bg-gray-100 dark:bg-[#2d2d2d]',
          {
            'border-b border-opacity-10 border-gray-300 dark:border-gray-600': expanded,
          },
        )}
        onClick={() => setExpanded(v => !v)}
      >
        <TerminalIcon className="h-[18px] w-[18px] opacity-80" />
        <span className="text-sm">Result</span>
      </div>
      {expanded && (
        <div className="flex items-center justify-center p-4">
          <Embed lang={lang} code={code} meta={meta} />
        </div>
      )}
    </div>
  )
}
CodeResult.displayName = 'CodeResult'
