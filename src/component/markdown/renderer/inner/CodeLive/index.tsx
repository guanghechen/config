import React from 'react'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { Mermaid } from './mermaid'

interface IProps {
  readonly lang: string
  readonly code: string
  readonly meta: ICodeMetaData
}

export const CodeLiveRenderer: React.FC<IProps> = props => {
  const { lang, code } = props

  switch (lang.toLowerCase()) {
    case 'mermaid':
      return <Mermaid code={code} />
    default:
      return <React.Fragment />
  }
}
