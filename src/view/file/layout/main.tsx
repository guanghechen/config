import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { calcExtname } from '@/common/util/path'
import { HtmlAdaptor } from '../container/HtmlAdaptor'
import { ImageAdaptor } from '../container/ImageAdaptor'
import { JsonAdaptor } from '../container/JsonAdaptor'
import { MarkdownAdaptor } from '../container/MarkdownAdaptor'
import { PdfAdaptor } from '../container/PdfAdaptor'
import { SvgAdaptor } from '../container/SvgAdaptor'
import { TextAdaptor } from '../container/TextAdaptor'
import { UnknownAdaptor } from '../container/UnknownAdaptor'
import { WhiteboardAdaptor } from '../container/WhiteboardAdaptor'
import { useFileViewmodel } from '../context'

interface IProps {
  readonly storageKeyScope: string
}

export const Main: React.FC<IProps> = props => {
  const { storageKeyScope } = props
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)

  if (!filepath) {
    return (
      <UnknownAdaptor
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        storageKeyScope={storageKeyScope}
      />
    )
  }

  const extname: string = calcExtname(filepath)
  switch (extname.toLowerCase()) {
    case '.whiteboard':
      return <WhiteboardAdaptor filepath={filepath} />
    case '.html':
    case '.htm':
      return (
        <HtmlAdaptor
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.json':
      return (
        <JsonAdaptor
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.eventstream':
    case '.jsonl':
    case '.log':
    case '.txt':
      return (
        <TextAdaptor
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.md':
      return (
        <MarkdownAdaptor
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.pdf':
      return (
        <PdfAdaptor
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.svg':
      return (
        <SvgAdaptor
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.png':
    case '.jpg':
    case '.jpeg':
      return (
        <ImageAdaptor
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    default:
      return (
        <UnknownAdaptor
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
  }
}
Main.displayName = 'FileViewMain'
