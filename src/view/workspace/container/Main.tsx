import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
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
import { useWorkspaceViewmodel } from '../context'

export const Main: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)
  const mainScrollableContainer: HTMLDivElement | null = useStateValue(
    viewmodel.mainScrollableContainer$,
  )

  const extname: string = React.useMemo<string>(() => {
    if (!filepath) return ''
    const dotIndex: number = filepath.lastIndexOf('.')
    return dotIndex < 0 ? '' : filepath.slice(dotIndex)
  }, [filepath])

  const container: React.ReactElement = React.useMemo<React.ReactElement>(() => {
    if (!filepath) {
      return (
        <UnknownView
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          mainScrollableContainer={mainScrollableContainer}
        />
      )
    }

    switch (extname.toLowerCase()) {
      case '.eventstream':
        return (
          <TextView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.excalidraw':
        return (
          <ExcalidrawView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.html':
      case '.htm':
        return (
          <HtmlView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.json':
        return (
          <JsonView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.jsonl':
        return (
          <JsonlView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.log':
      case '.txt':
        return (
          <TextView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.md':
        return (
          <MarkdownView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.pdf':
        return (
          <PdfView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.svg':
        return (
          <SvgView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      case '.png':
      case '.jpg':
      case '.jpeg':
        return (
          <ImageView
            workspace={workspace}
            filepath={filepath}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
      default:
        return (
          <UnknownView
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        )
    }
  }, [extname, workspace, filepath, filepathDirtyTick, mainScrollableContainer])

  return container
}

Main.displayName = 'WorkspaceMain'
