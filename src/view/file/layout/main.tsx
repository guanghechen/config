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
        <UnknownView
          workspace={null}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          mainScrollableContainer={null}
        />
      )
    }

    const extname: string = filepath ? regexes.extname.exec(filepath)?.[1] || '' : ''
    switch (extname.toLowerCase()) {
      case '.eventstream':
        return (
          <TextView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
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
          />
        )
      case '.json':
        return (
          <JsonView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
          />
        )
      case '.jsonl':
        return (
          <JsonlView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
          />
        )
      case '.log':
      case '.txt':
        return (
          <TextView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
          />
        )
      case '.md':
        return (
          <MarkdownView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
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
        return (
          <UnknownView
            workspace={null}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={null}
          />
        )
    }
  }
}
