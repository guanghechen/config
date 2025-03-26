import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useWorkspaceViewmodel } from '../context'

const ImageContainer = React.lazy(() => import('./image'))
const JsonContainer = React.lazy(() => import('./json'))
const MarkdownContainer = React.lazy(() => import('./markdown'))
const UnknownContainer = React.lazy(() => import('./unknown'))

export const WorkspaceMain: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const filepath = useStateValue(workspaceVM.filepath$)

  const extname: string = React.useMemo<string>(() => {
    if (!filepath) return ''
    const dotIndex: number = filepath.lastIndexOf('.')
    return dotIndex < 0 ? '' : filepath.slice(dotIndex)
  }, [filepath])

  const container: React.ReactElement = React.useMemo<React.ReactElement>(() => {
    switch (extname.toLowerCase()) {
      case '.json':
        return <JsonContainer />
      case '.md':
        return <MarkdownContainer />
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.svg':
        return <ImageContainer filepath={filepath} workspace={workspace} />
      default:
        return <UnknownContainer extname={extname} filepath={filepath} />
    }
  }, [extname, filepath, workspace])

  return (
    <div className="box-border flex h-full justify-center">
      <div className="box-border h-full w-full p-8">{container}</div>
    </div>
  )
}

WorkspaceMain.displayName = 'WorkspaceMain'
export default WorkspaceMain
