import React from 'react'
import { calcExtname } from '@/util/path'
import { ExcalidrawAdaptor } from '@/view/file/container/ExcalidrawAdaptor'
import { HtmlAdaptor } from '@/view/file/container/HtmlAdaptor'
import { ImageAdaptor } from '@/view/file/container/ImageAdaptor'
import { JsonAdaptor } from '@/view/file/container/JsonAdaptor'
import { MarkdownAdaptor } from '@/view/file/container/MarkdownAdaptor'
import { PdfAdaptor } from '@/view/file/container/PdfAdaptor'
import { SvgAdaptor } from '@/view/file/container/SvgAdaptor'
import { TextAdaptor } from '@/view/file/container/TextAdaptor'
import { UnknownAdaptor } from '@/view/file/container/UnknownAdaptor'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export class Main extends React.PureComponent<IProps> {
  public static displayName: string = 'WorkspaceViewMain'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick, storageKeyScope } = this.props

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
      case '.excalidraw':
        return (
          <ExcalidrawAdaptor
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            storageKeyScope={storageKeyScope}
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
}
