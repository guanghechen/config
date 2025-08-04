import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { WorkspaceViewModel } from '@/context/workspace'
const EventStreamContainer = React.lazy(() => import('./eventstream'))
const ExcalidrawContainer = React.lazy(() => import('./excalidraw'))
const ImageContainer = React.lazy(() => import('./image'))
const JsonContainer = React.lazy(() => import('./json'))
const MarkdownContainer = React.lazy(() => import('./markdown'))
const PDFContainer = React.lazy(() => import('./pdf'))
const SvgContainer = React.lazy(() => import('./svg'))
const UnknownContainer = React.lazy(() => import('./unknown'))

interface IProps {
  readonly viewmodel: WorkspaceViewModel
}

export const WorkspaceMain: React.FC<IProps> = props => {
  const { viewmodel } = props
  const workspace: string | null = useStateValue(viewmodel.workspace$)
  const filepath = useStateValue(viewmodel.filepath$)

  const extname: string = React.useMemo<string>(() => {
    if (!filepath) return ''
    const dotIndex: number = filepath.lastIndexOf('.')
    return dotIndex < 0 ? '' : filepath.slice(dotIndex)
  }, [filepath])

  const container: React.ReactElement = React.useMemo<React.ReactElement>(() => {
    switch (extname.toLowerCase()) {
      case '.eventstream':
        return <EventStreamContainer />
      case '.excalidraw':
        return <ExcalidrawContainer />
      case '.json':
        return <JsonContainer />
      case '.md':
        return <MarkdownContainer />
      case '.pdf':
        return <PDFContainer filepath={filepath} workspace={workspace} />
      case '.svg':
        return <SvgContainer filepath={filepath} workspace={workspace} />
      case '.png':
      case '.jpg':
      case '.jpeg':
        return <ImageContainer filepath={filepath} workspace={workspace} />
      default:
        return <UnknownContainer extname={extname} filepath={filepath} />
    }
  }, [extname, filepath, workspace])

  return container
}
WorkspaceMain.displayName = 'WorkspaceMain'
export default WorkspaceMain
