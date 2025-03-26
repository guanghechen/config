import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useWorkspaceViewmodel } from '../context'

const MarkdownContainer = React.lazy(() => import('./markdown'))
const UnknownContainer = React.lazy(() => import('./unknown'))

export const WorkspaceMain: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const filepath = useStateValue(workspaceVM.filepath$)

  const extname: string = React.useMemo<string>(() => {
    if (!filepath) return ''
    const dotIndex: number = filepath.lastIndexOf('.')
    return dotIndex < 0 ? '' : filepath.slice(dotIndex)
  }, [filepath])

  const container: React.ReactElement = React.useMemo<React.ReactElement>(() => {
    switch (extname) {
      case '.md':
        return <MarkdownContainer />
      default:
        return <UnknownContainer extname={extname} filepath={filepath} />
    }
  }, [filepath, extname])

  return (
    <div className="box-border flex h-full justify-center">
      <div className="box-border h-full w-full p-8">{container}</div>
    </div>
  )
}

WorkspaceMain.displayName = 'WorkspaceMain'
export default WorkspaceMain
