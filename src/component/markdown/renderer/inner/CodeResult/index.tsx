import cn from 'clsx'
import React from 'react'
import { TerminalIcon } from '@/component/icon/material'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { Mermaid } from './mermaid'

interface ICodeResultRendererProps {
  readonly lang: string
  readonly code: string
  readonly meta: ICodeMetaData
}

const CodeResultRenderer: React.FC<ICodeResultRendererProps> = props => {
  const { lang, code } = props

  switch (lang.toLowerCase()) {
    case 'mermaid':
      return <Mermaid code={code} />
    default:
      return <React.Fragment />
  }
}

interface IProps {
  readonly darken: boolean
  readonly code: string
  readonly lang: string
  readonly meta: ICodeMetaData
}

export const CodeResult: React.FC<IProps> = props => {
  const { darken, code, lang, meta } = props
  const [expanded, setExpanded] = React.useState(true)

  return (
    <div className="flex flex-col" onClick={() => setExpanded(v => !v)}>
      <div
        className={cn(
          'flex w-full justify-start items-center gap-2 p-2 px-4 cursor-pointer select-none',
          {
            'bg-[#2d2d2d]': darken,
            'bg-gray-100': !darken,
            'border-b border-opacity-10 border-black': expanded,
          },
        )}
      >
        <TerminalIcon className="w-[18px] h-[18px] opacity-80" />
        <span className="text-sm">Result</span>
      </div>
      {expanded && (
        <div className="p-4 flex justify-center items-center">
          <CodeResultRenderer lang={lang} code={code} meta={meta} />
        </div>
      )}
    </div>
  )
}
CodeResult.displayName = 'CodeResult'
