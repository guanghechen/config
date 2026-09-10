import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { calcExtname } from '@/common/util/path'
import { HtmlAdaptor } from '@/view/file/container/HtmlAdaptor'
import { ImageAdaptor } from '@/view/file/container/ImageAdaptor'
import { JsonAdaptor } from '@/view/file/container/JsonAdaptor'
import { MarkdownAdaptor } from '@/view/file/container/MarkdownAdaptor'
import { PdfAdaptor } from '@/view/file/container/PdfAdaptor'
import { SvgAdaptor } from '@/view/file/container/SvgAdaptor'
import { TextAdaptor } from '@/view/file/container/TextAdaptor'
import { UnknownAdaptor } from '@/view/file/container/UnknownAdaptor'
import { useWorkspaceViewmodel } from '../context'

interface IProps {
  readonly storageKeyScope: string
}

export const Main: React.FC<IProps> = props => {
  const { storageKeyScope } = props
  const viewmodel = useWorkspaceViewmodel()
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
Main.displayName = 'WorkspaceViewMain'
