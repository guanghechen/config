import { useStateValue } from '@guanghechen/react-viewmodel'
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
import { useWorkspaceViewmodel } from '../context'

export const Main: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)
  const mainScrollableContainer: HTMLDivElement | null = useStateValue(
    viewmodel.mainScrollableContainer$,
  )
  const topbarVisible: boolean = useStateValue(viewmodel.topbarVisible$)

  const extname: string = React.useMemo<string>(() => {
    if (!filepath) return ''
    const dotIndex: number = filepath.lastIndexOf('.')
    return dotIndex < 0 ? '' : filepath.slice(dotIndex)
  }, [filepath])

  const container: React.ReactElement = React.useMemo<React.ReactElement>(() => {
    if (!filepath) {
      return <UnknownView filepath={filepath} extname={extname} />
    }

    const commonProps = {
      workspace,
      filepath,
      filepathDirtyTick,
      mainScrollableContainer,
      topbarVisible,
    }

    switch (extname.toLowerCase()) {
      case '.eventstream':
        return <EventStreamView {...commonProps} />
      case '.excalidraw':
        return <ExcalidrawView {...commonProps} />
      case '.html':
      case '.htm':
        return <HtmlView {...commonProps} />
      case '.json':
        return <JsonView {...commonProps} />
      case '.jsonl':
        return <JsonlView {...commonProps} />
      case '.md':
        return <MarkdownView {...commonProps} />
      case '.pdf':
        return <PdfView {...commonProps} />
      case '.svg':
        return <SvgView {...commonProps} />
      case '.png':
      case '.jpg':
      case '.jpeg':
        return <ImageView {...commonProps} />
      default:
        return <UnknownView filepath={filepath} extname={extname} />
    }
  }, [extname, workspace, filepath, filepathDirtyTick, mainScrollableContainer, topbarVisible])

  return container
}

Main.displayName = 'WorkspaceMain'
