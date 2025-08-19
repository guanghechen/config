import React from 'react'
import { ExcalidrawView } from '@/view/filetype/excalidraw/View'
import { HtmlView } from '@/view/filetype/html/View'
import { ImageView } from '@/view/filetype/image/View'
import { JsonView } from '@/view/filetype/json/View'
import { MarkdownView } from '@/view/filetype/markdown/View'
import { PdfView } from '@/view/filetype/pdf/View'
import { SvgView } from '@/view/filetype/svg/View'
import { TextView } from '@/view/filetype/text/View'
import { UnknownView } from '@/view/filetype/unknown/View'

const regexes = {
  extname: /(\.[^.]+)$/,
}

interface IProps {
  readonly filepath: string | null
  readonly filepathDirtyTick: number
}

export class Main extends React.PureComponent<IProps> {
  public static displayName: string = 'FileViewMain'

  public override render(): React.ReactElement {
    const { filepath, filepathDirtyTick } = this.props
    if (!filepath) {
      return (
        <UnknownView workspace={null} filepath={filepath} filepathDirtyTick={filepathDirtyTick} />
      )
    }

    const extname: string = filepath ? regexes.extname.exec(filepath)?.[1] || '' : ''
    const workspace: string | null = null

    switch (extname.toLowerCase()) {
      case '.excalidraw':
        return (
          <ExcalidrawView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.html':
      case '.htm':
        return (
          <HtmlView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.json':
        return (
          <JsonView
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
          <TextView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.md':
        return (
          <MarkdownView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.pdf':
        return (
          <PdfView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.svg':
        return (
          <SvgView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      case '.png':
      case '.jpg':
      case '.jpeg':
        return (
          <ImageView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
      default:
        return (
          <UnknownView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
          />
        )
    }
  }
}
