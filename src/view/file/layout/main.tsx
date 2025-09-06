import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { calcExtname } from '@/util/path'
import { DrawboardAdaptor } from '../container/DrawboardAdaptor'
import { ExcalidrawAdaptor } from '../container/ExcalidrawAdaptor'
import { HtmlAdaptor } from '../container/HtmlAdaptor'
import { ImageAdaptor } from '../container/ImageAdaptor'
import { JsonAdaptor } from '../container/JsonAdaptor'
import { MarkdownAdaptor } from '../container/MarkdownAdaptor'
import { PdfAdaptor } from '../container/PdfAdaptor'
import { SvgAdaptor } from '../container/SvgAdaptor'
import { TextAdaptor } from '../container/TextAdaptor'
import { UnknownAdaptor } from '../container/UnknownAdaptor'
import { useFileViewmodel } from '../context'

interface IProps {
  readonly storageKeyScope: string
}

export const Main: React.FC<IProps> = props => {
  const { storageKeyScope } = props
  const viewmodel = useFileViewmodel()
  const workspace: string | null = null
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)

  if (!filepath) {
    return (
      <UnknownAdaptor
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        storageKeyScope={storageKeyScope}
      />
    )
  }

  const extname: string = calcExtname(filepath)
  switch (extname.toLowerCase()) {
    case '.drawboard':
      return (
        <DrawboardAdaptor
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
          onSaved={() => viewmodel.markFilepathDirty()}
        />
      )
    case '.excalidraw':
      return (
        <ExcalidrawAdaptor
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
          onSaved={() => viewmodel.markFilepathDirty()}
        />
      )
    case '.html':
    case '.htm':
      return (
        <HtmlAdaptor
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.json':
      return (
        <JsonAdaptor
          workspace={workspace}
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
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.md':
      return (
        <MarkdownAdaptor
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.pdf':
      return (
        <PdfAdaptor
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    case '.svg':
      return (
        <SvgAdaptor
          workspace={workspace}
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
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
    default:
      return (
        <UnknownAdaptor
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          storageKeyScope={storageKeyScope}
        />
      )
  }
}
Main.displayName = 'FileViewMain'
