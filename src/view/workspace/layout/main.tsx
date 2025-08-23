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
}

export class Main extends React.PureComponent<IProps> {
  public static displayName: string = 'WorkspaceViewMain'

  public override render(): React.ReactElement {
    const { workspace, filepath, filepathDirtyTick } = this.props

    if (!filepath) {
      return (
        <UnknownAdaptor
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
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
          />
        )
      case '.html':
      case '.htm':
        return (
          <HtmlAdaptor
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.json':
        return (
          <JsonAdaptor
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
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
          />
        )
      case '.md':
        return (
          <MarkdownAdaptor
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.pdf':
        return (
          <PdfAdaptor
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.svg':
        return (
          <SvgAdaptor
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
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
          />
        )
      default:
        return (
          <UnknownAdaptor
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
    }
  }
}
