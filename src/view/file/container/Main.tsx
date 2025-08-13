import React from 'react'
import { EventStreamView } from '@/view/filetype/eventstream/View'
import { ExcalidrawView } from '@/view/filetype/excalidraw/View'
import { HtmlView } from '@/view/filetype/html/View'
import { ImageView } from '@/view/filetype/image/View'
import { JsonView } from '@/view/filetype/json/View'
import { JsonlView } from '@/view/filetype/jsonl/View'
import { MarkdownView } from '@/view/filetype/markdown/View'
import { PdfView } from '@/view/filetype/pdf/View'
import { SvgView } from '@/view/filetype/svg/View'
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
      return <UnknownView filepath={filepath} extname="" />
    }

    const extname: string = filepath ? regexes.extname.exec(filepath)?.[1] || '' : ''
    switch (extname.toLowerCase()) {
      case '.eventstream':
        return (
          <EventStreamView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
            topbarVisible={false}
          />
        )
      case '.excalidraw':
        return (
          <ExcalidrawView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
          />
        )
      case '.html':
      case '.htm':
        return (
          <HtmlView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
            topbarVisible={false}
          />
        )
      case '.json':
        return (
          <JsonView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
            topbarVisible={false}
          />
        )
      case '.jsonl':
        return (
          <JsonlView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
            topbarVisible={false}
          />
        )
      case '.md':
        return (
          <MarkdownView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
            topbarVisible={false}
          />
        )
      case '.pdf':
        return (
          <PdfView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
          />
        )
      case '.svg':
        return (
          <SvgView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
          />
        )
      case '.png':
      case '.jpg':
      case '.jpeg':
        return <ImageView workspace={null} filepath={filepath} mainScrollableContainer={null} />
      default:
        return <UnknownView filepath={filepath} extname={extname} />
    }
  }
}
